# SAB-AUDIT-v8 — SeekerClaw Agent Self-Knowledge Audit

> **Date:** 2026-03-03
> **Scope:** Re-audit after #220 (skill export/import, images, labels), #221 (back-online notification), NO_REPLY bold-markdown stripping (OpenClaw 2026.3.1 parity)
> **Method:** Full read of buildSystemBlocks() + constants verification + diagnostic coverage map
> **Baseline:** SAB-AUDIT-v7.md (111/111, 100%)

---

## Overall Scorecard

| Section | Score | Max | Percentage | Delta |
|---------|-------|-----|-----------|-------|
| A: Knowledge & Doors | 63 | 63 | 100% | — (held) |
| B: Diagnostic Coverage | 48 | 48 | 100% | — (held) |
| **Combined** | **111** | **111** | **100%** | — |

Scoring: ✅ = 3 pts, ⚠️ = 1 pt, ❌ = 0 pts.

---

## Constants Verification

| Constant | Code Value | Prompt Claim | Match |
|----------|-----------|-------------|-------|
| MAX_TOOL_USES | 25 (claude.js:1484) | "Up to 25 tool-call rounds" (line 802) | ✅ |
| MAX_HISTORY | 35 (claude.js:174) | "35 messages per chat" (line 801) | ✅ |
| max_tokens | 4096 (claude.js:1505) | "4096 tokens per response" (line 803) | ✅ |
| SHELL_ALLOWLIST | 34 commands (config.js:234-241) | 34 commands listed (line 637) | ✅ |
| SECRETS_BLOCKED | config.json, config.yaml, seekerclaw.db (config.js:225) | seekerclaw.db listed as BLOCKED (line 555) | ✅ |

No changes to constants since v7.

---

## Section A: Knowledge & Doors (21 items)

All 21 items from v7 held at ✅. No regressions.

### Changes Since v7

3 changes shipped since the v7 audit (2026-02-28). Each evaluated against the 3-part door test:

| Change | What Shipped | New Door? | Reason |
|--------|-------------|-----------|--------|
| #220 | Skill export/import, images, labels, empty dir cleanup | No | Android UI feature; JS changes are minor infrastructure (image field parsing in skills.js, empty dir cleanup in tools.js). Agent doesn't export/import skills. |
| #221 | Back-online notification on restart | **Yes (enriched existing)** | Messages sent during downtime are flushed — agent should know this when user asks "did you get my message?". Enriched line 804 with flushing + auto-notify detail. |
| eac70ab | NO_REPLY bold-markdown stripping (OpenClaw 2026.3.1 parity) | No | Transparent response processing — agent doesn't need to know about its own output cleaning regex. |

**1 existing door enriched** (line 804: conversation reset). Item count remains at 21.

### Full Item Scores

**Identity (5/5)**

| # | Item | v5 | v6 | v7 | v8 | Notes |
|---|------|----|----|-----|-----|-------|
| 1 | Own name/version | ✅ | ✅ | ✅ | ✅ | Lines 375-376 |
| 2 | Model | ✅ | ✅ | ✅ | ✅ | PLATFORM.md (auto-generated) |
| 3 | Device/hardware | ✅ | ✅ | ✅ | ✅ | PLATFORM.md |
| 4 | Who built it | ✅ | ✅ | ✅ | ✅ | Line 377 (OpenClaw) |
| 5 | Official channels | — | ✅ | ✅ | ✅ | Line 378 (seekerclaw.xyz, @SeekerClaw, t.me/seekerclaw, GitHub) |

**Architecture (4/4)**

| # | Item | v5 | v6 | v7 | v8 | Notes |
|---|------|----|----|-----|-----|-------|
| 6 | Node↔Kotlin bridge | ✅ | ✅ | ✅ | ✅ | Lines 382-387 |
| 7 | UI vs :node process | ✅ | ✅ | ✅ | ✅ | Lines 384-385 |
| 8 | Health monitoring | ✅ | ✅ | ✅ | ✅ | Lines 577-582 |
| 9 | Telegram polling | ✅ | ✅ | ✅ | ✅ | Lines 441-446 |

**Capabilities (4/4)**

| # | Item | v5 | v6 | v7 | v8 | Notes |
|---|------|----|----|-----|-----|-------|
| 10 | Full tool list | ✅ | ✅ | ✅ | ✅ | Lines 397-421 |
| 11 | Sandboxed tools | ✅ | ✅ | ✅ | ✅ | Lines 415-416 |
| 12 | What it cannot do | ✅ | ✅ | ✅ | ✅ | Lines 782-787 |
| 13 | Skills load/trigger | ✅ | ✅ | ✅ | ✅ | Lines 459-477 |

**Configuration (4/4)**

| # | Item | v5 | v6 | v7 | v8 | Notes |
|---|------|----|----|-----|-----|-------|
| 14 | Config files | ✅ | ✅ | ✅ | ✅ | Lines 544-556 |
| 15 | Settings agent can change | ✅ | ✅ | ✅ | ✅ | Lines 558-574 |
| 16 | API keys needed | ✅ | ✅ | ✅ | ✅ | Lines 560-562 |
| 17 | Model/heartbeat change | ✅ | ✅ | ✅ | ✅ | Line 547 |

**Self-Diagnosis (4/4)**

| # | Item | v5 | v6 | v7 | v8 | Notes |
|---|------|----|----|-----|-----|-------|
| 18 | Health stale | ✅ | ✅ | ✅ | ✅ | Lines 625-630 |
| 19 | Telegram disconnects | ✅ | ✅ | ✅ | ✅ | Lines 612-618 |
| 20 | Skill fails | ✅ | ✅ | ✅ | ✅ | Lines 619-624 |
| 21 | Conversation corruption | ✅ | ✅ | ✅ | ✅ | Lines 631-635 |

**Section A Total: 63/63 (100%)**

---

## Section B: Diagnostic Coverage (16 failure modes)

All 16 failure modes from v7 held at ✅. No regressions.

### Post-Fix Scores

| # | Subsystem | Failure Mode | v5 | v6 | v7 | v8 | Coverage Location |
|---|-----------|-------------|----|----|-----|-----|-------------------|
| 1 | Telegram | Bot token invalid/revoked | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Telegram |
| 2 | Telegram | Rate limited (429) | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Telegram |
| 3 | Claude API | Transport timeout | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Claude API |
| 4 | Claude API | Context overflow | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Claude API |
| 5 | Tools | Confirmation gate timeout | ✅ | ✅ | ✅ | ✅ | System prompt lines 498-503 |
| 6 | Tools | Tool result truncated | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Tools |
| 7 | Memory | memory_save fails (fs full) | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Memory |
| 8 | Memory | memory_search returns nothing | ✅ | ✅ | ✅ | ✅ | System prompt lines 506-512 |
| 9 | Cron | Job fails to send reminder | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Cron |
| 10 | Cron | Jobs lost after restart | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Cron |
| 11 | Bridge | Service down (ECONNREFUSED) | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Bridge |
| 12 | Bridge | Permission-specific errors | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Bridge |
| 13 | MCP | Server unreachable | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §MCP |
| 14 | MCP | Tool definition changed (rug-pull) | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §MCP |
| 15 | MCP | Rate limit exceeded | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §MCP |
| 16 | Skills | Requirements not met | ✅ | ✅ | ✅ | ✅ | DIAGNOSTICS.md §Skills |

**Section B Total: 48/48 (100%)**

### New Failure Modes Check

| Change | Potential Failure Mode | Assessment |
|--------|----------------------|------------|
| #220 (skill export/import) | Export/import fails | Android UI feature — agent has no tools for export/import. Not an agent failure mode. |
| #221 (back-online notify) | Notification send fails | Caught with `.catch()`, logged as WARN. Transparent infrastructure — agent doesn't know about it. Not a new diagnosable failure mode. |
| NO_REPLY stripping | Regex fails to strip token | Regex is battle-tested (SILENT_REPLY/HEARTBEAT_OK). Worst case: user sees bare token — existing "response processing" coverage applies. No new failure mode. |

No new failure modes to add.

---

## Gaps Fixed

| File | Line | Issue | Fix |
|------|------|-------|-----|
| claude.js | 804 | Conversation reset line didn't mention message flushing or auto-notification | Enriched: "...and any messages sent during downtime are flushed (the user is automatically notified to resend)" |

---

## Code Issues Found

None.

---

## Remaining Gaps

**None.** All 21 knowledge items and all 16 diagnostic failure modes score ✅.

---

## Observations

1. **#220 (skill export/import)** is the largest feature since v7 but is entirely Android UI + Kotlin side. The JS changes are minor infrastructure: `image` field parsing in `skills.js` and empty directory cleanup in `tools.js:delete`. Neither requires agent awareness.

2. **#221 (back-online notification)** adds a silent "Back online — resend anything important" Telegram message on restart. This is transparent infrastructure — the agent doesn't send it, the startup code does. The agent already knows sessions are ephemeral (line 804).

3. **NO_REPLY bold-markdown stripping** (OpenClaw 2026.3.1 parity) fixes a real bug where `**SILENT_REPLY` would leave `**` visible to users. This is response processing — the agent doesn't need to know about its own output cleaning.

4. **4 consecutive 100% audits** (v5→v8). The system prompt and DIAGNOSTICS.md are well-maintained. Next likely trigger for a new door: Claude 4.6 adaptive thinking (when ported — currently deferred).

---

## Score Progression

```
        Knowledge (Section A)               Diagnostics (Section B)
v1  ████████████████████░░░░░░░░░░  42/60  (70%)    (not audited)
v2  ████████████████████████████░░  56/60  (93%)    (not audited)
v3  ██████████████████████████████  60/60 (100%)    (not audited)
v4  ██████████████████████████████  60/60 (100%)    ██████████████████████████████  48/48 (100%)
v5  ██████████████████████████████  60/60 (100%)    ██████████████████████████████  48/48 (100%)
v6  ██████████████████████████████  63/63 (100%)    ██████████████████████████████  48/48 (100%)
v7  ██████████████████████████████  63/63 (100%)    ██████████████████████████████  48/48 (100%)
v8  ██████████████████████████████  63/63 (100%)    ██████████████████████████████  48/48 (100%)

Combined SAB Score:
v1  ██████████████████████████████░░░░░░░░░░░░░░░░░░░░  42/60   (70%)
v2  ██████████████████████████████████████████████░░░░  56/60   (93%)
v3  ██████████████████████████████████████████████████  60/60  (100%)
v4  ██████████████████████████████████████████████████ 108/108 (100%)
v5  ██████████████████████████████████████████████████ 108/108 (100%)  [SHELL_ALLOWLIST 22→34]
v6  ██████████████████████████████████████████████████ 111/111 (100%)  [+Official channels]
v7  ██████████████████████████████████████████████████ 111/111 (100%)  [DIAGNOSTICS.md MCP rate fix]
v8  ██████████████████████████████████████████████████ 111/111 (100%)  [enriched restart flushing door]
```

---

## Methodology

- **Source-only audit** — all scores derived from code reads, no runtime testing
- **Files read:** claude.js buildSystemBlocks() (lines 335-871), config.js (SHELL_ALLOWLIST line 234, SECRETS_BLOCKED line 225), DIAGNOSTICS.md (full), SAB-AUDIT-v7.md (baseline)
- **Constants verified:** MAX_TOOL_USES=25, MAX_HISTORY=35, max_tokens=4096, SHELL_ALLOWLIST=34 commands, SECRETS_BLOCKED=3 files
- **Git diff reviewed:** 3 changes (#220, #221, eac70ab) since v7 baseline
- **No fixes needed** — all items pass
