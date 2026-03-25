# Multilanguage Support — Chinese Simplified Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all hardcoded UI strings into Android string resources and add Chinese Simplified (zh-rCN) translation — industry-standard i18n for an app with 5,300+ users.

**Architecture:** Android's built-in resource system (`res/values/strings.xml` + `res/values-zh-rCN/strings.xml`). Device locale auto-selects language. Missing translations fall back to English. No in-app language picker (deferred to v1.8.1+ if requested). Compose UI uses `stringResource(R.string.xxx)` for all user-facing text.

**Tech Stack:** Android string resources, Jetpack Compose `stringResource()`, `@StringRes` annotations, `<plurals>` for count-dependent strings, `translatable="false"` for brand/tech terms.

**Scope:** ~200 in-scope strings (labels, headers, buttons, status indicators, empty states). Out of scope: dialogs, toasts, help tooltips (SettingsHelpTexts.kt), accessibility descriptions, setup screen — these are separate tickets.

**Reference:** `docs/internal/MULTILANGUAGE_PLAN.md` — high-level plan with naming conventions and safety rules.

---

## File Structure

| Action | File | Purpose |
|--------|------|---------|
| Create | `app/src/main/res/values/strings.xml` | English default (expand existing 3 → ~200 strings) |
| Create | `app/src/main/res/values-zh-rCN/strings.xml` | Chinese Simplified translations |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/navigation/NavGraph.kt` | Nav labels → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/dashboard/DashboardScreen.kt` | Dashboard strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/system/SystemScreen.kt` | System strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/logs/LogsScreen.kt` | Logs strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/skills/SkillsScreen.kt` | Skills strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/skills/SkillDetailScreen.kt` | Skill detail strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/settings/SettingsScreen.kt` | Settings strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/settings/ProviderConfigScreen.kt` | Provider config strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/settings/TelegramConfigScreen.kt` | Telegram config strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/settings/SearchProviderConfigScreen.kt` | Search config strings → stringResource |
| Modify | `app/src/main/java/com/seekerclaw/app/ui/settings/RestartDialog.kt` | Restart dialog strings → stringResource |

---

## Naming Convention

```
{category}_{description}

nav_home, nav_logs, nav_skills, nav_settings
section_status, section_device, section_connection
label_battery, label_memory, label_uptime, label_version
status_running, status_offline, status_error, status_starting
button_deploy_agent, button_stop_agent, button_save, button_cancel
stat_api, stat_latency, stat_cache
empty_no_logs, empty_no_skills
filter_debug, filter_info, filter_warn, filter_error
error_auth_rejected, error_rate_limited
banner_no_internet, banner_api_restored
uplink_telegram, uplink_engine, uplink_ai_provider
```

Brand/tech terms use `translatable="false"`: SeekerClaw, AgentOS, OpenClaw, Node.js, Telegram, MCP, SOL, API, SDK.

---

## Task 1: Create English strings.xml with all in-scope strings

**Files:**
- Modify: `app/src/main/res/values/strings.xml`

This is the foundation. Add all ~200 string resources organized by screen/category. Every subsequent task references these resource names.

- [ ] **Step 1: Read the existing strings.xml**

Current content (3 strings only):
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">SeekerClaw</string>
    <string name="notification_channel_name">SeekerClaw Service</string>
    <string name="notification_content">AI agent is running</string>
</resources>
```

- [ ] **Step 2: Replace with full strings.xml**

Write the complete `app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>

    <!-- ==================== NON-TRANSLATABLE ==================== -->
    <string name="app_name" translatable="false">SeekerClaw</string>
    <string name="brand_agentos" translatable="false">AgentOS</string>
    <string name="brand_claw_engine" translatable="false">Claw Engine</string>
    <string name="brand_openclaw" translatable="false">OpenClaw</string>
    <string name="tech_api" translatable="false">API</string>
    <string name="tech_nodejs" translatable="false">Node.js</string>
    <string name="tech_telegram" translatable="false">Telegram</string>
    <string name="tech_mcp" translatable="false">MCP</string>
    <string name="tech_sol" translatable="false">SOL</string>

    <!-- ==================== NOTIFICATION ==================== -->
    <string name="notification_channel_name">SeekerClaw Service</string>
    <string name="notification_content">AI agent is running</string>

    <!-- ==================== NAVIGATION ==================== -->
    <string name="nav_home">Home</string>
    <string name="nav_logs">Logs</string>
    <string name="nav_skills">Skills</string>
    <string name="nav_settings">Settings</string>

    <!-- ==================== DASHBOARD ==================== -->
    <!-- Logo -->
    <string name="logo_seeker">Seeker</string>
    <string name="logo_claw">C/aw</string>

    <!-- Status indicators -->
    <string name="status_online">Online</string>
    <string name="status_offline">Offline</string>
    <string name="status_starting">Starting…</string>
    <string name="status_error">Error</string>
    <string name="status_config_needed">Config Needed</string>
    <string name="status_rate_limited">Rate Limited</string>
    <string name="status_api_overloaded">API Overloaded</string>
    <string name="status_api_unreachable">API Unreachable</string>
    <string name="status_api_unstable">API Unstable</string>
    <string name="status_auth_error">Auth Error</string>
    <string name="status_billing_issue">Billing Issue</string>
    <string name="status_quota_exceeded">Quota Exceeded</string>
    <string name="status_network_error">Network Error</string>
    <string name="status_api_error">API Error</string>
    <string name="status_agent_unresponsive">Agent Unresponsive</string>

    <!-- Banners -->
    <string name="banner_no_internet">No internet connection</string>
    <string name="banner_api_restored">API connection restored</string>

    <!-- Error messages -->
    <string name="error_auth_rejected">API key rejected%1$s — check Settings</string>
    <string name="error_billing_issue">API billing issue — check %1$s</string>
    <string name="error_quota_exceeded">API quota exceeded — try again later or upgrade plan</string>
    <string name="error_rate_limited">Rate limited — retrying automatically</string>
    <string name="error_api_unavailable">%1$s API temporarily unavailable — retrying</string>
    <string name="error_api_unreachable">%1$s API unreachable — retrying</string>
    <string name="error_cannot_reach_api">Cannot reach %1$s API — check internet connection</string>
    <string name="error_agent_stale">Agent may have stopped responding — try restarting</string>
    <string name="error_api_generic">API error — check Logs for details</string>
    <string name="error_missing_bot_token">Your Telegram bot token is missing</string>
    <string name="error_missing_credential">Your API credential is missing</string>
    <string name="error_config_required">Your agent needs configuration to start</string>

    <!-- Setup/Ready cards -->
    <string name="card_complete_setup">Complete Setup</string>
    <string name="card_ready">Ready to go!</string>
    <string name="card_ready_subtitle">Tap "Deploy Agent" below to start %1$s, then open Telegram to chat with your agent.</string>
    <string name="button_continue_setup">Continue Setup</string>
    <string name="hint_complete_setup">Complete setup to deploy</string>

    <!-- Dashboard labels -->
    <string name="label_uptime">Uptime</string>
    <string name="label_today">TODAY</string>
    <string name="label_total">TOTAL</string>
    <string name="label_last">LAST</string>
    <string name="section_status">Status</string>

    <!-- Stat cards -->
    <string name="stat_api">API</string>
    <string name="stat_api_unit">req</string>
    <string name="stat_latency">LATENCY</string>
    <string name="stat_latency_unit">ms</string>
    <string name="stat_cache">CACHE</string>
    <string name="stat_cache_unit">%</string>

    <!-- Uplink labels -->
    <string name="uplink_engine_retrying">Engine retrying</string>
    <string name="uplink_engine_error">Engine error</string>
    <string name="uplink_engine_unresponsive">Engine unresponsive</string>
    <string name="uplink_engine_default">Claw Engine</string>
    <string name="uplink_starting">Starting…</string>
    <string name="uplink_offline">Offline</string>
    <string name="uplink_blocked_config">Blocked: missing config</string>
    <string name="uplink_bot_missing">Bot token missing</string>
    <string name="uplink_message_relay">Message relay</string>
    <string name="uplink_connecting">Connecting…</string>
    <string name="uplink_relay_error">Relay error</string>
    <string name="uplink_credential_missing">Credential missing</string>
    <string name="uplink_model_retrying">%1$s (retrying)</string>
    <string name="uplink_auth_expired">Auth expired</string>
    <string name="uplink_billing_issue">Billing issue</string>
    <string name="uplink_quota_exceeded">Quota exceeded</string>
    <string name="uplink_api_error">API error</string>
    <string name="uplink_unresponsive">Unresponsive</string>
    <string name="uplink_loading_model">Loading model…</string>
    <string name="uplink_model_error">Model error</string>
    <string name="uplink_name_telegram">Telegram</string>
    <string name="uplink_name_engine">Engine</string>
    <string name="uplink_name_ai_provider">AI Provider</string>

    <!-- Buttons -->
    <string name="button_deploy_agent">Deploy Agent</string>
    <string name="button_stop_agent">Stop Agent</string>
    <string name="button_settings">Settings ></string>
    <string name="button_system">System ></string>
    <string name="button_save">Save</string>
    <string name="button_cancel">Cancel</string>
    <string name="button_confirm">Confirm</string>
    <string name="button_continue">Continue</string>
    <string name="button_remove">Remove</string>
    <string name="button_later">Later</string>
    <string name="button_copy">Copy</string>
    <string name="button_apply">Apply</string>

    <!-- ==================== SYSTEM SCREEN ==================== -->
    <string name="screen_system">System</string>
    <string name="system_section_status">Status</string>
    <string name="system_label_version">Version</string>
    <string name="system_label_openclaw">OpenClaw</string>
    <string name="system_label_nodejs">Node.js</string>
    <string name="system_label_agent">Agent</string>
    <string name="system_label_uptime">Uptime</string>
    <string name="system_status_running">Running</string>
    <string name="system_status_starting">Starting</string>
    <string name="system_status_stopped">Stopped</string>
    <string name="system_status_error">Error</string>

    <string name="system_section_device">Device</string>
    <string name="system_label_battery">Battery</string>
    <string name="system_charging">Charging</string>
    <string name="system_label_device_memory">Device Memory</string>
    <string name="system_label_device_storage">Device Storage</string>
    <string name="system_loading">Loading…</string>

    <string name="system_section_app_storage">APP STORAGE</string>
    <string name="system_label_workspace">Workspace</string>
    <string name="system_label_database">Database</string>
    <string name="system_label_logs">Logs</string>
    <string name="system_label_runtime">Runtime</string>
    <string name="system_label_total">Total</string>

    <string name="system_section_connection">Connection</string>
    <string name="system_label_telegram">Telegram</string>
    <string name="system_connected">Connected</string>
    <string name="system_disconnected">Disconnected</string>
    <string name="system_label_last_message">Last message</string>
    <string name="system_label_model">Model</string>

    <string name="system_section_api_limits">API Limits</string>
    <string name="system_limit_session">Session</string>
    <string name="system_limit_weekly">Weekly</string>
    <string name="system_limit_requests">Requests</string>
    <string name="system_limit_tokens">Tokens</string>

    <string name="system_section_usage">Usage</string>
    <string name="system_label_today">Today</string>
    <string name="system_label_all_time">All Time</string>
    <string name="system_unit_messages">messages</string>
    <string name="system_unit_tokens">tokens</string>

    <string name="system_section_api_analytics">API Analytics</string>
    <string name="system_label_avg_latency">Avg Latency</string>
    <string name="system_label_error_rate">Error Rate</string>
    <string name="system_label_cache_hits">Cache Hits</string>
    <string name="system_label_tokens_in_out">Tokens In/Out</string>
    <string name="system_section_memory_index">Memory Index</string>
    <string name="system_label_last_indexed">Last Indexed</string>

    <string name="system_time_just_now">just now</string>
    <string name="system_time_minutes_ago">%1$dm ago</string>
    <string name="system_time_hours_ago">%1$dh ago</string>
    <string name="system_time_days_ago">%1$dd ago</string>
    <string name="system_reset_soon">soon</string>
    <string name="system_reset_in_hours">in %1$dh %2$dm</string>
    <string name="system_reset_in_minutes">in %1$dm</string>
    <string name="system_reset_less_than_one_min">in &lt;1m</string>

    <!-- ==================== LOGS SCREEN ==================== -->
    <string name="screen_logs">Logs</string>
    <string name="logs_subtitle">System logs and diagnostics</string>
    <string name="logs_search_placeholder">Search logs…</string>
    <string name="logs_empty">No logs yet.</string>
    <string name="logs_empty_search">No logs match your search.</string>
    <string name="logs_empty_filter">No logs for selected levels.</string>
    <string name="logs_entries_hidden">%1$d entries hidden.</string>
    <string name="logs_entries_count">%1$d/%2$d entries</string>
    <string name="logs_filtered_count"> · %1$d filtered</string>
    <string name="logs_toggle_auto_scroll">Auto-scroll</string>
    <string name="logs_button_show_all">Show all</string>

    <string name="filter_debug">Debug</string>
    <string name="filter_info">Info</string>
    <string name="filter_warn">Warn</string>
    <string name="filter_error">Error</string>

    <string name="dialog_clear_logs_title">Clear Logs</string>
    <string name="dialog_clear_logs_message">This will delete all log entries. This cannot be undone.</string>
    <string name="dialog_clear_logs_button">Clear</string>

    <!-- ==================== SKILLS SCREEN ==================== -->
    <string name="screen_skills">Skills</string>
    <string name="skills_title">Skills (%1$d)</string>
    <string name="skills_title_filtered">Skills (%1$d of %2$d)</string>
    <string name="skills_search_placeholder">Search skills…</string>
    <string name="skills_section_added">Added (%1$d)</string>
    <string name="skills_section_default">Default (%1$d)</string>
    <string name="skills_empty_search">No skills match your search</string>
    <string name="skills_empty_search_hint">Try a different search term</string>
    <string name="skills_empty">No skills installed</string>
    <string name="skills_empty_hint">Send a .md skill file via Telegram to install your first skill.</string>
    <string name="skills_marketplace_title">Skill Marketplace</string>
    <string name="skills_marketplace_coming_soon">COMING SOON</string>
    <string name="skills_marketplace_description">Discover and install skills created by the community.</string>
    <string name="button_import">Import</string>
    <string name="button_export">Export</string>
    <string name="button_export_all">Export All</string>

    <plurals name="skills_trigger_count">
        <item quantity="one">%1$d trigger</item>
        <item quantity="other">%1$d triggers</item>
    </plurals>

    <!-- Skill Detail -->
    <string name="skill_back">← Skills</string>
    <string name="skill_label_type">TYPE</string>
    <string name="skill_type_default">Default (bundled)</string>
    <string name="skill_type_user">Added by user</string>
    <string name="skill_label_description">DESCRIPTION</string>
    <string name="skill_label_triggers">TRIGGERS</string>
    <string name="skill_trigger_semantic">Semantic — AI picks this skill based on description</string>
    <string name="skill_label_diagnostics">DIAGNOSTICS</string>
    <string name="skill_label_file">FILE</string>

    <!-- ==================== SETTINGS SCREEN ==================== -->
    <string name="screen_settings">Settings</string>
    <string name="settings_section_quick_setup">Quick Setup</string>
    <string name="settings_qr_description">Generate a config QR at seekerclaw.xyz and scan it to set up your agent in seconds.</string>
    <string name="button_scan_config_qr">Scan Config QR</string>
    <string name="button_importing_config">Importing Config…</string>

    <string name="settings_ai_config">AI Configuration</string>
    <string name="settings_ai_config_subtitle">Provider, Model, Keys</string>
    <string name="settings_ai_config_info">Select AI provider, configure model and API credentials.</string>
    <string name="settings_telegram">Telegram</string>
    <string name="settings_telegram_subtitle">Bot Token, Owner ID, Connection Test</string>
    <string name="settings_telegram_info">Configure your Telegram bot settings.</string>
    <string name="settings_agent_name">Agent Name</string>
    <string name="settings_heartbeat_interval">Heartbeat Interval</string>
    <string name="settings_heartbeat_value">Every %1$d minutes</string>
    <string name="settings_heartbeat_edit_label">Heartbeat Interval (minutes, 5–120)</string>
    <string name="settings_search_provider">Search Provider</string>
    <string name="settings_search_not_configured"> (not configured)</string>

    <!-- Preferences -->
    <string name="settings_auto_start">Auto-start on boot</string>
    <string name="settings_analytics">Usage analytics</string>
    <string name="settings_battery">Battery unrestricted</string>
    <string name="settings_server_mode">Server mode (keep screen awake)</string>

    <!-- Permissions -->
    <string name="settings_permissions_info">Enable permissions to unlock device features (camera, GPS, SMS, etc.)</string>
    <string name="permission_camera">Camera</string>
    <string name="permission_gps">GPS Location</string>
    <string name="permission_contacts">Contacts</string>
    <string name="permission_sms">SMS</string>
    <string name="permission_phone">Phone Calls</string>

    <!-- Wallet -->
    <string name="settings_section_wallet">Solana Wallet</string>
    <string name="wallet_label_address">Address</string>
    <string name="wallet_label_wallet">Wallet</string>
    <string name="wallet_opener_info">Opens Phantom, Solflare, or Seeker Vault</string>
    <string name="button_disconnect_wallet">Disconnect Wallet</string>
    <string name="settings_jupiter_api_key">Jupiter API Key</string>
    <string name="settings_jupiter_not_set">Not set — swaps disabled</string>
    <string name="settings_helius_api_key">Helius API Key</string>
    <string name="settings_helius_not_set">Not set — NFT holdings disabled</string>

    <!-- MCP -->
    <string name="settings_section_mcp">MCP Servers</string>
    <string name="mcp_empty">No servers configured</string>
    <string name="button_add_mcp_server">Add MCP Server</string>

    <!-- Data -->
    <string name="settings_section_data">Data</string>
    <string name="button_export_memory">Export Memory</string>
    <string name="button_import_memory">Import Memory</string>
    <string name="button_export_skills">Export Skills</string>
    <string name="button_import_skills">Import Skills</string>

    <!-- Setup / Danger -->
    <string name="settings_section_setup">Setup</string>
    <string name="button_run_setup_again">Run Setup Again</string>
    <string name="settings_section_danger">Danger Zone</string>
    <string name="button_reset_config">Reset Config</string>
    <string name="button_wipe_memory">Wipe Memory</string>

    <!-- System info -->
    <string name="settings_section_system">System</string>
    <string name="settings_change_requires_restart">Changing this requires an agent restart.</string>

    <!-- Settings dialogs -->
    <string name="dialog_reset_config_title">Reset Config</string>
    <string name="dialog_reset_config_message">This will stop the agent, clear all config, and return to setup. This cannot be undone.</string>
    <string name="dialog_wipe_memory_title">Wipe Memory</string>
    <string name="dialog_wipe_memory_message">This will delete all memory files. The agent will lose all accumulated knowledge. This cannot be undone.</string>
    <string name="dialog_wipe_confirm_label">Type WIPE to confirm</string>
    <string name="dialog_run_setup_title">Run Setup Again</string>
    <string name="dialog_run_setup_message">This will restart the setup flow. Your current config will be overwritten when you complete setup.</string>
    <string name="dialog_import_memory_title">Import Memory</string>
    <string name="dialog_import_memory_message">This will overwrite personality, memory, and skills with the backup. A safety backup is created automatically before importing.</string>
    <string name="button_select_file">Select File</string>
    <string name="dialog_apply_config_title">Apply Imported Config</string>

    <!-- MCP dialogs -->
    <string name="dialog_add_mcp_server">Add MCP Server</string>
    <string name="dialog_edit_mcp_server">Edit MCP Server</string>
    <string name="mcp_label_name">Name</string>
    <string name="mcp_label_url">Server URL</string>
    <string name="mcp_url_placeholder">https://mcp.example.com/mcp</string>
    <string name="mcp_label_auth_token">Auth Token (optional)</string>
    <string name="mcp_error_invalid_url">Invalid URL. Must start with https:// or http://</string>
    <string name="mcp_warning_auth_https">Auth token requires HTTPS (or localhost)</string>
    <string name="dialog_remove_server_title">Remove Server</string>
    <string name="dialog_remove_server_message">Remove \"%1$s\"? This server\'s tools will no longer be available.</string>

    <!-- Restart dialog -->
    <string name="dialog_config_updated">Config Updated</string>
    <string name="dialog_restart_message">Restart the agent to apply changes?</string>
    <string name="button_restart_now">Restart Now</string>

    <!-- ==================== PROVIDER CONFIG ==================== -->
    <string name="screen_provider_config">AI Provider</string>
    <string name="provider_active">Active</string>
    <string name="provider_auth_api_key">API Key</string>
    <string name="provider_auth_setup_token">Pro/Max Setup Token</string>
    <string name="provider_label_model">Model</string>
    <string name="provider_label_auth_type">Auth Type</string>
    <string name="provider_field_active">(active)</string>
    <string name="provider_label_anthropic_key">Anthropic API Key</string>
    <string name="provider_label_setup_token">Setup Token</string>
    <string name="provider_label_openai_key">OpenAI API Key</string>
    <string name="provider_label_openrouter_key">OpenRouter API Key</string>

    <string name="openrouter_model_info">Full model ID from openrouter.ai/models (e.g. anthropic/claude-sonnet-4-6)</string>
    <string name="openrouter_fallback_label">Fallback Model (optional)</string>
    <string name="openrouter_fallback_info">Auto-switches if primary model is down (e.g. google/gemini-2.5-pro)</string>
    <string name="openrouter_key_info">Get your key at openrouter.ai/keys</string>
    <string name="openrouter_model_id_required">Model ID *</string>
    <string name="openrouter_model_id_optional">Model ID (optional)</string>
    <string name="openrouter_model_placeholder">e.g. anthropic/claude-sonnet-4-6</string>
    <string name="openrouter_context_length">Context Length (optional)</string>
    <string name="openrouter_context_default">Default: 128000</string>
    <string name="openrouter_context_info">Max tokens the model supports. Check openrouter.ai/models</string>

    <string name="provider_section_connection_test">Connection Test</string>
    <string name="provider_connection_verify">Verify your credentials are valid and the API is reachable.</string>
    <string name="provider_connection_success">Connection successful!</string>
    <string name="provider_connection_failed">Connection failed</string>
    <string name="button_test_connection">Test Connection</string>
    <string name="button_testing">Testing…</string>
    <string name="dialog_select_model">Select Model</string>
    <string name="provider_auth_info">Both credentials are stored. Switching just changes which one is used.</string>

    <!-- Provider errors -->
    <string name="provider_error_credential_empty">Credential is empty</string>
    <string name="provider_error_unauthorized">Unauthorized / Invalid credential</string>
    <string name="provider_error_anthropic_unavailable">Anthropic API unavailable</string>
    <string name="provider_error_timeout">Connection timed out</string>
    <string name="provider_error_network">Network unreachable or timeout</string>
    <string name="provider_error_api_key_empty">API key is empty</string>
    <string name="provider_error_openrouter_credits">Insufficient credits — add funds at openrouter.ai/credits</string>
    <string name="provider_error_rate_limited">Rate limited — try again in a moment</string>
    <string name="provider_error_openrouter_unavailable">OpenRouter API unavailable</string>
    <string name="provider_error_openai_unauthorized">Unauthorized / Invalid API key</string>
    <string name="provider_error_openai_unavailable">OpenAI API unavailable</string>

    <!-- ==================== TELEGRAM CONFIG ==================== -->
    <string name="screen_telegram_config">Telegram Configuration</string>
    <string name="telegram_label_bot_token">Bot Token</string>
    <string name="telegram_label_owner_id">Owner ID</string>
    <string name="telegram_owner_auto_detect">Auto-detect</string>
    <string name="telegram_section_connection_test">Connection Test</string>
    <string name="telegram_connection_verify">Verify your bot token is valid and Telegram is reachable.</string>
    <string name="telegram_error_token_empty">Bot token is empty.</string>
    <string name="telegram_connection_success">Bot connected as @%1$s</string>
    <string name="button_test_bot">Test Bot</string>
    <string name="telegram_not_set">Not set</string>

    <!-- ==================== SEARCH PROVIDER ==================== -->
    <string name="screen_search_provider">Search Provider</string>
    <string name="search_section_provider">Provider</string>
    <string name="search_label_api_key">API Key</string>
    <string name="search_not_configured">Not configured — web search will not work until an API key is set.</string>
    <string name="search_section_resources">Resources</string>
    <string name="search_get_api_key">Get API Key →</string>
    <string name="search_key_not_set">Not set</string>
    <string name="search_settings_title">%1$s Settings</string>

    <!-- ==================== COMMON ==================== -->
    <string name="content_desc_back">Back</string>
    <string name="content_desc_dismiss">Dismiss</string>
    <string name="not_set">Not set</string>

    <!-- Toasts -->
    <string name="toast_agent_restarting">Agent restarting…</string>
    <string name="toast_address_copied">Address copied</string>
    <string name="toast_memory_exported">Memory exported successfully</string>
    <string name="toast_memory_imported">Memory imported. Restart agent to apply.</string>
    <string name="toast_import_failed">Import failed</string>
    <string name="toast_export_failed">Export failed</string>
    <string name="toast_config_imported">Config imported</string>
    <string name="toast_no_qr_data">No QR data received</string>
    <string name="toast_skill_exported">Skill exported</string>
    <string name="toast_skills_exported">Skills exported</string>
    <string name="toast_no_skills_found">No skills found in file</string>

    <plurals name="toast_skills_imported">
        <item quantity="one">Imported %1$d skill</item>
        <item quantity="other">Imported %1$d skills</item>
    </plurals>

</resources>
```

- [ ] **Step 3: Compile to verify XML is valid**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL (strings.xml is additive — no code references yet, won't break anything)

- [ ] **Step 4: Commit**

```bash
git add app/src/main/res/values/strings.xml
git commit -m "$(cat <<'EOF'
i18n: add complete English strings.xml (~200 resources)

Foundation for multilanguage support. All in-scope UI strings
extracted as Android string resources. No code changes yet —
existing hardcoded strings still work.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Refactor BottomNavItem to use @StringRes

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/navigation/NavGraph.kt`

The `BottomNavItem` data class uses `val label: String` — change it to `@StringRes val labelRes: Int` so nav labels come from string resources.

- [ ] **Step 1: Read NavGraph.kt and understand current BottomNavItem usage**

Current code:
```kotlin
data class BottomNavItem(
    val label: String,
    val iconRes: Int,
    val route: Any,
)

val bottomNavItems = listOf(
    BottomNavItem("Home", R.drawable.ic_lucide_layout_grid, DashboardRoute),
    BottomNavItem("Logs", R.drawable.ic_lucide_terminal, LogsRoute),
    BottomNavItem("Skills", R.drawable.ic_lucide_layers, SkillsRoute),
    BottomNavItem("Settings", R.drawable.ic_lucide_settings, SettingsRoute),
)
```

- [ ] **Step 2: Update BottomNavItem to use @StringRes**

```kotlin
import androidx.annotation.StringRes
import androidx.compose.ui.res.stringResource

data class BottomNavItem(
    @StringRes val labelRes: Int,
    val iconRes: Int,
    val route: Any,
)

val bottomNavItems = listOf(
    BottomNavItem(R.string.nav_home, R.drawable.ic_lucide_layout_grid, DashboardRoute),
    BottomNavItem(R.string.nav_logs, R.drawable.ic_lucide_terminal, LogsRoute),
    BottomNavItem(R.string.nav_skills, R.drawable.ic_lucide_layers, SkillsRoute),
    BottomNavItem(R.string.nav_settings, R.drawable.ic_lucide_settings, SettingsRoute),
)
```

- [ ] **Step 3: Update all usages of `item.label` to `stringResource(item.labelRes)`**

Search NavGraph.kt for `item.label` and replace with `stringResource(item.labelRes)`. Typically used in:
```kotlin
// NavigationBarItem label
Text(stringResource(item.labelRes))
```

Also update the analytics screen tracking if it uses label:
```kotlin
// If tracking uses item.label, keep English for analytics:
val screenName = when (dest?.route) { ... }
```

- [ ] **Step 4: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/navigation/NavGraph.kt
git commit -m "$(cat <<'EOF'
i18n: refactor BottomNavItem to use @StringRes

Nav labels now come from string resources instead of hardcoded
strings. Foundation for localized navigation.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extract DashboardScreen strings

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/dashboard/DashboardScreen.kt`

This is the most-seen screen with ~80 strings. Replace all hardcoded strings with `stringResource()`.

- [ ] **Step 1: Add import for stringResource**

At the top of DashboardScreen.kt, add:
```kotlin
import androidx.compose.ui.res.stringResource
```

- [ ] **Step 2: Replace all hardcoded strings systematically**

Work through the file top-to-bottom. The pattern for each replacement:

**Simple strings:**
```kotlin
// BEFORE
Text("AgentOS")
// AFTER
Text(stringResource(R.string.brand_agentos))
```

**Parameterized strings:**
```kotlin
// BEFORE
text = "Cannot reach $providerName API — check internet connection"
// AFTER
text = stringResource(R.string.error_cannot_reach_api, providerName)
```

**Status indicator (when/switch blocks):**
```kotlin
// BEFORE
AgentHealth.RateLimited -> "Rate Limited"
// AFTER
AgentHealth.RateLimited -> stringResource(R.string.status_rate_limited)
```

Key replacements in DashboardScreen.kt (all ~80 strings):
- Logo text: `"Seeker"` → `R.string.logo_seeker`, `"C/aw"` → `R.string.logo_claw`
- `"AgentOS"` → `R.string.brand_agentos`
- `"No internet connection"` → `R.string.banner_no_internet`
- All AgentHealth status strings → corresponding `R.string.status_*`
- All error message strings → corresponding `R.string.error_*`
- `"API connection restored"` → `R.string.banner_api_restored`
- `"Complete Setup"` → `R.string.card_complete_setup`
- `"Ready to go!"` → `R.string.card_ready`
- `"Continue Setup"` → `R.string.button_continue_setup`
- `"Deploy Agent"` / `"Stop Agent"` → `R.string.button_deploy_agent` / `R.string.button_stop_agent`
- `"Uptime"` → `R.string.label_uptime`
- `"TODAY"`, `"TOTAL"`, `"LAST"` → `R.string.label_today`, etc.
- `"Status"` → `R.string.section_status`
- `"API"`, `"LATENCY"`, `"CACHE"` → `R.string.stat_api`, etc.
- `"req"`, `"ms"`, `"%"` → `R.string.stat_api_unit`, etc.
- All uplink strings → corresponding `R.string.uplink_*`
- `"Settings >"`, `"System >"` → `R.string.button_settings`, `R.string.button_system`
- `"Complete setup to deploy"` → `R.string.hint_complete_setup`

**Important:** `stringResource()` can only be called from `@Composable` functions. For strings in `when` blocks inside composables, this is fine. For strings in non-composable helpers, pass Context and use `context.getString(R.string.xxx)`.

- [ ] **Step 3: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/dashboard/DashboardScreen.kt
git commit -m "$(cat <<'EOF'
i18n: extract DashboardScreen strings to resources

Replace ~80 hardcoded strings with stringResource() calls.
Covers status indicators, error messages, uplink labels,
buttons, and stat cards.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extract SystemScreen strings

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/system/SystemScreen.kt`

~50 strings covering device stats, connection info, API analytics.

- [ ] **Step 1: Add stringResource import and replace all hardcoded strings**

Same pattern as Task 3. Key replacements:
- `"System"` → `R.string.screen_system`
- `"Status"`, `"Device"`, `"Connection"`, etc. → `R.string.system_section_*`
- `"Version"`, `"Battery"`, `"Uptime"`, etc. → `R.string.system_label_*`
- `"Running"`, `"Starting"`, `"Stopped"`, `"Error"` → `R.string.system_status_*`
- `"Connected"` / `"Disconnected"` → `R.string.system_connected` / `R.string.system_disconnected`
- `"Charging"` → `R.string.system_charging`
- `"Loading…"` → `R.string.system_loading`
- Time formatting functions (`formatTimeAgo`, `formatResetTime`): use `context.getString()` since these are non-composable helper functions at the bottom of the file

**For formatTimeAgo/formatResetTime:** These are utility functions that return Strings. They need a `Context` parameter (or `Resources`):
```kotlin
// BEFORE
private fun formatTimeAgo(ms: Long): String {
    // ...
    return "just now"
    return "${mins}m ago"
}

// AFTER
private fun formatTimeAgo(ms: Long, resources: android.content.res.Resources): String {
    // ...
    return resources.getString(R.string.system_time_just_now)
    return resources.getString(R.string.system_time_minutes_ago, mins)
}
```

Call sites update: `formatTimeAgo(ms, LocalContext.current.resources)` or pass resources from composable scope.

- [ ] **Step 2: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/system/SystemScreen.kt
git commit -m "$(cat <<'EOF'
i18n: extract SystemScreen strings to resources

Replace ~50 hardcoded strings with stringResource() calls.
Covers device stats, connection, API analytics, time formatting.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Extract LogsScreen + SkillsScreen + SkillDetailScreen strings

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/logs/LogsScreen.kt`
- Modify: `app/src/main/java/com/seekerclaw/app/ui/skills/SkillsScreen.kt`
- Modify: `app/src/main/java/com/seekerclaw/app/ui/skills/SkillDetailScreen.kt`

~80 strings total across 3 smaller screens.

- [ ] **Step 1: Extract LogsScreen strings (~30)**

Key replacements:
- `"Logs"` → `R.string.screen_logs`
- `"System logs and diagnostics"` → `R.string.logs_subtitle`
- `"Search logs…"` → `R.string.logs_search_placeholder`
- `"No logs yet."` → `R.string.logs_empty`
- `"No logs match your search."` → `R.string.logs_empty_search`
- `"No logs for selected levels."` → `R.string.logs_empty_filter`
- `"Auto-scroll"` → `R.string.logs_toggle_auto_scroll`
- `"Show all"` → `R.string.logs_button_show_all`
- `"Debug"`, `"Info"`, `"Warn"`, `"Error"` → `R.string.filter_*`
- `"Clear Logs"` dialog → `R.string.dialog_clear_logs_*`
- Entries count: `"${filteredLogs.size}/${logs.size} entries"` → `stringResource(R.string.logs_entries_count, filteredLogs.size, logs.size)`

- [ ] **Step 2: Extract SkillsScreen strings (~35)**

Key replacements:
- Skills title with count → `stringResource(R.string.skills_title, skills.size)` or `stringResource(R.string.skills_title_filtered, filtered.size, skills.size)`
- `"Search skills…"` → `R.string.skills_search_placeholder`
- `"Added (${addedSkills.size})"` → `stringResource(R.string.skills_section_added, addedSkills.size)`
- `"Default (${defaultSkills.size})"` → `stringResource(R.string.skills_section_default, defaultSkills.size)`
- Empty state messages → `R.string.skills_empty*`
- Marketplace card → `R.string.skills_marketplace_*`
- `"Import"`, `"Export"`, `"Export All"` → `R.string.button_import`, etc.
- Trigger count plurals → `resources.getQuantityString(R.plurals.skills_trigger_count, count, count)`

- [ ] **Step 3: Extract SkillDetailScreen strings (~15)**

Key replacements:
- `"← Skills"` → `R.string.skill_back`
- `"TYPE"`, `"DESCRIPTION"`, `"TRIGGERS"`, `"DIAGNOSTICS"`, `"FILE"` → `R.string.skill_label_*`
- `"Default (bundled)"` / `"Added by user"` → `R.string.skill_type_*`
- `"Semantic — AI picks this skill based on description"` → `R.string.skill_trigger_semantic`
- `"Export"` → `R.string.button_export`

- [ ] **Step 4: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 5: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/logs/LogsScreen.kt \
      app/src/main/java/com/seekerclaw/app/ui/skills/SkillsScreen.kt \
      app/src/main/java/com/seekerclaw/app/ui/skills/SkillDetailScreen.kt
git commit -m "$(cat <<'EOF'
i18n: extract Logs + Skills screen strings to resources

Replace ~80 hardcoded strings across LogsScreen, SkillsScreen,
and SkillDetailScreen with stringResource() calls.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Extract SettingsScreen strings

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/settings/SettingsScreen.kt`

The biggest file (~130 strings). Extract section headers, field labels, buttons, and dialog text. **Skip SettingsHelpTexts.kt** (deferred — long-form text).

- [ ] **Step 1: Add stringResource import and work through systematically**

Key replacements by section:

**Quick Setup section:**
- `"Quick Setup"` → `R.string.settings_section_quick_setup`
- QR description → `R.string.settings_qr_description`
- `"Scan Config QR"` / `"Importing Config…"` → `R.string.button_*`

**AI Configuration row:**
- `"AI Configuration"` → `R.string.settings_ai_config`
- `"Provider, Model, Keys"` → `R.string.settings_ai_config_subtitle`

**Telegram row:**
- `"Telegram"` → `R.string.settings_telegram`
- `"Bot Token, Owner ID, Connection Test"` → `R.string.settings_telegram_subtitle`

**Settings fields:**
- `"Agent Name"`, `"Heartbeat Interval"`, `"Search Provider"` → `R.string.settings_*`

**Preferences toggles:**
- `"Auto-start on boot"`, `"Usage analytics"`, `"Battery unrestricted"`, `"Server mode..."` → `R.string.settings_*`

**Permissions:**
- `"Camera"`, `"GPS Location"`, `"Contacts"`, `"SMS"`, `"Phone Calls"` → `R.string.permission_*`

**Wallet section:**
- `"Solana Wallet"`, `"Address"`, `"Copy"`, etc. → `R.string.settings_section_wallet`, `R.string.wallet_*`

**MCP section:**
- `"MCP Servers"`, `"No servers configured"`, `"Add MCP Server"` → `R.string.settings_section_mcp`, etc.
- MCP dialog fields → `R.string.mcp_*`, `R.string.dialog_*`

**Data section:**
- `"Export Memory"`, `"Import Memory"`, etc. → `R.string.button_*`

**Danger zone:**
- `"Reset Config"`, `"Wipe Memory"` → `R.string.button_*`
- All dialog text → `R.string.dialog_*`

**System info:**
- `"Version"`, `"OpenClaw"`, `"Node.js"` → `R.string.settings_section_system`, reuse `R.string.system_label_*`

**Common buttons (reuse):**
- `"Save"`, `"Cancel"`, `"Confirm"`, `"Continue"`, `"Remove"` → `R.string.button_*`

**Toasts:**
- `"Memory exported successfully"`, `"Import failed"`, etc. → `R.string.toast_*`
- Note: Toast strings use `context.getString()` not `stringResource()`

- [ ] **Step 2: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/settings/SettingsScreen.kt
git commit -m "$(cat <<'EOF'
i18n: extract SettingsScreen strings to resources

Replace ~130 hardcoded strings with stringResource() calls.
Covers all sections, toggles, permissions, wallet, MCP,
data, danger zone, and dialogs.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Extract config screen strings (Provider, Telegram, Search, RestartDialog)

**Files:**
- Modify: `app/src/main/java/com/seekerclaw/app/ui/settings/ProviderConfigScreen.kt`
- Modify: `app/src/main/java/com/seekerclaw/app/ui/settings/TelegramConfigScreen.kt`
- Modify: `app/src/main/java/com/seekerclaw/app/ui/settings/SearchProviderConfigScreen.kt`
- Modify: `app/src/main/java/com/seekerclaw/app/ui/settings/RestartDialog.kt`

~80 strings across 4 files.

- [ ] **Step 1: Extract ProviderConfigScreen strings (~50)**

Key replacements:
- `"AI Provider"` → `R.string.screen_provider_config`
- `"Active"` → `R.string.provider_active`
- `"API Key"` / `"Pro/Max Setup Token"` → `R.string.provider_auth_*`
- `"Model"` → `R.string.provider_label_model`
- `"Connection Test"` → `R.string.provider_section_connection_test`
- `"Test Connection"` / `"Testing…"` → `R.string.button_test_connection`, `R.string.button_testing`
- `"Connection successful!"` / `"Connection failed"` → `R.string.provider_connection_*`
- `"Select Model"` → `R.string.dialog_select_model`
- All provider error messages → `R.string.provider_error_*`
- OpenRouter-specific fields → `R.string.openrouter_*`

- [ ] **Step 2: Extract TelegramConfigScreen strings (~15)**

Key replacements:
- `"Telegram Configuration"` → `R.string.screen_telegram_config`
- `"Bot Token"`, `"Owner ID"` → `R.string.telegram_label_*`
- `"Auto-detect"` → `R.string.telegram_owner_auto_detect`
- `"Connection Test"` → `R.string.telegram_section_connection_test`
- `"Test Bot"` / `"Testing…"` → `R.string.button_test_bot`, `R.string.button_testing`
- `"Not set"` → `R.string.telegram_not_set`

- [ ] **Step 3: Extract SearchProviderConfigScreen strings (~12)**

Key replacements:
- `"Search Provider"` → `R.string.screen_search_provider`
- `"Provider"` → `R.string.search_section_provider`
- `"Active"` → `R.string.provider_active` (reuse)
- `"API Key"` → `R.string.search_label_api_key`
- `"Not configured..."` → `R.string.search_not_configured`
- `"Resources"` → `R.string.search_section_resources`
- `"Get API Key →"` → `R.string.search_get_api_key`
- `"${activeProvider.displayName} Settings"` → `stringResource(R.string.search_settings_title, activeProvider.displayName)`

- [ ] **Step 4: Extract RestartDialog strings (~5)**

Key replacements:
- `"Config Updated"` → `R.string.dialog_config_updated`
- `"Restart the agent to apply changes?"` → `R.string.dialog_restart_message`
- `"Restart Now"` → `R.string.button_restart_now`
- `"Later"` → `R.string.button_later`
- Toast `"Agent restarting…"` → `context.getString(R.string.toast_agent_restarting)`

- [ ] **Step 5: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add app/src/main/java/com/seekerclaw/app/ui/settings/ProviderConfigScreen.kt \
      app/src/main/java/com/seekerclaw/app/ui/settings/TelegramConfigScreen.kt \
      app/src/main/java/com/seekerclaw/app/ui/settings/SearchProviderConfigScreen.kt \
      app/src/main/java/com/seekerclaw/app/ui/settings/RestartDialog.kt
git commit -m "$(cat <<'EOF'
i18n: extract config screen strings to resources

Replace ~80 hardcoded strings across ProviderConfig, TelegramConfig,
SearchProviderConfig, and RestartDialog with stringResource() calls.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Create Chinese Simplified translation

**Files:**
- Create: `app/src/main/res/values-zh-rCN/strings.xml`

Translate all translatable strings to Chinese Simplified. Brand names and tech terms stay English (they're marked `translatable="false"` and won't appear in this file).

- [ ] **Step 1: Create the locale directory**

```bash
mkdir -p app/src/main/res/values-zh-rCN
```

- [ ] **Step 2: Write Chinese translation file**

Create `app/src/main/res/values-zh-rCN/strings.xml` with all translatable strings. Key translation decisions:

| English | Chinese | Notes |
|---------|---------|-------|
| Deploy Agent | 部署代理 | Standard AI term |
| Stop Agent | 停止代理 | |
| Online | 在线 | |
| Offline | 离线 | |
| Starting… | 启动中… | |
| Settings | 设置 | |
| Battery | 电池 | |
| Device Memory | 设备内存 | |
| Device Storage | 设备存储 | |
| Uptime | 运行时间 | |
| Skills | 技能 | |
| Connection Test | 连接测试 | |
| Danger Zone | 危险区域 | |
| Wipe Memory | 清除记忆 | |
| Reset Config | 重置配置 | |

**Translation rules:**
- Keep crypto/DeFi terms in English: Wallet, SOL, Swap, NFT
- Keep brand names: SeekerClaw, Telegram, Claude, OpenAI, OpenRouter
- Keep technical terms: API, SDK, MCP, Node.js, HTTPS, URL
- Use standard Chinese software localization (not machine translation)
- Match Android platform terminology (设置, 权限, 通知, etc.)

Write the complete `values-zh-rCN/strings.xml` with all non-`translatable="false"` strings translated.

- [ ] **Step 3: Compile and verify**

Run: `./gradlew compileDappStoreDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add app/src/main/res/values-zh-rCN/strings.xml
git commit -m "$(cat <<'EOF'
i18n: add Chinese Simplified (zh-rCN) translations

Complete translation of ~200 UI strings. Brand/tech terms stay
English. Follows Android platform terminology conventions.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Final compile + visual verification

**Files:** None (verification only)

- [ ] **Step 1: Full clean build**

```bash
./gradlew clean assembleDappStoreDebug 2>&1 | tail -20
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 2: Run /smoke-test skill**

Execute the smoke-test skill to verify:
- Phase 1: Compile check passes
- Phase 2: No deleted files
- Phase 4: All string resources resolve
- Phase 6: No raw hex colors, no hardcoded strings remaining in modified files

- [ ] **Step 3: Verify no remaining hardcoded strings in modified files**

Search for obvious remaining hardcoded strings:
```bash
grep -rn 'Text("' app/src/main/java/com/seekerclaw/app/ui/dashboard/DashboardScreen.kt | grep -v 'stringResource\|//' | head -20
grep -rn 'text = "' app/src/main/java/com/seekerclaw/app/ui/settings/SettingsScreen.kt | grep -v 'stringResource\|//' | head -20
```

Some hardcoded strings are intentional (emoji symbols like `"⚡"`, `"⚠"`, format templates). The check is for missed user-facing text.

- [ ] **Step 4: Document what's left**

Update `docs/internal/MULTILANGUAGE_PLAN.md` with:
- Strings extracted: ~200
- Screens covered: all 11
- What's deferred: SettingsHelpTexts.kt, SetupScreen.kt, toasts (some done), accessibility descriptions
- Next steps: in-app language picker (v1.8.1), Japanese/Korean (v1.9.0)

- [ ] **Step 5: Final commit**

```bash
git add docs/internal/MULTILANGUAGE_PLAN.md
git commit -m "$(cat <<'EOF'
docs: update multilanguage plan with implementation status

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Safety Checklist

Before creating PR, verify:

- [ ] English UI is pixel-identical (no visual regressions)
- [ ] All `translatable="false"` strings are NOT in zh-rCN file
- [ ] Parameterized strings use `%1$s`, `%2$d` format (not string interpolation)
- [ ] Plurals use `<plurals>` resource (not manual if/else)
- [ ] Toast strings use `context.getString()` (not `stringResource()` — toasts aren't composable)
- [ ] Log messages stay hardcoded English (debug output, not user-facing)
- [ ] Analytics event names stay English
- [ ] No `R.string` references in non-UI code (services, receivers)

---

## Build Guidance

**Gradle sync required?** No — no build.gradle.kts changes.
**Just build & run:** Yes — Kotlin source + XML resources only.
