# SeekerClaw Multilanguage Support Plan

> **Status:** Planning | **Target:** v1.8.0 | **First language:** Chinese Simplified (zh-CN)
> **Users at risk:** 4,700+ live users — zero regressions allowed

## Summary

SeekerClaw has 1,080+ hardcoded English strings but only ~150-200 are visible UI (labels, headers, status text, buttons). The rest are dialogs, help tooltips, toasts, and accessibility strings — deferred.

The agent already responds in any language — no agent-side work needed. This plan covers Android UI labels only.

---

## Scope: UI Labels Only

### In Scope (~150-200 strings)

| Category | Examples | Count |
|----------|---------|-------|
| Tab labels | Home, Console, Skills, Settings | 4 |
| Section headers | Status, Device, Connection, Preferences | ~25 |
| Field labels | Battery, Memory, Uptime, Version, Model | ~40 |
| Status indicators | Running, Offline, Error, Starting, Connected | ~20 |
| Button labels | Deploy Agent, Stop Agent, Complete setup | ~10 |
| Dashboard stats | API, LATENCY, CACHE, TODAY, TOTAL, LAST | ~10 |
| Card values | Charging, Not set, Loading... | ~15 |
| Empty states | No logs yet, No skills installed | ~10 |
| Filter labels | Debug, Info, Warn, Error | 4 |
| Settings labels | Auto-start, Analytics, Battery, Camera, GPS | ~15 |

### Out of Scope (Deferred)

| Category | Why Deferred |
|----------|-------------|
| Dialogs (edit, confirm, wipe) | Action-oriented, not navigation |
| Toasts/Snackbars | Transient, low visibility |
| Help tooltips (SettingsHelpTexts.kt) | Long-form, needs deep product knowledge to translate |
| Content descriptions (a11y) | Invisible to sighted users |
| Placeholder/hint text | Secondary UX |
| Setup screen | Complex multi-step flow, many states — separate ticket |
| Error messages from Node.js | Live in JS, need mapping layer |
| Log message prefixes | Debug-only, stay English |

---

## Architecture

### v1.8.0: System Locale (Auto)
- Android loads values-zh-rCN/strings.xml when device language is Chinese
- Zero UI needed — it just works
- Fallback: missing translations show English (safe)

### v1.8.1+: In-App Language Picker (If Requested)
- AppCompatDelegate.setApplicationLocales() (API 33+ per-app language)
- "Language" dropdown in Settings
- Only build if users request it

---

## File-by-File Extraction

### Priority 1: What Users See First

| File | Strings | Notes |
|------|---------|-------|
| NavGraph.kt | ~4 | Tab labels: Home, Console, Skills, Settings |
| DashboardScreen.kt | ~50 | Most-seen screen. Status, stats, uplinks |

### Priority 2: Settings Navigation

| File | Strings | Notes |
|------|---------|-------|
| SettingsScreen.kt | ~40 | Section headers + field labels ONLY (skip dialogs, toasts, help) |

### Priority 3: Secondary Screens

| File | Strings | Notes |
|------|---------|-------|
| SystemScreen.kt | ~40 | Field labels, section headers, status values |
| LogsScreen.kt | ~15 | Filter labels, empty states, search hint |
| SkillsScreen.kt | ~15 | Headers, empty states, filter |

### Priority 4: Config Screens (Labels Only)

| File | Strings | Notes |
|------|---------|-------|
| ProviderConfigScreen.kt | ~10 | Field labels only |
| AnthropicConfigScreen.kt | ~10 | Field labels only |
| TelegramConfigScreen.kt | ~10 | Field labels only |

---

## Implementation Pattern

### Extract
```kotlin
// BEFORE
Text("Deploy Agent")

// AFTER
Text(stringResource(R.string.button_deploy_agent))
```

### Resource Files
```xml
<!-- res/values/strings.xml (English default) -->
<string name="button_deploy_agent">Deploy Agent</string>

<!-- res/values-zh-rCN/strings.xml (Chinese Simplified) -->
<string name="button_deploy_agent">部署代理</string>
```

### Naming Convention
```
{category}_{description}

tab_home, tab_console, tab_skills, tab_settings
section_status, section_device, section_connection
label_battery, label_memory, label_uptime
status_running, status_offline, status_error
button_deploy, button_stop
stat_api, stat_latency, stat_cache
empty_no_logs, empty_no_skills
filter_debug, filter_info, filter_warn, filter_error
```

### Non-Translatable Strings
```xml
<string name="brand_seekerclaw" translatable="false">SeekerClaw</string>
<string name="brand_claw_engine" translatable="false">Claw Engine</string>
<string name="brand_agent_os" translatable="false">AgentOS</string>
<string name="tech_api" translatable="false">API</string>
<string name="tech_node_js" translatable="false">Node.js</string>
<string name="tech_openclaw" translatable="false">OpenClaw</string>
<string name="tech_telegram" translatable="false">Telegram</string>
<string name="tech_mcp" translatable="false">MCP</string>
<string name="tech_sol" translatable="false">SOL</string>
```

### Parameterized Strings
```xml
<!-- English -->
<string name="label_entries_count">%1$d/%2$d entries</string>
<string name="label_battery_value">%1$d%% %2$s</string>

<!-- Chinese -->
<string name="label_entries_count">%1$d/%2$d 条目</string>
<string name="label_battery_value">%1$d%% %2$s</string>
```

---

## Translation Approach

### Step 1: Extract All Strings (Mechanical)
- One BAT ticket per priority group
- Pure refactor — English text stays identical
- Verify: before/after screenshots must be pixel-identical

### Step 2: Translate (AI + Human Review)
- Claude translates all ~150-200 strings to zh-CN
- Native Chinese speaker reviews for natural phrasing, technical term consistency, length
- Budget: 2-3 hours of review time

### Step 3: Test
- Set device to zh-CN locale
- Walk through every screen
- Check for: overflow, truncation, awkward phrasing, missing translations

---

## Safety Rules

1. **English Must Be Identical** — Extract = pure refactor. Before/after screenshots must match.
2. **Brand Names Never Translate** — SeekerClaw, Claw Engine, AgentOS, OpenClaw. Marked translatable="false".
3. **Technical Terms Stay English** — API, SDK, Node.js, Telegram, MCP, SOL, NFT, DCA.
4. **Solana/DeFi Terms Stay English** — Swap, DCA, Holdings, Wallet, SOL. Crypto uses English globally.
5. **Log Messages Stay English** — All Log.d(), LogCollector.append(). Debugging must be readable by us.
6. **Missing Translation = English Fallback** — Android handles this automatically. Safe.

---

## Date/Time/Number Formatting

| Type | English | Chinese |
|------|---------|---------|
| Date | March 20, 2026 | 2026年3月20日 |
| Time | 7:43 PM | 19:43 (24h common) |
| Numbers | 1,234 | 1,234 (same) |

Decision: Use Android's built-in DateFormat and NumberFormat with locale. Check formatUptime() and formatTimeAgo() in SystemScreen.kt.

---

## Effort Estimate

| Task | Effort | BAT Tickets |
|------|--------|-------------|
| Extract P1 strings (Dashboard + Nav) | Half day | 1 |
| Extract P2-P4 strings (remaining screens) | 1 day | 1 |
| AI translation + human review | Half day | 1 |
| Device testing zh-CN | Half day | Part of above |
| **Total** | **2-3 days** | **3 tickets** |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Chinese text overflow in narrow cards | Medium | Test every screen, use maxLines + Ellipsis |
| English regression (string mismatch) | Low | Screenshot comparison before/after |
| Inconsistent translation quality | Medium | Native speaker review, not just AI |
| Users want in-app picker | Medium | Defer to v1.8.1, easy to add later |

---

## Future Languages

Once infrastructure is in place, adding a language = one values-{locale}/strings.xml file.

| Language | Locale | Priority |
|----------|--------|----------|
| Chinese Simplified | zh-rCN | v1.8.0 |
| Japanese | ja | v1.9.0 |
| Korean | ko | v1.9.0 |
| Spanish | es | v2.0.0 |
| Chinese Traditional | zh-rTW | On demand |

---

*Plan created 2026-03-20. Scope: UI labels only (~150-200 strings). First language: Chinese Simplified.*
