# DeerFlow-Inspired Features — Implementation Plan

> **Status:** Draft | **Author:** Claude | **Date:** 2026-03-21
> **Context:** 5,300 active users, production Android app, Node.js 18 runtime, Telegram interface
> **Codebase ref:** claude.js (tool loop), tools/ (56+ tools), main.js (message routing), config.js (constants)

---

## Table of Contents

1. [Feature 1: Loop Detection (P0)](#feature-1-loop-detection-p0)
2. [Feature 2: Context Summarization (P1)](#feature-2-context-summarization-p1)
3. [Feature 3: Clarification Tool (P1)](#feature-3-clarification-tool-p1)
4. [Feature 4: Memory Session Scrubbing (P1)](#feature-4-memory-session-scrubbing-p1)
5. [Feature 5: Deferred Tool Loading (P2)](#feature-5-deferred-tool-loading-p2)
6. [Challenge & Risk Assessment](#challenge--risk-assessment)
7. [Priority & Dependencies](#priority--dependencies)
8. [Effort Summary](#effort-summary)

---

## Feature 1: Loop Detection (P0)

**Priority:** P0 — Ship first. Loop bugs burn tokens and frustrate users.
**Effort:** Small (~60 lines new code, ~10 lines modifications)
**Risk:** Low — additive, no existing behavior changed unless loop detected

### Problem

The tool loop in `claude.js` (lines 1718-1895) has no loop detection. The only guard is `MAX_TOOL_USES = 25` (line 1713). If the model calls the same tool with the same arguments repeatedly — for example, `web_fetch` on a URL that always 404s, or `read` on a file that doesn't exist — it burns through all 25 iterations before stopping. At ~$0.01-0.10 per iteration (depending on context size and model), a single stuck loop can cost $0.25-2.50 and take 2-5 minutes before the user sees any response.

**Concrete scenario:** User asks "check if my website is up." Agent calls `web_fetch("https://example.com")`, gets a timeout error, calls it again, gets a timeout, calls it again... 25 times. Each call waits up to 15s. Total: 6+ minutes of silence, $1+ in API costs, and the user thinks the bot is dead.

### Solution

New module `loop-detector.js` that tracks tool call hashes per conversation turn and injects corrective system messages when patterns repeat.

**File: `app/src/main/assets/nodejs-project/loop-detector.js`** (~60 lines)

```javascript
// loop-detector.js — Detect and break tool call loops in the agent's tool-use cycle.
//
// Hash: MD5(toolName + JSON.stringify(args)) — fast, collision-resistant enough for dedup.
// Window: last 10 hashes per turn. Checked after each tool round.
// Thresholds: warn at 3 identical hashes, force-break at 5.

const crypto = require('crypto');
const { log } = require('./config');

const LOOP_WARN = 3;
const LOOP_BREAK = 5;
const WINDOW_SIZE = 10;

// Per-turn state. Key = turnId, Value = { hashes: string[], warnInjected: boolean }
const turnState = new Map();

function hashToolCalls(toolCalls) {
    // Hash the SET of tool calls in one iteration (handles alternating-tool loops).
    // Sort by name for deterministic ordering when multiple tools called in parallel.
    const parts = toolCalls
        .map(tc => tc.name + ':' + JSON.stringify(tc.input ?? {}))
        .sort();
    return crypto.createHash('md5').update(parts.join('|')).digest('hex');
}

/**
 * Record a tool round and check for loops.
 *
 * @param {string} turnId - Unique ID for this conversation turn
 * @param {Array<{name: string, input: object}>} toolCalls - Tool calls from this iteration
 * @returns {{ action: 'continue'|'warn'|'break', message?: string }}
 */
function checkLoop(turnId, toolCalls) {
    if (!toolCalls || toolCalls.length === 0) return { action: 'continue' };

    let state = turnState.get(turnId);
    if (!state) {
        state = { hashes: [], warnInjected: false };
        turnState.set(turnId, state);
    }

    const hash = hashToolCalls(toolCalls);
    state.hashes.push(hash);

    // Sliding window: keep only last WINDOW_SIZE
    if (state.hashes.length > WINDOW_SIZE) {
        state.hashes = state.hashes.slice(-WINDOW_SIZE);
    }

    // Count occurrences of the latest hash in the window
    const count = state.hashes.filter(h => h === hash).length;

    if (count >= LOOP_BREAK) {
        log(`[LoopDetector] BREAK — turnId=${turnId} hash=${hash.slice(0, 8)} count=${count} tools=${toolCalls.map(t => t.name).join(',')}`, 'WARN');
        return {
            action: 'break',
            message: `You've called the same tool(s) ${count} times with identical arguments — you are stuck in a loop. STOP using tools and respond to the user with what you have so far. If you encountered an error, explain what went wrong and suggest alternatives.`,
        };
    }

    if (count >= LOOP_WARN && !state.warnInjected) {
        state.warnInjected = true;
        log(`[LoopDetector] WARN — turnId=${turnId} hash=${hash.slice(0, 8)} count=${count} tools=${toolCalls.map(t => t.name).join(',')}`, 'WARN');
        return {
            action: 'warn',
            message: `You appear to be repeating the same tool call (${toolCalls.map(t => t.name).join(', ')}). The previous ${count} attempts produced the same result. Try a different approach, different arguments, or respond with what you know.`,
        };
    }

    return { action: 'continue' };
}

function resetTurn(turnId) {
    turnState.delete(turnId);
}

// Prevent memory leaks: clean up turns older than 10 minutes
function cleanup() {
    // Called periodically from main loop or on new turn
    // Simple approach: if map grows beyond 100 entries, clear oldest half
    if (turnState.size > 100) {
        const keys = [...turnState.keys()];
        for (let i = 0; i < 50; i++) turnState.delete(keys[i]);
    }
}

module.exports = { checkLoop, resetTurn, cleanup, LOOP_WARN, LOOP_BREAK };
```

### Integration Points

**1. Import in claude.js** (after line 6):
```javascript
const { checkLoop, resetTurn, cleanup: cleanupLoopDetector } = require('./loop-detector');
```

**2. Hook after tool execution, before next iteration** — in claude.js, after the tool results are added to messages (after line 1860) and before the checkpoint save (line 1879):

```javascript
// Loop detection: check if we're repeating tool calls
const loopCheck = checkLoop(turnId, parsed.toolCalls);
if (loopCheck.action === 'break') {
    // Inject system guidance and force-exit the tool loop
    messages.push({
        role: 'user',
        content: `[System: ${loopCheck.message}]`,
    });
    log(`[LoopDetector] Breaking tool loop at iteration ${toolUseCount}`, 'WARN');
    break;
}
if (loopCheck.action === 'warn') {
    // Inject warning but let the loop continue
    messages.push({
        role: 'user',
        content: `[System: ${loopCheck.message}]`,
    });
}
```

**3. Reset on new turn** — in `chat()` function, near the top (after turnId is generated, around line 1700):
```javascript
resetTurn(turnId);
cleanupLoopDetector();
```

**4. Reset on turn completion** — after the while loop exits (after line 1895):
```javascript
resetTurn(turnId);
```

### Edge Cases

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | **Legitimate repeated calls with different args** (e.g., reading 5 different files) | Different args produce different hashes. `hashToolCalls()` includes `JSON.stringify(input)`, so `read("a.txt")` and `read("b.txt")` are distinct. No false positive. |
| 2 | **Alternating two-tool loop** (e.g., `read` then `write` then `read` then `write` with same args) | `hashToolCalls()` hashes the SET of calls per iteration, not individual calls. If the model calls `read` alone in iteration 1 and `write` alone in iteration 2, those are different hashes. But if it calls `read+write` as a pair each time, the pair hash repeats and triggers detection. For single-tool alternation, the window captures both hashes — the `count` check only triggers when the SAME hash appears 3+ times, so alternating patterns need 6 iterations minimum (3 of each) before either triggers. This is acceptable. |
| 3 | **MCP tools with identical names from different servers** | MCP tool names are prefixed: `mcp__servername__toolname` (see tools/index.js line 22-33 and main.js line 1128). The full prefixed name is already included in the hash. No collision. |
| 4 | **Cron `agentTurn` sessions** | Same detection applies. Cron turns use the same `chat()` function with a turnId. Loop detection works identically. |
| 5 | **Tool call with non-deterministic args** (e.g., timestamp in args) | These produce different hashes each time, so loop detection won't trigger. This is correct behavior — if the args genuinely differ, it's not a loop. |
| 6 | **Warn message itself causes the model to retry** | The warn message is injected as a `[System: ...]` user message. If the model ignores it and retries, the count reaches LOOP_BREAK (5) and the loop is force-stopped. The two-tier system (warn then break) handles this. |
| 7 | **Memory leak from turnState Map** | `cleanup()` called at the start of each new turn caps the Map at 100 entries. Additionally, `resetTurn()` is called on turn completion. Turns typically last <5 minutes, so the Map stays small. |

### Testing

1. **Trigger a loop intentionally:** Send "fetch https://thisdomaindoesnotexist12345.com and keep trying until it works" — should see warning after 3 attempts, break after 5.
2. **Verify no false positives:** Send "read SOUL.md, MEMORY.md, and IDENTITY.md" — three `read` calls with different args, all should succeed without warnings.
3. **Check logs:** After a loop break, `node_debug.log` should contain `[LoopDetector] BREAK` and `[LoopDetector] WARN` entries.
4. **Verify the response:** After force-break, the agent should respond with a text message explaining what happened, not just go silent.
5. **Token cost:** Compare API costs for a known loop scenario before/after — should see ~80% reduction (5 iterations max vs 25).

### Rollback

- Delete `loop-detector.js` and remove the 3 integration points in `claude.js` (import, hook, reset calls).
- Zero risk: the module is purely additive. Removing it restores the original behavior (loop up to MAX_TOOL_USES).
- **Soft disable:** Add `LOOP_DETECTION_ENABLED = true` flag in config.js. Wrap the `checkLoop()` call in an `if` guard. Set to `false` to disable without code changes.

---

## Feature 2: Context Summarization (P1)

**Priority:** P1 — Improves long conversation quality. Not urgent but high impact.
**Effort:** Medium (~80 lines new code, ~15 lines modifications)
**Risk:** Medium — adds an extra API call per trim cycle, model-dependent quality

### Problem

When context usage hits 90% (line 1465: `CONTEXT_DANGER_THRESHOLD = 0.90`), `adaptiveTrim()` (lines 1550-1587) drops the oldest messages wholesale. This means the agent loses all context from early in the conversation — decisions made, information gathered, user preferences stated. The user then has to repeat themselves.

**Concrete scenario:** User has a 20-message conversation about setting up a Solana swap. They discussed slippage tolerance, token choices, and amount. At message 21, context hits 90%. `adaptiveTrim()` removes the first 10 messages. The agent now has no memory of the slippage discussion and uses the default. User gets a worse swap than expected.

### Solution

Before `adaptiveTrim()` drops messages, summarize them into a compact "conversation recap" message that preserves key decisions and facts.

**New function in claude.js** (add after `adaptiveTrim()`, around line 1588):

```javascript
/**
 * Summarize old messages before they're trimmed, preserving key context.
 * Called when context usage crosses SUMMARIZE_THRESHOLD (85%) — before
 * adaptiveTrim's 90% threshold kicks in.
 *
 * @param {Array} messages - Conversation messages (mutated: oldest N replaced with summary)
 * @param {object} adapter - Provider adapter for API calls
 * @param {string} model - Current model name
 * @param {object} systemBlocks - System prompt blocks
 * @param {string} chatId - Chat ID for API call routing
 * @param {string} turnId - For logging
 * @returns {Promise<boolean>} - true if summarization occurred
 */
const SUMMARIZE_THRESHOLD = 0.85;
const SUMMARIZE_MSG_COUNT = 10; // number of oldest messages to summarize
const SUMMARIZE_MAX_INPUT_CHARS = 4000; // cap input to summarization call
let _lastSummarizedTurnId = null; // only summarize once per turn

async function summarizeOldMessages(messages, adapter, model, systemBlocks, chatId, turnId) {
    // Guard: only summarize once per turn
    if (_lastSummarizedTurnId === turnId) return false;

    // Guard: need enough messages to summarize
    if (messages.length <= MIN_PRESERVED_MESSAGES + SUMMARIZE_MSG_COUNT) return false;

    // Collect oldest messages (skip system messages which aren't in the array)
    const toSummarize = messages.slice(0, SUMMARIZE_MSG_COUNT);

    // Build a text representation of the messages to summarize
    let summaryInput = '';
    for (const msg of toSummarize) {
        const role = msg.role === 'tool' ? 'tool_result' : msg.role;
        let content = '';
        if (msg.role === 'assistant' && msg.toolCalls && msg.toolCalls.length) {
            content = `[Used tools: ${msg.toolCalls.map(tc => tc.name).join(', ')}]`;
            if (msg.content) content += ' ' + msg.content;
        } else {
            content = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content);
        }
        // Truncate individual messages
        if (content.length > 500) content = content.slice(0, 497) + '...';
        summaryInput += `${role}: ${content}\n`;
    }

    // Cap total input
    if (summaryInput.length > SUMMARIZE_MAX_INPUT_CHARS) {
        summaryInput = summaryInput.slice(0, SUMMARIZE_MAX_INPUT_CHARS) + '\n[truncated]';
    }

    // Choose a lighter model for summarization if possible
    const summaryModel = chooseSummaryModel(model);

    const summaryPrompt = [
        {
            role: 'user',
            content: `Summarize this conversation segment in 2-3 concise sentences. Focus on: decisions made, information gathered, user preferences stated, and any action items. Do NOT include greetings, filler, or meta-commentary.\n\n${summaryInput}`,
        }
    ];

    try {
        const apiMessages = adapter.toApiMessages(summaryPrompt);
        const body = adapter.formatRequest(summaryModel, 256, systemBlocks, apiMessages, []);
        const res = await claudeApiCall(body, chatId, { turnId, iteration: -1 });

        if (res.status !== 200) {
            log(`[Summarize] API error ${res.status} — falling back to trim without summary`, 'WARN');
            return false;
        }

        const parsed = adapter.fromApiResponse(res.data);
        const summaryText = (parsed.text || '').trim();

        if (!summaryText || summaryText.length < 10) {
            log('[Summarize] Empty or too-short summary — skipping', 'WARN');
            return false;
        }

        // Replace the oldest messages with a single summary message
        messages.splice(0, SUMMARIZE_MSG_COUNT, {
            role: 'assistant',
            content: `[Summary of earlier conversation: ${summaryText}]`,
        });

        _lastSummarizedTurnId = turnId;
        log(`[Summarize] Replaced ${SUMMARIZE_MSG_COUNT} messages with summary (${summaryText.length} chars) | turnId=${turnId}`, 'INFO');
        return true;
    } catch (err) {
        log(`[Summarize] Failed: ${err.message} — falling back to trim`, 'WARN');
        return false;
    }
}

/**
 * Pick a cheaper/faster model for summarization.
 * Falls back to the current model if no lighter option is known.
 */
function chooseSummaryModel(currentModel) {
    // Claude: use Haiku if current model is Sonnet/Opus
    if (currentModel.includes('opus') || currentModel.includes('sonnet')) {
        return 'claude-haiku-4-5';
    }
    // OpenAI: use gpt-4o-mini
    if (currentModel.includes('gpt')) {
        return 'gpt-4o-mini';
    }
    // OpenRouter or unknown: use same model (can't assume what's available)
    return currentModel;
}
```

### Integration Points

**1. Hook in the tool loop** — in claude.js, before the trim-recheck loop (before line 1737):

```javascript
// Context summarization: if usage is high but not yet critical, summarize before trimming
if (ctx.usage >= SUMMARIZE_THRESHOLD && ctx.usage < CONTEXT_DANGER_THRESHOLD) {
    await summarizeOldMessages(messages, adapter, MODEL, systemBlocks, chatId, turnId);
    // Recheck context after summarization
    ctx = checkContextUsage(systemBlocks, messages, formattedTools, MODEL, turnId, _ctxCache);
}
```

**2. Also hook before the existing trim loop** — if context is already at 90%+ (line 1737), summarize first:

```javascript
// Even at danger threshold, try to summarize before we trim
if (ctx.usage >= CONTEXT_DANGER_THRESHOLD && messages.length > MIN_PRESERVED_MESSAGES) {
    await summarizeOldMessages(messages, adapter, MODEL, systemBlocks, chatId, turnId);
    ctx = checkContextUsage(systemBlocks, messages, formattedTools, MODEL, turnId, _ctxCache);
}
```

**3. Reset the per-turn flag** — in `chat()`, near the top:
```javascript
_lastSummarizedTurnId = null; // reset is handled by turnId comparison
```
(Actually, since the flag compares `turnId`, no explicit reset is needed. Each turn has a unique ID.)

### Edge Cases

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | **Summarization API call fails** (network error, rate limit, model unavailable) | Caught in try/catch. Logs warning, returns `false`. `adaptiveTrim()` proceeds normally — same behavior as today. No user impact. |
| 2 | **Summarization exceeds context itself** | Input is capped at `SUMMARIZE_MAX_INPUT_CHARS = 4000` chars (~1000 tokens). Output is capped at `max_tokens: 256`. Total summarization call is ~1300 tokens — well within any model's context. |
| 3 | **Tool-use pairs in the summary window** | Tool results are represented as `[Used tools: tool_name]` in the summary input, not the full result. The summary captures WHAT was done, not the raw data. This prevents the summary from being as large as the original. |
| 4 | **Multiple trim cycles in one turn** | `_lastSummarizedTurnId` check ensures we only summarize once per turn. After the first summarization, subsequent trims drop messages without re-summarizing. This prevents recursive API calls. |
| 5 | **OpenRouter with unknown models** | `chooseSummaryModel()` returns the current model for OpenRouter. Slightly more expensive but guarantees availability. The `OPENROUTER_FALLBACK_MODEL` from config.js could be used here as an enhancement, but the current model is the safe default. |
| 6 | **Summary contains hallucinated information** | The summary prompt is tightly scoped ("Focus on: decisions made, information gathered..."). The output is wrapped in `[Summary of earlier conversation: ...]` brackets so the model knows it's a compressed recap, not a verbatim record. Hallucination risk is low because the input is the actual conversation, not external knowledge. |
| 7 | **Cost of extra API call** | Haiku at ~$0.25/M input tokens: ~1000 tokens in + 100 out = ~$0.0003 per summarization. This happens at most once per turn, and only when context is nearly full. At 5,300 users, assume 10% hit summarization daily = 530 calls/day = $0.16/day. Negligible. |

### Testing

1. **Force high context:** Send a series of long messages (paste a 3000-word text, ask questions about it, repeat 5 times). Watch `node_debug.log` for `[Summarize]` entries.
2. **Verify summary quality:** After summarization, ask the agent "what did we discuss earlier?" — it should be able to recall key points from the summarized segment.
3. **Compare with/without:** Run the same long conversation with and without summarization. Without: agent loses early context. With: agent retains key decisions.
4. **Cost tracking:** Check `api_request_log` table for summarization calls (they'll have `iteration: -1`).
5. **Failure mode:** Temporarily block API access mid-conversation (airplane mode for 2s during trim) — verify the app recovers and trims normally.

### Rollback

- Remove the `summarizeOldMessages()` function and its two hook points in the tool loop.
- **Soft disable:** Add `CONTEXT_SUMMARIZATION_ENABLED = true` in config.js. Wrap both hook points in an `if` guard. Set to `false` to disable.
- Rollback is safe: the feature only ADDS a summary message before trimming. Without it, trimming works exactly as it does today.

---

## Feature 3: Clarification Tool (P1)

**Priority:** P1 — Reduces wasted tool calls from ambiguous requests.
**Effort:** Medium (~100 lines new tool code, ~25 lines routing modifications)
**Risk:** Medium — changes message interception flow, adds a new pending state

### Problem

When the user sends an ambiguous request, the agent guesses and often guesses wrong. This wastes tool calls, API tokens, and user time. There's no structured way for the agent to pause, ask for clarification, and resume.

**Concrete scenario:** User says "send 10 to Alice." Agent doesn't know: 10 what? SOL? USDC? SPL token? Send via Telegram? Solana transfer? SMS? The agent picks `solana_send` with SOL, triggers the confirmation gate, user sees "Send 10 SOL to Alice?" and says NO because they meant 10 USDC. Two wasted API calls + one failed confirmation.

### Solution

A structured `ask_clarification` tool that pauses execution, sends a formatted question to the user via Telegram, waits for their answer, and returns it as the tool result.

**New tool definition in `tools/system.js`** (add after `js_eval` tool, line 40):

```javascript
{
    name: 'ask_clarification',
    description: 'Ask the user a clarifying question and wait for their answer. Use this when the user\'s request is ambiguous, when you need to choose between multiple approaches, or before expensive/destructive operations where you\'re unsure of intent. The user will see the question in Telegram and can reply with text. 120s timeout. Max 3 uses per conversation turn. Do NOT use this for simple yes/no confirmations — those are handled by the confirmation gate on high-impact tools.',
    input_schema: {
        type: 'object',
        properties: {
            question: {
                type: 'string',
                description: 'The question to ask the user. Be specific and concise.',
            },
            clarification_type: {
                type: 'string',
                enum: ['missing_info', 'ambiguous_requirement', 'approach_choice', 'risk_confirmation'],
                description: 'Category of clarification needed. missing_info: required data not provided. ambiguous_requirement: request could mean multiple things. approach_choice: multiple valid approaches, need user preference. risk_confirmation: action has consequences, want to verify intent.',
            },
            options: {
                type: 'array',
                items: { type: 'string' },
                description: 'Optional numbered choices for the user. If provided, displayed as a numbered list. User can reply with a number or free text.',
            },
        },
        required: ['question', 'clarification_type'],
    },
},
```

**Handler in `tools/system.js`:**

```javascript
async ask_clarification(input, chatId) {
    // Rate limit: max 3 clarifications per turn
    const key = `clarify_${chatId}`;
    const count = (clarificationCounts.get(key) || 0) + 1;
    if (count > 3) {
        return {
            skipped: true,
            reason: 'rate_limit',
            message: 'Maximum 3 clarifications per turn. Proceed with your best judgment.',
        };
    }
    clarificationCounts.set(key, count);

    // Cron sessions: can't ask user for input
    if (_isCronSession && _isCronSession(chatId)) {
        return {
            skipped: true,
            reason: 'cron_session',
            message: 'Cannot ask clarification in a cron session. Proceed with your best judgment or skip.',
        };
    }

    // Format the question
    let text = `\u2753 *Clarification needed*\n\n${input.question}`;
    if (input.options && input.options.length > 0) {
        text += '\n\n';
        input.options.forEach((opt, i) => {
            text += `${i + 1}. ${opt}\n`;
        });
        text += '\n_Reply with a number or your own answer._';
    } else {
        text += '\n\n_Reply with your answer._';
    }

    // Use the shared pending-reply mechanism
    const answer = await requestClarification(chatId, text, 120000);

    if (answer === null) {
        return {
            timeout: true,
            message: 'User did not respond within 120 seconds. Proceed with your best judgment or explain that you need more information.',
        };
    }

    // If options were provided and user replied with a number, resolve to the option text
    let resolvedAnswer = answer;
    if (input.options && input.options.length > 0) {
        const num = parseInt(answer, 10);
        if (num >= 1 && num <= input.options.length) {
            resolvedAnswer = input.options[num - 1];
        }
    }

    return {
        answer: resolvedAnswer,
        raw_reply: answer,
        clarification_type: input.clarification_type,
    };
},
```

**Shared pending state in `tools/index.js`** (add near line 58, alongside `pendingConfirmations`):

```javascript
const pendingClarifications = new Map(); // chatId -> { resolve, timer, question }
const clarificationCounts = new Map();   // chatId -> count (reset per turn)

function requestClarification(chatId, formattedQuestion, timeoutMs = 120000) {
    return new Promise((resolve) => {
        // Reject if already pending
        if (pendingClarifications.has(chatId)) {
            resolve(null);
            return;
        }

        // Send question to user
        telegram('sendMessage', {
            chat_id: chatId,
            text: formattedQuestion,
            parse_mode: 'Markdown',
        }).catch(err => log(`[Clarify] Failed to send question: ${err.message}`, 'ERROR'));

        const timer = setTimeout(() => {
            pendingClarifications.delete(chatId);
            resolve(null);
        }, timeoutMs);

        pendingClarifications.set(chatId, { resolve, timer, question: formattedQuestion });
    });
}
```

### Integration Points

**1. Message interception in main.js** — modify the polling handler (lines 961-984) to check `pendingClarifications` BEFORE `pendingConfirmations`:

```javascript
// Check for pending clarification first
const pendingClarify = pendingClarifications.get(msgChatId);
if (pendingClarify && isPlainText) {
    log(`[Clarify] User replied "${msgText.slice(0, 50)}" for pending clarification`, 'INFO');
    clearTimeout(pendingClarify.timer);
    pendingClarify.resolve(msgText);
    pendingClarifications.delete(msgChatId);
} else if (pending && isPlainText) {
    // ... existing confirmation handling (lines 968-984)
```

The clarification check must come first because clarifications are more conversational — any text reply is a valid answer, unlike confirmations which require YES/NO.

**2. Export from tools/index.js** — add `pendingClarifications`, `requestClarification`, and `clarificationCounts` to exports.

**3. Wire cron session detection** — in main.js, pass `isCronSession` to the system tool module so it can check if the current session is a cron job:

```javascript
systemMod._setIsCronSession((chatId) => cronSessions.has(String(chatId)));
```

**4. Reset clarification count per turn** — in claude.js `chat()`, before the tool loop:

```javascript
clarificationCounts.delete(`clarify_${chatId}`);
```

**5. System prompt addition** — in `buildSystemBlocks()` (line 369 of claude.js), add to the Tooling section:

```
- **ask_clarification**: Pause and ask the user a question when their request is ambiguous. Use before expensive operations (swaps, sends) when you're unsure of details. Do NOT overuse — only when genuinely needed. You have max 3 per turn.
```

### Edge Cases

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | **User sends unrelated message during clarification** | Unlike confirmations (which require YES/NO), clarifications accept any text as an answer. This matches user expectations — they're having a conversation, not confirming an action. If the reply is truly unrelated, the agent can interpret it in context. |
| 2 | **Agent calls ask_clarification repeatedly** | Rate limited to 3 per conversation turn via `clarificationCounts` Map. After 3, the tool returns `{ skipped: true, reason: 'rate_limit' }` and the agent must proceed with its best guess. |
| 3 | **Timeout (user doesn't respond in 120s)** | Returns `{ timeout: true }`. The agent should either proceed with its best judgment or explain that it needs more information. The 120s timeout is double the confirmation timeout (60s) because users need more time to think about open-ended questions. |
| 4 | **Multiple pending clarifications** | Only one at a time per chatId. If `pendingClarifications.has(chatId)` is true when a second clarification is attempted, the Promise resolves immediately with `null`. The agent receives `{ timeout: true }` and must proceed. |
| 5 | **User sends a photo/document instead of text** | The `isPlainText` check (line 965-966) filters non-text messages. The clarification remains pending. The user sees no explicit error (same as confirmation flow). After 120s, it times out. Improvement for later: handle captions on photos. |
| 6 | **Clarification during a confirmation** | If a confirmation is pending (user needs to YES/NO a swap), clarification is blocked by the `pendingClarifications.has()` guard because both share the chatId key space but use different Maps. The agent gets `null` and must wait. In practice, this shouldn't happen because the tool loop is synchronous — only one tool executes at a time. |
| 7 | **Cron agentTurn sessions** | Automatically skipped with `{ skipped: true, reason: 'cron_session' }`. Cron sessions have no user interaction — the agent must proceed autonomously. |

### Testing

1. **Ambiguous request:** Send "send 10 to Alice" — agent should use `ask_clarification` to ask "10 what? SOL, USDC, or something else? And do you mean a Solana transfer or a Telegram message?"
2. **Numbered options:** Verify the numbered list renders correctly in Telegram and that replying "2" resolves to the second option.
3. **Timeout:** Send an ambiguous request, don't reply for 2 minutes — agent should proceed with best guess or explain it needed more info.
4. **Rate limit:** In one turn, trigger 4 clarifications — the 4th should return `skipped: true`.
5. **Cron session:** Set up a cron `agentTurn` that would normally trigger clarification — verify it's auto-skipped.

### Rollback

- Remove the `ask_clarification` tool from `tools/system.js`.
- Remove the `pendingClarifications` Map and `requestClarification()` from `tools/index.js`.
- Remove the clarification check from main.js message interception (revert to original lines 961-984).
- **Soft disable:** Remove `ask_clarification` from the TOOLS array export. The handler can stay — it just won't be callable.

---

## Feature 4: Memory Session Scrubbing (P1)

**Priority:** P1 — Prevents memory pollution. High value, low effort.
**Effort:** Small (~40 lines new code, ~5 lines modifications)
**Risk:** Low — only affects new memory saves, never touches existing files

### Problem

The agent saves transient, session-specific artifacts to long-term memory (MEMORY.md and daily notes). Over time, memory fills with useless entries like "I used the web_fetch tool to check the website" or "user uploaded file IMG_20260321.jpg" that have no value in future conversations. This wastes context tokens when memory is loaded into the system prompt and makes `memory_search` results noisy.

**Concrete scenario:** User asks the agent to research a topic. Agent saves: "I searched for 'Solana DePIN' using web_search. I then used web_fetch to read 3 articles. I used the read tool to check MEMORY.md." None of this is useful next week. Meanwhile, the actual insight ("Helium is the largest DePIN on Solana with 900K hotspots") gets buried under noise.

### Solution

A content scrubber that strips session-specific artifacts before writing to memory files.

**New function in `tools/memory.js`** (add near the top, after imports):

```javascript
// ── Memory scrubbing ────────────────────────────────────────────────────────
//
// Strip transient session artifacts from memory content before saving.
// These patterns are meaningless in future sessions and waste context tokens.

const SCRUB_ENABLED = true; // config flag — can be moved to config.js if needed

// Pre-compiled patterns for performance
const SCRUB_PATTERNS = [
    // Tool execution self-narration: "I used/called/ran the X tool"
    /\bI\s+(?:used|called|ran|executed|invoked)\s+(?:the\s+)?\w+(?:_\w+)*\s+tool\b/gi,

    // File upload references: "uploaded file X.jpg" (but NOT "uploaded resume to LinkedIn")
    /\buploaded?\s+(?:the\s+)?(?:file|image|photo|document|video|audio)\s+\S+/gi,

    // Telegram message IDs (never useful in future sessions)
    /\bmessage\s*#?\d{5,}\b/gi,

    // Temporary file paths
    /\/tmp\/\S+/gi,

    // Session-specific timestamps without dates: "at 3:45 PM" (but NOT "at 2026-03-21 3:45 PM")
    // Only match times NOT preceded by a date pattern
    /(?<!\d{4}-\d{2}-\d{2}\s)(?<!\d{1,2}\/\d{1,2}\/\d{2,4}\s)\bat\s+\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)\b/gi,

    // "I then..." narration filler (common in tool chains)
    /\bI\s+then\s+(?:used|called|ran|checked|opened|read|fetched|searched)\b/gi,
];

function scrubSessionContent(content) {
    if (!SCRUB_ENABLED || !content) return content;

    let scrubbed = content;
    let scrubCount = 0;

    for (const pattern of SCRUB_PATTERNS) {
        // Reset regex state (global flag)
        pattern.lastIndex = 0;
        const before = scrubbed;
        scrubbed = scrubbed.replace(pattern, '');
        if (scrubbed !== before) scrubCount++;
    }

    // Clean up artifacts: multiple spaces, empty lines, leading/trailing whitespace
    scrubbed = scrubbed
        .replace(/  +/g, ' ')           // collapse multiple spaces
        .replace(/\n\s*\n\s*\n/g, '\n\n') // collapse triple+ newlines to double
        .trim();

    if (scrubCount > 0) {
        log(`[MemoryScrub] Scrubbed ${scrubCount} pattern matches from memory save`, 'DEBUG');
    }

    // If scrubbing removed everything meaningful, return null to signal "don't save"
    if (scrubbed.length < 10) {
        log('[MemoryScrub] Content too short after scrubbing — skipping save', 'INFO');
        return null;
    }

    return scrubbed;
}
```

### Integration Points

**1. Hook in `memory_save` handler** — `tools/memory.js` line 91-96:

```javascript
async memory_save(input, chatId) {
    const scrubbedContent = scrubSessionContent(input.content);
    if (scrubbedContent === null) {
        return { success: true, message: 'Memory save skipped (content was session-specific only)' };
    }
    const currentMemory = loadMemory();
    const newMemory = currentMemory + '\n\n---\n\n' + redactSecrets(scrubbedContent);
    saveMemory(newMemory.trim());
    return { success: true, message: 'Memory saved' };
},
```

**2. Hook in `daily_note` handler** — `tools/memory.js` line 103-106:

```javascript
async daily_note(input, chatId) {
    const scrubbedNote = scrubSessionContent(input.note);
    if (scrubbedNote === null) {
        return { success: true, message: 'Daily note skipped (content was session-specific only)' };
    }
    appendDailyMemory(redactSecrets(scrubbedNote));
    return { success: true, message: 'Note added to daily memory' };
},
```

### Edge Cases

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | **False positive: "I uploaded my resume to LinkedIn"** | The upload pattern requires "uploaded file/image/photo/document X" — it matches the noun (file, image, etc.) between "uploaded" and the filename. "uploaded my resume to LinkedIn" does NOT match because "resume" is not in the noun list. Verified by regex: `/\buploaded?\s+(?:the\s+)?(?:file\|image\|photo\|document\|video\|audio)\s+\S+/gi` won't match "uploaded my resume to LinkedIn". |
| 2 | **Agent saving distilled tool results as memory** | If the agent writes "User's website example.com returns a 404 error" — this has no tool narration patterns and passes through unchanged. Only self-referential narration ("I used web_fetch...") is scrubbed, not factual observations. |
| 3 | **Empty content after scrubbing** | Returns `null`, which signals the handler to skip the save entirely. The tool still returns `success: true` so the agent doesn't think it failed — it just reports the save was skipped. |
| 4 | **Daily notes vs MEMORY.md** | Same scrubbing applies to both. Both handlers call `scrubSessionContent()` before writing. |
| 5 | **Regex performance** | Patterns are compiled once at module load (top-level `const`), not per-call. For a typical memory save of 200-500 chars, regex execution takes <1ms. Not a concern. |
| 6 | **Existing memory not affected** | Scrubbing only applies to NEW saves. Existing MEMORY.md content is never modified. If users want to clean existing memory, they can use "WIPE MEMORY" in Settings. |
| 7 | **Scrub pattern matches inside quoted user speech** | If the user said "I used the web_search tool" and the agent saves that as a quote, the scrubber would remove it. This is an acceptable trade-off: direct quotes of tool narration are rare and low-value. If it becomes an issue, we can add a "quoted text" exclusion pattern. |

### Testing

1. **Tool narration:** Have the agent save "I used the web_search tool to find information about Bitcoin. Bitcoin is currently trading at $95,000." — verify only the first sentence is removed, the fact about Bitcoin remains.
2. **Clean content:** Save "User prefers dark roast coffee and lives in San Francisco" — verify nothing is scrubbed.
3. **All-noise content:** Have the agent save "I used the read tool to check the file. I then called web_fetch." — verify the save is skipped entirely (too short after scrubbing).
4. **Daily note:** Same tests but via `daily_note` tool.
5. **Log monitoring:** Check `node_debug.log` for `[MemoryScrub]` entries to verify scrubbing is happening.

### Rollback

- Set `SCRUB_ENABLED = false` at the top of the scrub function. Zero code changes needed.
- Or: revert the two handler modifications (4 lines each) to restore original behavior.
- **No data risk:** This feature only prevents writing noise — it never deletes or modifies existing memory.

---

## Feature 5: Deferred Tool Loading (P2)

**Priority:** P1 — Critical for OpenRouter/OpenAI cost savings. Per-provider strategy.
**Effort:** Medium (~100 lines new code, ~30 lines modifications — simpler with adapter pattern)
**Risk:** Medium — only affects non-Claude providers; Claude behavior unchanged

### Problem

Every API call sends the full tool schema payload (~40KB, ~80 tools). This consumes tokens on every turn, even for simple "hello" messages where no tools are needed. With Claude's prompt caching, the first call per session pays the full cost and subsequent calls get cached pricing — but the schemas still consume context window space, reducing room for conversation history.

**Concrete scenario:** User sends "good morning." The API call includes 40KB of tool schemas (Solana swap parameters, Android bridge endpoints, MCP server tools...) even though the response will be "Good morning! How can I help you today?" That's ~10,000 tokens of tool schema for a greeting.

### Solution

A `tool_search` meta-tool that lets the agent discover and load tool schemas on demand, with a small set of always-available core tools.

**WARNING: This feature has significant trade-offs. See [Challenge & Risk Assessment](#challenge--risk-assessment) for why this may not be worth building.**

**New tool in `tools/system.js`:**

```javascript
{
    name: 'tool_search',
    description: 'Search for available tools by keyword. Returns matching tool names with full schemas so you can use them. Use when you need a capability not in your always-available tools (read, write, web_search, web_fetch, datetime, memory_save, ask_clarification). Example: tool_search("solana swap") returns the solana_swap tool schema.',
    input_schema: {
        type: 'object',
        properties: {
            query: {
                type: 'string',
                description: 'Search query — tool name, keyword, or description of what you need.',
            },
            max_results: {
                type: 'number',
                description: 'Maximum tools to return (default: 5, max: 10).',
            },
        },
        required: ['query'],
    },
},
```

**Handler:**

```javascript
async tool_search(input, chatId) {
    const query = (input.query || '').toLowerCase().trim();
    if (!query) return { error: 'query is required' };

    const maxResults = Math.min(input.max_results || 5, 10);
    const allTools = _getAllTools ? _getAllTools() : [];

    // Score each tool against the query
    const scored = allTools.map(tool => {
        const name = (tool.name || '').toLowerCase();
        const desc = (tool.description || '').toLowerCase();
        let score = 0;

        // Exact name match
        if (name === query) score += 100;
        // Name contains query
        else if (name.includes(query)) score += 50;
        // Query words in name
        const words = query.split(/\s+/);
        for (const w of words) {
            if (name.includes(w)) score += 20;
            if (desc.includes(w)) score += 5;
        }

        return { tool, score };
    })
    .filter(s => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, maxResults);

    if (scored.length === 0) {
        return {
            matches: [],
            message: `No tools found matching "${input.query}". Try different keywords.`,
        };
    }

    return {
        matches: scored.map(s => ({
            name: s.tool.name,
            description: s.tool.description,
            input_schema: s.tool.input_schema,
            score: s.score,
        })),
    };
},
```

**Deferred mode in claude.js** — when enabled, modify `getTools()` call at line 1723:

```javascript
const rawTools = _deps.getTools ? _deps.getTools() : [];

let formattedTools;
if (DEFERRED_TOOL_MODE) {
    // Only send core tools + any tools discovered via tool_search this turn
    const coreNames = new Set(['read', 'write', 'web_search', 'web_fetch', 'datetime',
        'memory_save', 'ask_clarification', 'tool_search']);
    const coreTools = rawTools.filter(t => coreNames.has(t.name) || discoveredTools.has(t.name));
    formattedTools = adapter.formatTools(coreTools);

    // Inject tool catalog into system prompt (names + one-line descriptions)
    // This is added once per turn, not per iteration
    if (toolUseCount === 0) {
        const catalog = rawTools
            .filter(t => !coreNames.has(t.name))
            .map(t => `- ${t.name}: ${(t.description || '').split('.')[0]}`)
            .join('\n');
        systemBlocks.push({
            type: 'text',
            text: `\n## Available Tools (use tool_search to load full schema)\n${catalog}`,
        });
    }
} else {
    formattedTools = adapter.formatTools(rawTools);
}
```

**Track discovered tools per turn:**

```javascript
// At top of chat(), alongside other per-turn state
const discoveredTools = new Set();

// In tool_search handler result processing (after tool execution, ~line 1853):
if (toolUse.name === 'tool_search' && result && result.matches) {
    for (const match of result.matches) {
        discoveredTools.add(match.name);
    }
}
```

### Integration Points

**1. Config flag** — in config.js:
```javascript
const DEFERRED_TOOL_MODE = false; // P2: Experimental — enable for token savings
```

**2. System prompt modification** — in `buildSystemBlocks()` (line 369), add conditional section:
```
## Tool Discovery
You have a set of always-available tools (read, write, web_search, web_fetch, datetime, memory_save, ask_clarification).
For any other capability, use tool_search("keyword") to find and load the appropriate tool.
After tool_search returns a tool's schema, you can use that tool in subsequent calls within this turn.
```

**3. Tool result injection** — the `tool_search` results include full `input_schema`, which the agent uses to construct the next tool call. The `discoveredTools` set ensures the schema is included in the next API call's tool list.

### Edge Cases

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | **Agent doesn't know to use tool_search** | System prompt explicitly teaches this. The tool catalog in the system prompt lists all available tools by name, so the agent knows what exists. |
| 2 | **Two-step overhead: search then use** | Every non-core tool use costs an extra API round-trip. For tool-heavy conversations, this INCREASES total cost. Only valuable for short, simple conversations. |
| 3 | **Claude prompt caching already amortizes tool schema cost** | With `cache_control: { type: 'ephemeral' }` on the last tool, Claude caches the entire tool list after the first call. Subsequent calls in the same turn pay ~10% of the original token cost. The savings from deferred loading may be minimal on cached turns. |
| 4 | **MCP tools change dynamically** | `tool_search` queries the live `_getAllTools()` each time, so it reflects current MCP server state. But if an MCP server disconnects between the search and the use, the tool won't be in the `rawTools` list. The `discoveredTools` set only adds names — if the actual tool object is gone, it won't be included. The agent gets a "tool not found" error and can re-search. |
| 5 | **Confirmation-gated tools returned by tool_search** | Still gated. The `CONFIRM_REQUIRED` check happens at execution time (line 1800), not at schema-loading time. Discovering a tool via `tool_search` doesn't bypass confirmation. |
| 6 | **Provider compatibility** | `tool_search` is a regular tool — works with any provider. The deferred mode filtering happens before `adapter.formatTools()`, so it's provider-agnostic. |
| 7 | **Agent calls tool_search for a core tool** | The search returns it with full schema (it's in the allTools list). The agent can then use it normally. No harm done, just a wasted call. The system prompt should clarify which tools are always available. |

### Testing

1. **Enable deferred mode:** Set `DEFERRED_TOOL_MODE = true` in config.js.
2. **Simple greeting:** Send "hello" — verify the API call only includes ~8 core tool schemas, not all 80.
3. **Tool discovery:** Send "what's the SOL price?" — agent should call `tool_search("solana price")`, get `solana_price` schema, then call it.
4. **Token comparison:** Log token usage per API call with and without deferred mode. Expect ~30% reduction on first call, less on cached calls.
5. **Edge case:** Send "swap 1 SOL for USDC" — agent needs `tool_search("solana swap")` then `solana_swap`, plus confirmation. Verify the full flow works.

### Rollback

- Set `DEFERRED_TOOL_MODE = false` (default). The `tool_search` tool still exists but the deferred loading logic is bypassed — all tools are sent every call as before.
- This is the safest rollback of all 5 features because the flag is off by default.

---

## Challenge & Risk Assessment

Honest evaluation of each feature's risks, trade-offs, and whether it should actually be built.

### Feature 1: Loop Detection — BUILD IT

**Verdict: Strong YES.** This is a clear win with no meaningful downside.

- **Risk:** Negligible. The detector is purely additive — it only activates when the same tool+args hash appears 3+ times. Normal tool use never triggers it.
- **Counter-argument:** "What if the model has a legitimate reason to retry?" — If the args are identical, the result will be identical. Retrying the same `web_fetch("https://down-site.com")` 25 times is never useful. If the model CHANGES args (different URL, different query), the hash changes and detection doesn't trigger.
- **Cost:** Zero runtime cost when no loop is detected. MD5 hashing of tool args is <0.1ms. Map cleanup is O(1) amortized.
- **Production risk:** The warn-then-break two-tier system means even if the thresholds are wrong, the worst case is breaking a legitimate loop early — which still saves tokens. Ship with logging, tune thresholds based on data.

### Feature 2: Context Summarization — BUILD WITH CAUTION

**Verdict: Conditional YES.** High value but needs careful monitoring.

- **Risk:** The summarization API call adds latency (2-5s) and cost (~$0.0003/call). If the summary is poor quality, the agent operates on incorrect context — worse than having no context at all.
- **Counter-argument:** "adaptiveTrim already works fine" — No, it doesn't. It drops messages silently, causing the agent to forget user decisions. The user experience degrades noticeably in long conversations.
- **Key risk: model quality.** Haiku 4.5 summarizing a complex Solana transaction discussion may miss critical details (amounts, addresses, slippage). Mitigation: the summary is additive (it REPLACES messages that would have been dropped entirely). Even a mediocre summary is better than no context.
- **Key risk: latency.** An extra API call during an already-slow context-management phase. On mobile networks, this could add 3-8s. Mitigation: the summarization only happens once per turn, and only when context is nearly full — which means the conversation is already long and the user expects slower responses.
- **Ship with `CONTEXT_SUMMARIZATION_ENABLED = false` initially.** Enable for beta users, monitor API logs for summary quality and latency.

### Feature 3: Clarification Tool — BUILD IT

**Verdict: YES, with scope limits.**

- **Risk:** Changes the message interception flow in main.js (lines 961-984), which is the most sensitive code path — every incoming message passes through it. A bug here could cause messages to be swallowed or misrouted.
- **Counter-argument:** "The agent can just ask in its text response" — It can, but then it loses the tool-use context. If the agent responds with text ("What token?"), the next user message starts a new tool-use turn from scratch. With `ask_clarification`, the answer is injected as a tool result and the agent continues the SAME turn with full context.
- **Key risk: overuse.** If the agent uses `ask_clarification` for everything ("What format?" "What timezone?" "Are you sure?"), it becomes annoying. Mitigation: rate limit (3/turn), system prompt guidance, and the `clarification_type` enum helps the model self-check whether it really needs to ask.
- **Key risk: message interception ordering.** Checking `pendingClarifications` before `pendingConfirmations` means a confirmation reply could be captured as a clarification answer if both are pending simultaneously. Mitigation: this can't happen because the tool loop is synchronous — only one pending state exists at a time per chatId.
- **Production risk: low.** The pattern mirrors the existing confirmation flow (which has been stable since BAT-255). Same Promise-based architecture, same Map-based pending state, same timeout mechanism.

### Feature 4: Memory Session Scrubbing — BUILD IT

**Verdict: Strong YES.** Highest value-to-effort ratio of all 5 features.

- **Risk:** Extremely low. Only affects new memory saves. Never touches existing files. Regex-based, deterministic, fast.
- **Counter-argument:** "Let the AI decide what to save" — The AI already decides, and it decides poorly. Models consistently narrate their tool usage when saving memory. This is a well-known pattern across all LLM agents.
- **Key risk: false positives.** A regex might strip useful content. Mitigation: patterns are narrowly targeted (tool narration, file uploads, temp paths, message IDs). The content "Bitcoin hit $95K" or "User prefers dark mode" will never match these patterns. And if the entire content is scrubbed, we skip the save rather than saving empty content.
- **Production risk: minimal.** Ship with `SCRUB_ENABLED = true`. If users report missing memories, set to `false` and investigate.

### Feature 5: Deferred Tool Loading — PER-PROVIDER STRATEGY

**Verdict: BUILD — but only for non-Claude providers. Claude keeps full schemas + caching.**

**Strategy:**
- **Claude:** Full tool schemas + `cache_control: { type: 'ephemeral' }` on last tool. Already efficient. No change.
- **OpenAI / OpenRouter:** Deferred tool loading. Send only 5 always-available tools + `tool_search`. ~80% token savings.

**Why per-provider works:**
1. The adapter pattern already handles per-provider tool formatting via `formatTools()`.
2. Claude users see zero change — same behavior, same caching, same quality.
3. OpenRouter users (growing segment, 100+ models, no prompt caching) get massive savings.

**Implementation:**
```javascript
// In claude.js, before tool formatting (line 1723):
const useDeferredTools = PROVIDER !== 'claude';
const toolsToSend = useDeferredTools
    ? filterToAlwaysAvailable(rawTools)  // 5 core + tool_search + discovered this turn
    : rawTools;                           // All 80+ tools (Claude caches these)
```

**Remaining risks:**
- OpenRouter models may struggle with `tool_search` — needs good system prompt guidance
- First tool use takes 2 round-trips instead of 1
- `discoveredTools` set must persist across iterations within a turn

---

## Priority & Dependencies

### Build Order

```
Phase 1 (Ship together):
  [1] Loop Detection (P0)     ← No dependencies, standalone module
  [4] Memory Scrubbing (P1)   ← No dependencies, standalone function

Phase 2 (Ship together, after Phase 1 is stable):
  [5] Deferred Tool Loading (P1) ← Per-provider: OpenAI/OpenRouter only, Claude unchanged
  [3] Clarification Tool (P1) ← No dependencies, but changes message interception

Phase 3 (After real usage data):
  [2] Context Summarization (P2) ← Already have adaptiveTrim, build when users report context loss
```

### Dependency Graph

```
Loop Detection ──── (none)
Memory Scrubbing ── (none)
Clarification Tool ─┬─ pendingConfirmations pattern (existing, stable)
                    └─ message interception (main.js lines 961-984)
Context Summarization ─┬─ adapter.formatRequest() (existing)
                       ├─ claudeApiCall() (existing)
                       └─ chooseSummaryModel() depends on provider knowledge
Deferred Tool Loading ─┬─ tool_search requires all tools accessible
                       ├─ discoveredTools state in claude.js tool loop
                       └─ system prompt modifications in buildSystemBlocks()
```

### Why This Order

1. **Loop Detection + Memory Scrubbing first:** Both are zero-dependency, low-risk, high-value. They can be code-reviewed and shipped in a single PR. If anything breaks, they're trivially reversible.

2. **Clarification Tool + Context Summarization second:** Both modify core code paths (message interception, tool loop). They should be shipped after Phase 1 is stable in production to avoid debugging overlapping changes. The Clarification Tool should land first within Phase 2 because it's lower risk (follows existing confirmation pattern).

3. **Context Summarization last:** We already have `adaptiveTrim()`. Build summarization when users report "the agent forgot what we discussed" — real evidence vs theoretical improvement.

---

## Effort Summary

| # | Feature | Priority | Effort | Risk | New Lines | Modified Lines | Files Changed | Recommended |
|---|---------|----------|--------|------|-----------|----------------|---------------|-------------|
| 1 | Loop Detection | P0 | Small | Low | ~60 | ~15 | 2 (`loop-detector.js` new, `claude.js`) | YES |
| 4 | Memory Session Scrubbing | P1 | Small | Low | ~40 | ~10 | 1 (`tools/memory.js`) | YES |
| 5 | Deferred Tool Loading | P1 | Medium | Medium | ~100 | ~30 | 3 (`tools/system.js`, `claude.js`, `config.js`) | YES (OpenAI/OpenRouter only) |
| 3 | Clarification Tool | P1 | Medium | Medium | ~100 | ~25 | 4 (`tools/system.js`, `tools/index.js`, `main.js`, `claude.js`) | YES |
| 2 | Context Summarization | P2 | Medium | Medium | ~80 | ~15 | 2 (`claude.js`, `config.js`) | DEFER (build on user demand) |

**Total recommended effort:** ~300 new lines + ~80 modified lines across 7 files.

**Estimated timeline:**
- Phase 1 (Features 1 + 4): 1 day implementation + 1 day testing = 2 days
- Phase 2 (Features 5 + 3): 2 days implementation + 2 days testing = 4 days
- Phase 3 (Feature 2): On demand, ~2 days when needed
- Total: ~1 week for Phase 1 + 2

**Token cost impact:**
- Loop Detection: **saves** $0.25-2.50 per stuck loop (estimated 10-50 loops/day across all users)
- Context Summarization: **costs** ~$0.16/day additional (~$5/month), but prevents wasted tool calls from lost context
- Clarification Tool: **saves** 1-3 wasted tool calls per ambiguous request (estimated 200+ daily)
- Memory Scrubbing: **saves** context tokens on every future conversation (cumulative, hard to quantify)
- Net impact: **significant savings**, especially from Loop Detection and Clarification Tool
