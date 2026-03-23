# Search Provider System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken DDG fallback chain with a clean single-provider search system supporting Brave, Perplexity, Exa, Tavily, and Firecrawl — configurable from a new Search Provider settings screen.

**Architecture:** First, extract HTTP transport layer from `web.js` into `http.js` (separation of concerns). Then: new `SearchProviders.kt` registry (mirrors `Providers.kt` pattern). JS `web.js` refactored to remove DDG/DDG-Lite, keep `searchBrave()` + `searchPerplexity()`, add `searchExa()`, `searchTavily()`, `searchFirecrawl()`. `tools/web.js` simplified to single-provider dispatch (no fallback chain). `ConfigManager` extended with `searchProvider` + per-provider API key fields. New `SearchProviderConfigScreen.kt` for UI. QR v1 untouched; v2 search provider support designed-for but not wired yet.

**Tech Stack:** Kotlin/Jetpack Compose (Android UI), Node.js 18 (agent), HTTPS REST APIs (Brave/Perplexity/Exa/Tavily/Firecrawl)

**Status:** COMPLETED — BAT-481, PR #294, merged 2026-03-23.

---

## File Map

### JS (Node.js Agent) — `app/src/main/assets/nodejs-project/`

| File | Action | Responsibility |
|------|--------|----------------|
| `http.js` | **Create** | Extract HTTP transport: `httpRequest`, `httpStreamingRequest`, `httpOpenAIStreamingRequest`, `httpChatCompletionsStreamingRequest`. Pure transport layer (~600 lines). |
| `web.js` | **Modify** | Remove HTTP transport functions (now in `http.js`). Remove `searchDDG()`, `searchDDGLite()`. Add `searchExa()`, `searchTavily()`, `searchFirecrawl()`. Import `httpRequest` from `http.js`. Keep `searchBrave()`, `searchPerplexity()`, caching, `webFetch()`, HTML helpers. |
| `claude.js` | **Modify** | Update `require('./web')` → `require('./http')` for streaming functions. Update system prompt — remove DDG references, document new search providers. |
| `solana.js` | **Modify** | Update `require('./web')` → `require('./http')` for `httpRequest`. |
| `telegram.js` | **Modify** | Update `require('./web')` → `require('./http')` for `httpRequest`. |
| `tools/solana.js` | **Modify** | Update `require('../web')` → `require('../http')` for `httpRequest`. |
| `tools/web.js` | **Modify** | Remove fallback chain. Replace with single-provider dispatch using `config.searchProvider`. Update imports (remove DDG, add new providers). |
| `config.js` | **Modify** | Add `searchProvider`, `exaApiKey`, `tavilyApiKey`, `firecrawlApiKey` to config loading + `_knownKeyMap`. Keep `braveApiKey`, `perplexityApiKey`. |

### Kotlin (Android) — `app/src/main/java/com/seekerclaw/app/`

| File | Action | Responsibility |
|------|--------|----------------|
| `config/SearchProviders.kt` | **Create** | `SearchProviderInfo` data class + `availableSearchProviders` registry (Brave, Exa, Tavily, Firecrawl). Helper: `searchProviderById()`. |
| `config/ConfigManager.kt` | **Modify** | Add `searchProvider`, `exaApiKey`, `tavilyApiKey`, `firecrawlApiKey` to `AppConfig`. Add storage keys, encrypt/decrypt, `writeConfigJson()` support. |
| `ui/settings/SearchProviderConfigScreen.kt` | **Create** | Dedicated screen: provider picker, API key field, test button, help text. Pattern follows `ProviderConfigScreen.kt`. |
| `ui/settings/SettingsScreen.kt` | **Modify** | Replace inline "Brave API Key" field with "Search Provider" nav entry (like "AI Configuration"). Add `onNavigateToSearchConfig` callback. |
| `ui/settings/SettingsHelpTexts.kt` | **Modify** | Add help texts for search provider, Exa, Tavily, Firecrawl. |
| `ui/navigation/NavGraph.kt` | **Modify** | Add `SearchConfigRoute`, wire navigation. |

### Not Touched (Future)

| File | Notes |
|------|-------|
| `config/ConfigClaimImporter.kt` | QR v2 search provider field — designed for but not wired in this task. Will parse `config.searchProvider` + `integrations.exaApiKey` etc. when v2 web ships. |

---

## API Reference (for JS implementations)

### Brave Search (existing)
- **Endpoint:** `GET https://api.search.brave.com/res/v1/web/search?q={query}&count={n}&freshness={f}`
- **Auth:** Header `X-Subscription-Token: {key}`
- **Response:** `{ web: { results: [{ title, url, description }] } }`
- **Key prefix:** `BSA...`

### Perplexity Search (existing)
- **Endpoint:** `POST https://api.perplexity.ai/chat/completions` (direct) or `POST https://openrouter.ai/api/v1/chat/completions` (via OpenRouter)
- **Auth:** Header `Authorization: Bearer {key}`
- **Body:** `{ model: "sonar-pro", messages: [{ role: "user", content: query }], search_recency_filter: freshness }`
- **Response:** `{ choices: [{ message: { content } }], citations: [...] }`
- **Key prefix:** `pplx-...` (direct) or `sk-or-...` (OpenRouter)
- **Note:** Auto-detects direct vs OpenRouter from key prefix

### Exa Search
- **Endpoint:** `POST https://api.exa.ai/search`
- **Auth:** Header `x-api-key: {key}`
- **Body:** `{ query, numResults, type: "auto", contents: { text: { maxCharacters: 500 } } }`
- **Response:** `{ results: [{ title, url, text, publishedDate }] }`
- **Key hint:** Exa API key from dashboard.exa.ai

### Tavily Search
- **Endpoint:** `POST https://api.tavily.com/search`
- **Auth:** In body as `api_key` field
- **Body:** `{ api_key, query, search_depth: "basic", max_results: 5, include_answer: true }`
- **Response:** `{ answer, results: [{ title, url, content }] }`
- **Key hint:** `tvly-...` from app.tavily.com

### Firecrawl Search
- **Endpoint:** `POST https://api.firecrawl.dev/v1/search`
- **Auth:** Header `Authorization: Bearer {key}`
- **Body:** `{ query, limit: 5, scrapeOptions: { formats: ["markdown"] } }`
- **Response:** `{ data: [{ url, title, markdown, description }] }`
- **Key hint:** `fc-...` from firecrawl.dev

---

## Risks & Notes

1. **HTTP extraction (Task 0)** — Pure mechanical refactor. No logic changes. `mcp-client.js` has its own `httpRequest` — do NOT touch it. Commit separately for clean git history and easy revert if needed.

2. **Brave freshness parameter** — Removed from the unified tool schema for simplicity. `searchBrave(query, count, freshness)` still accepts 3 params — the dispatch intentionally passes only 2, so `freshness` becomes `undefined` (no filter applied). `BRAVE_FRESHNESS_VALUES` and `PERPLEXITY_RECENCY_MAP` stay as private constants in `web.js` for internal use. Can re-add freshness to tool schema later as provider-specific option if needed.

3. **QR v2 future** — `ConfigClaimImporter` can later parse `config.searchProvider` + `integrations.exaApiKey/tavilyApiKey/firecrawlApiKey` when web ships v2. Schema is designed for this but not wired now.

4. **Existing users** — Users with Brave key keep working seamlessly (`searchProvider` defaults to `"brave"`). Users with no search key get a clearer error ("Check your API key in Settings > Search Provider") instead of the current DDG fallback noise.

5. **Config.json backward compat** — Old `braveApiKey` field stays in config.json. New `searchProvider` field added alongside. Node.js config.js handles missing fields gracefully (`config.searchProvider` undefined → tools/web.js fallback `|| 'brave'`). Kotlin AppConfig defaults to `"brave"` — so first-time Settings screen shows "Brave Search" even if never explicitly configured. This is intentional UX.

6. **`perplexityApiKey` in `writeConfigJson()`** — This is a NET-NEW addition. The current `writeConfigJson()` does NOT write `perplexityApiKey` — it was only stored in SharedPreferences but never sent to the Node.js config.json. Task 8 Step 7 fixes this by including it alongside the other new keys.
