# Open Wallet Standard (OWS) Integration Audit

> **Date:** 2026-03-26
> **Status:** Research / Planning
> **Reference:** https://github.com/wallet-standard/wallet-standard (core), https://github.com/anza-xyz/wallet-standard (Solana extension)

---

## Executive Summary

The **Wallet Standard** is a chain-agnostic TypeScript interface spec for wallet discovery and interaction. It replaces fragmented `window.solana` / `window.ethereum` patterns with a unified event-based registration system. Originally built for Solana, it now supports any blockchain via namespaced features.

**Key finding:** OWS is a **web/browser standard** — it relies on `window` events and DOM APIs. SeekerClaw is a **native Android app** using MWA (Mobile Wallet Adapter) for wallet operations. **Direct integration is not possible.** However, there are three concrete integration paths worth pursuing, detailed below.

---

## 1. What Is the Open Wallet Standard

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Browser Window                     │
│                                                       │
│  ┌──────────────┐    window events     ┌───────────┐ │
│  │ Wallet        │◄──────────────────►│ App        │ │
│  │ (Extension)   │  register-wallet    │ (dApp)     │ │
│  │               │  app-ready          │            │ │
│  │ registerWallet│                     │ getWallets │ │
│  └──────────────┘                     └───────────┘ │
│                                                       │
│  Features: standard:connect, standard:disconnect,     │
│            standard:events, solana:signTransaction,   │
│            solana:signAndSendTransaction,              │
│            solana:signMessage, solana:signIn           │
└─────────────────────────────────────────────────────┘
```

### Core Concepts

| Concept | Description |
|---------|-------------|
| **Wallet** | Object implementing `{ version, name, icon, chains, features, accounts }` |
| **WalletAccount** | Read-only data: `{ address, publicKey, chains, features, label, icon }` |
| **Feature** | Namespaced capability: `standard:connect`, `solana:signTransaction` |
| **IdentifierString** | Namespace format: `namespace:name` (e.g., `solana:mainnet`) |
| **Registration** | Wallets dispatch `wallet-standard:register-wallet` window event |
| **Discovery** | Apps call `getWallets()` which listens for registrations |

### Packages

| Package | Purpose |
|---------|---------|
| `@wallet-standard/base` | Core types: Wallet, WalletAccount, WalletIcon |
| `@wallet-standard/features` | Standard features: connect, disconnect, events |
| `@wallet-standard/app` | App-side: `getWallets()` |
| `@wallet-standard/wallet` | Wallet-side: `registerWallet()` |
| `@solana/wallet-standard-features` | Solana features: signTransaction, signMessage, signIn |
| `@solana/wallet-standard-chains` | Chain IDs: `solana:mainnet`, `solana:devnet` |

### Solana Features

| Feature | Purpose | Input | Output |
|---------|---------|-------|--------|
| `solana:signTransaction` | Sign without broadcast | `{ account, transaction: Uint8Array, chain }` | `{ signedTransaction: Uint8Array }` |
| `solana:signAndSendTransaction` | Sign + broadcast | Same + send options | `{ signature: Uint8Array }` |
| `solana:signMessage` | Sign arbitrary bytes (Ed25519) | `{ account, message: Uint8Array }` | `{ signedMessage, signature }` |
| `solana:signIn` | Sign In With Solana (SIWS) | Domain, statement, nonce, etc. | `{ account, signedMessage, signature }` |
| `solana:signAndSendAllTransactions` | Batch sign+send | Array of inputs | `PromiseSettledResult[]` |

---

## 2. SeekerClaw's Current Wallet Architecture

### How It Works Today

```
User (Telegram) → Agent → solana_swap tool → solana.js
    → androidBridgeCall('/solana/sign-only')
        → AndroidBridge.kt → SolanaAuthActivity.kt
            → MWA Intent → Phantom/Solflare
                → User approves → Signed TX returned
                    → Jupiter Ultra executes
```

### Current Stack

| Layer | Technology | File |
|-------|-----------|------|
| **Protocol** | MWA (Mobile Wallet Adapter) | `SolanaWalletManager.kt` |
| **Bridge** | NanoHTTPD localhost:8765 | `AndroidBridge.kt` |
| **Node.js client** | HTTP POST to bridge | `solana.js`, `bridge.js` |
| **Tools** | 16 Solana/Jupiter tools | `tools/solana.js` |
| **Signing** | MWA sign-only (Jupiter Ultra) or sign+send | `SolanaAuthActivity.kt` |
| **Storage** | Encrypted SharedPrefs + `solana_wallet.json` | `ConfigManager.kt` |

### Current Limitations

1. **Solana-only** — MWA is a Solana-specific protocol
2. **Single wallet** — Only one wallet connected at a time
3. **No wallet selection** — First MWA-compatible wallet found is used
4. **No feature detection** — Assumes all wallets support sign, signAndSend
5. **No multi-chain** — Hardcoded to `Solana.Mainnet`

---

## 3. Why OWS Cannot Be Integrated Directly

| OWS Requirement | SeekerClaw Reality |
|-----------------|--------------------|
| `window` object for events | No browser — native Android + Node.js |
| Browser extension wallets | Wallets are Android apps (Phantom, Solflare) |
| DOM CustomEvent dispatching | No DOM — IPC via HTTP bridge + JNI |
| TypeScript interfaces | Node.js 18 (JavaScript) + Kotlin |
| Synchronous wallet registration | Wallet connection requires user intent + MWA handshake |

**The Wallet Standard is a browser-tier specification.** SeekerClaw operates at the OS tier (Android intents, foreground services, JNI bridge). MWA is the mobile equivalent of what OWS does for browsers.

---

## 4. Three Integration Paths

### Path A: Wallet Standard Abstraction Layer (Recommended)

**What:** Adopt OWS's *interface design* (not its registration mechanism) as an internal abstraction in SeekerClaw's Node.js layer. This enables multi-chain wallet support with a clean, feature-based architecture.

**Why:** SeekerClaw already has Jupiter/Solana tools, and users are requesting TON and Ethereum support. Rather than building ad-hoc integrations for each chain, adopt the Wallet Standard's interface pattern as the internal API contract.

**Architecture:**

```
┌─────────────────────────────────────────────────────┐
│                  Node.js (main.js)                    │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │           Wallet Standard Adapter Layer          │ │
│  │                                                   │ │
│  │  interface WalletAdapter {                        │ │
│  │    name, icon, chains, features, accounts         │ │
│  │    connect(), disconnect()                        │ │
│  │    signTransaction(), signAndSendTransaction()    │ │
│  │    signMessage()                                  │ │
│  │  }                                                │ │
│  │                                                   │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │ │
│  │  │ Solana   │ │ TON      │ │ EVM (future)     │ │ │
│  │  │ MWA      │ │ TonKeeper│ │ WalletConnect    │ │ │
│  │  │ Adapter  │ │ Adapter  │ │ Adapter          │ │ │
│  │  └────┬─────┘ └────┬─────┘ └────────┬─────────┘ │ │
│  └───────┼─────────────┼────────────────┼───────────┘ │
│          │             │                │              │
│          ▼             ▼                ▼              │
│    Bridge:8765    Bridge:8766     Bridge:8767          │
│    (MWA)          (TON Connect)   (WalletConnect)     │
└─────────────────────────────────────────────────────┘
```

**Implementation Steps:**

1. **Define `WalletAdapter` interface** in Node.js (mirrors OWS `Wallet` type):
   ```javascript
   // wallet-standard/adapter.js
   class WalletAdapter {
     get name() {}           // "Phantom", "TonKeeper"
     get icon() {}           // data URI
     get chains() {}         // ["solana:mainnet", "ton:mainnet"]
     get features() {}       // { "solana:signTransaction": ..., "standard:connect": ... }
     get accounts() {}       // [{ address, publicKey, chains }]

     async connect(opts) {}
     async disconnect() {}
   }
   ```

2. **Wrap existing MWA integration** as `SolanaMwaAdapter extends WalletAdapter`:
   ```javascript
   // wallet-standard/solana-mwa.js
   class SolanaMwaAdapter extends WalletAdapter {
     get chains() { return ['solana:mainnet']; }
     get features() {
       return {
         'standard:connect': { connect: () => this._mwaAuthorize() },
         'solana:signTransaction': { signTransaction: (input) => this._mwaSign(input) },
         'solana:signAndSendTransaction': { signAndSendTransaction: (input) => this._mwaSignAndSend(input) },
       };
     }
     async _mwaAuthorize() { return androidBridgeCall('/solana/authorize'); }
     async _mwaSign(input) { return androidBridgeCall('/solana/sign-only', input); }
   }
   ```

3. **Create `WalletRegistry`** (replaces OWS's `getWallets()`):
   ```javascript
   // wallet-standard/registry.js
   class WalletRegistry {
     #adapters = new Map();

     register(adapter) { this.#adapters.set(adapter.name, adapter); }
     get(name) { return this.#adapters.get(name); }
     getAll() { return [...this.#adapters.values()]; }

     // Find wallets that support a specific feature
     getByFeature(feature) {
       return this.getAll().filter(w => feature in w.features);
     }

     // Find wallets that support a specific chain
     getByChain(chain) {
       return this.getAll().filter(w => w.chains.includes(chain));
     }
   }
   ```

4. **Refactor tools** to use adapter interface instead of direct bridge calls:
   ```javascript
   // Before (current):
   const result = await androidBridgeCall('/solana/sign-only', { transaction });

   // After (with adapter):
   const wallet = walletRegistry.getByFeature('solana:signTransaction')[0];
   const [result] = await wallet.features['solana:signTransaction'].signTransaction({
     account: wallet.accounts[0],
     transaction: txBytes,
     chain: 'solana:mainnet',
   });
   ```

**Effort:** ~2 weeks (refactor existing Solana tools + build adapter layer)
**Risk:** Low — wraps existing working code, no protocol changes
**Value:** Future multi-chain support becomes plug-and-play

---

### Path B: WebView Wallet Bridge (For Web Companion)

**What:** If SeekerClaw ever gets a web companion (seekerclaw.xyz dashboard, web setup tool), implement full OWS in the web layer so browser wallet extensions can interact with the agent.

**Architecture:**

```
┌─────────────────────────────────────────────────────┐
│              seekerclaw.xyz (Web App)                 │
│                                                       │
│  ┌──────────────────────────────────────────────┐    │
│  │  @wallet-standard/app → getWallets()          │    │
│  │  Discovers: Phantom, Backpack, Solflare, etc. │    │
│  │  standard:connect → get accounts              │    │
│  │  solana:signTransaction → sign via extension  │    │
│  └──────────────┬───────────────────────────────┘    │
│                  │                                     │
│                  ▼                                     │
│  ┌──────────────────────────────────────────────┐    │
│  │  API → SeekerClaw Agent (via Telegram or WS)  │    │
│  │  Signed TX submitted to agent for execution   │    │
│  └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

**User Flow:**
1. User visits seekerclaw.xyz/wallet
2. Page calls `getWallets()` → discovers Phantom extension
3. User clicks "Connect" → `standard:connect` → gets accounts
4. User can sign transactions in browser, relay to agent
5. Or: agent requests signatures, web UI prompts wallet

**Effort:** ~1 week (standard web integration, well-documented)
**Risk:** Low — standard web pattern
**Value:** Medium — enables browser-based wallet management for the agent

---

### Path C: SeekerClaw as a Wallet Standard Wallet (Advanced)

**What:** Register SeekerClaw itself as a Wallet Standard wallet that other dApps (web or mobile) can discover and use. The agent becomes the signer — dApps request signatures, the agent decides whether to approve.

**This is the most novel integration** and aligns with SeekerClaw's identity as an autonomous agent.

**Architecture:**

```
┌──────────────────────────────────────────────────────┐
│                  External dApp (web)                   │
│  getWallets() → discovers "SeekerClaw Agent Wallet"    │
│  standard:connect → WebSocket to SeekerClaw agent     │
│  solana:signTransaction → agent evaluates + signs     │
└──────────────┬───────────────────────────────────────┘
               │ WebSocket / HTTP
               ▼
┌──────────────────────────────────────────────────────┐
│              SeekerClaw Agent                          │
│  Receives sign request → evaluates safety →            │
│  Asks user via Telegram "dApp X wants to sign TX" →    │
│  User approves → MWA signs → returns to dApp          │
└──────────────────────────────────────────────────────┘
```

**User Flow:**
1. User installs SeekerClaw browser extension (thin proxy)
2. Extension calls `registerWallet(new SeekerClawWallet())` on page load
3. Any dApp calling `getWallets()` sees "SeekerClaw Agent"
4. dApp requests `solana:signTransaction`
5. Extension relays request to SeekerClaw agent (via WebSocket/Telegram)
6. Agent evaluates: is this safe? Is this within the user's rules?
7. Agent asks user via Telegram: "Raydium wants to swap 5 SOL → USDC. Approve?"
8. User replies YES → agent signs via MWA → returns signed TX to dApp

**Effort:** ~4-6 weeks (browser extension + agent protocol + security review)
**Risk:** High — new attack surface, needs careful security design
**Value:** High — SeekerClaw becomes a programmable wallet layer for all dApps

---

## 5. Recommended Integration Plan

### Phase 1: Internal Adapter Layer (Path A) — Priority: HIGH

**Goal:** Standardize wallet interactions using OWS interface patterns.

```
Week 1:
├── Define WalletAdapter base class (wallet-standard/adapter.js)
├── Define WalletRegistry (wallet-standard/registry.js)
├── Implement SolanaMwaAdapter wrapping existing bridge calls
└── Unit tests for adapter layer

Week 2:
├── Refactor tools/solana.js to use adapter instead of direct bridge calls
├── Refactor solana.js RPC calls to go through adapter
├── Update system prompt (agent self-awareness)
└── Integration test: all 16 Solana tools still work through adapter
```

**Files to create:**
```
app/src/main/assets/nodejs-project/
├── wallet-standard/
│   ├── adapter.js          # WalletAdapter base class
│   ├── registry.js         # WalletRegistry (discover + manage)
│   ├── solana-mwa.js       # SolanaMwaAdapter (wraps AndroidBridge)
│   └── index.js            # Exports
```

**Files to modify:**
```
app/src/main/assets/nodejs-project/
├── tools/solana.js         # Use walletRegistry instead of direct bridge calls
├── solana.js               # Use adapter for wallet operations
├── main.js                 # Initialize registry + register MWA adapter on startup
└── claude.js               # Update system prompt with wallet standard info
```

### Phase 2: TON Adapter (Path A extension) — Priority: MEDIUM

**Goal:** Add TON blockchain support using the same adapter interface.

```
wallet-standard/
├── ton-adapter.js          # TonConnectAdapter extends WalletAdapter
```

**Kotlin side:**
```
app/src/main/java/com/seekerclaw/app/
├── ton/
│   ├── TonWalletManager.kt    # TON Connect protocol
│   └── TonAuthActivity.kt     # TON wallet intent
├── bridge/
│   └── AndroidBridge.kt       # Add /ton/* endpoints
```

### Phase 3: Browser Extension (Path C) — Priority: LOW (future)

Only if there's user demand for dApp integration.

---

## 6. User Flow Diagrams

### Flow 1: Multi-Wallet Setup (Path A)

```
User opens SeekerClaw → Settings → Wallets

┌─────────────────────────────────────┐
│         Wallet Management            │
│                                       │
│  Connected Wallets:                   │
│  ┌─────────────────────────────────┐ │
│  │ 🟢 Phantom (Solana)             │ │
│  │    7xKX...gAsU                   │ │
│  │    Features: sign, signAndSend   │ │
│  └─────────────────────────────────┘ │
│  ┌─────────────────────────────────┐ │
│  │ 🟢 TonKeeper (TON)              │ │
│  │    EQBv...2kCQ                   │ │
│  │    Features: sign, transfer      │ │
│  └─────────────────────────────────┘ │
│                                       │
│  [+ Connect Wallet]                   │
│                                       │
│  Select chain:                        │
│  ┌────────┐ ┌────────┐ ┌──────────┐ │
│  │ Solana │ │  TON   │ │ Ethereum │ │
│  └────────┘ └────────┘ └──────────┘ │
└─────────────────────────────────────┘
```

### Flow 2: Agent Swap with Wallet Selection (Path A)

```
User (Telegram): "Swap 1 SOL for USDC"

Agent:
  1. walletRegistry.getByFeature('solana:signTransaction')
     → [PhantomAdapter]  (only one Solana wallet)

  2. Get quote from Jupiter
     → "1 SOL ≈ 142.50 USDC (0.1% slippage)"

  3. Show confirmation:
     "🔄 Swap 1 SOL → ~142.50 USDC via Jupiter Ultra
      Wallet: Phantom (7xKX...gAsU)
      Fee: Gasless (Jupiter pays)
      Reply YES to confirm"

  4. User: "YES"

  5. wallet.features['solana:signTransaction'].signTransaction({
       account: wallet.accounts[0],
       transaction: ultraOrderTx,
       chain: 'solana:mainnet'
     })
     → MWA popup on device → user taps approve

  6. Jupiter Ultra execute → TX confirmed
     "✅ Swapped 1 SOL → 142.47 USDC
      TX: 4sGj...kL2m"
```

### Flow 3: Cross-Chain Operation (Path A, future)

```
User (Telegram): "What's my total balance across all wallets?"

Agent:
  1. walletRegistry.getAll()
     → [PhantomAdapter, TonKeeperAdapter]

  2. For each wallet:
     - Phantom: solana_balance → 5.2 SOL ($742), 200 USDC
     - TonKeeper: ton_balance → 50 TON ($310)

  3. Response:
     "💰 Portfolio Summary:
      Solana (Phantom): $942
        • 5.2 SOL ($742)
        • 200 USDC ($200)
      TON (TonKeeper): $310
        • 50 TON ($310)
      ─────────────
      Total: $1,252"
```

### Flow 4: dApp Signature Relay (Path C, future)

```
User visits raydium.io in browser with SeekerClaw extension

1. Raydium calls getWallets() → sees "SeekerClaw Agent"
2. User clicks "Connect" in Raydium
3. Extension → WebSocket → SeekerClaw Agent
4. Agent sends Telegram: "🔗 Raydium wants to connect. Allow?"
5. User: "yes"
6. Agent: standard:connect → returns account to Raydium

7. User initiates swap on Raydium
8. Raydium calls solana:signTransaction
9. Extension → Agent → Telegram:
   "✍️ Raydium wants to sign a transaction:
    Swap 10 USDC → SOL on Raydium AMM
    Programs: Raydium AMM v4, Token Program
    Approve?"
10. User: "yes"
11. Agent → MWA → Phantom signs → returns to Raydium
12. Raydium broadcasts TX
```

---

## 7. What We Need (Requirements by Path)

### Path A (Adapter Layer) — Minimal Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| Define WalletAdapter JS class | **TODO** | Mirror OWS Wallet interface |
| Define WalletRegistry | **TODO** | Discovery + feature filtering |
| SolanaMwaAdapter | **TODO** | Wrap existing bridge calls |
| Refactor tools/solana.js | **TODO** | Use adapter instead of direct bridge |
| Update system prompt | **TODO** | Agent knows about wallet standard |
| Tests | **TODO** | All 16 Solana tools still pass |
| No new dependencies | ✅ | Pure JS, no npm packages needed |
| No Android changes | ✅ | Bridge endpoints stay the same |
| No new permissions | ✅ | Same MWA flow |

### Path B (Web Companion) — Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| Web app (seekerclaw.xyz) | Partial | Setup tool exists, no wallet page |
| `@wallet-standard/app` npm package | **TODO** | Standard web dependency |
| `@solana/wallet-standard` | **TODO** | Solana features |
| WebSocket to agent | **TODO** | Real-time signature relay |
| CORS / security headers | **TODO** | Prevent cross-origin attacks |

### Path C (Agent-as-Wallet) — Requirements

| Requirement | Status | Notes |
|-------------|--------|-------|
| Browser extension (Chrome/Firefox) | **TODO** | Thin proxy, calls registerWallet() |
| `@wallet-standard/wallet` package | **TODO** | Registration API |
| WebSocket server in agent | **TODO** | Receive sign requests |
| Telegram approval flow | **TODO** | Agent asks user before signing |
| Transaction safety analysis | Partial | verifySwapTransaction() exists |
| Rate limiting | Partial | 15s cooldown exists for swaps |
| Extension signing key | **TODO** | Verify extension identity |
| Security audit | **TODO** | New attack surface review |

---

## 8. Risk Assessment

| Risk | Path A | Path B | Path C |
|------|--------|--------|--------|
| Breaking existing functionality | Low (refactor only) | None (new code) | None (new code) |
| New attack surface | None | Medium (CORS) | **High** (relay protocol) |
| User confusion | Low | Low | Medium (new UX) |
| Development effort | 2 weeks | 1 week | 4-6 weeks |
| Maintenance burden | Low | Low | High |
| Value to users | High (multi-chain) | Medium | High (dApp access) |

---

## 9. Recommendation

**Start with Path A.** It's the highest-value, lowest-risk integration:

1. **No new dependencies** — pure JS abstraction layer
2. **No Android changes** — bridge stays the same
3. **Backward compatible** — all existing tools work through adapter
4. **Future-proof** — adding TON, ETH, or any chain is just a new adapter class
5. **Follows OWS principles** — feature-based discovery, namespaced identifiers, immutable accounts

Path B and C are future work, contingent on:
- Path B: Building a web dashboard (currently not planned)
- Path C: User demand for dApp integration + security audit capacity

---

## 10. OWS Concepts to Adopt vs Skip

### Adopt (in our adapter layer)

| OWS Concept | How We Use It |
|-------------|---------------|
| `Wallet` interface shape | `WalletAdapter` base class |
| `WalletAccount` data object | Account representation per chain |
| `IdentifierString` namespacing | `solana:mainnet`, `ton:mainnet`, `standard:connect` |
| Feature map pattern | `wallet.features['solana:signTransaction']` |
| `standard:connect/disconnect` | Unified connect/disconnect across chains |
| `standard:events` | Wallet state change notifications |
| Chain identifiers | `solana:mainnet`, `solana:devnet`, `ton:mainnet` |
| Raw bytes (Uint8Array) | Already using Buffer/Uint8Array for transactions |

### Skip (not applicable to native mobile)

| OWS Concept | Why Skip |
|-------------|----------|
| `window` event registration | No browser — use explicit registry |
| `registerWallet()` / `getWallets()` | Use `WalletRegistry.register()` directly |
| `UnstoppableCustomEvent` | No DOM events |
| `WalletIcon` data URI format | Use Android drawable resources |
| React hooks (`useWallets`) | Kotlin Compose, not React |
| Browser extension detection | Use Android intent resolution |

---

## Appendix A: OWS Type Reference

```typescript
// Core types (from @wallet-standard/base)
interface Wallet {
    readonly version: '1.0.0';
    readonly name: string;
    readonly icon: WalletIcon;
    readonly chains: IdentifierArray;
    readonly features: IdentifierRecord<unknown>;
    readonly accounts: readonly WalletAccount[];
}

interface WalletAccount {
    readonly address: string;
    readonly publicKey: ReadonlyUint8Array;
    readonly chains: IdentifierArray;
    readonly features: IdentifierArray;
    readonly label?: string;
    readonly icon?: WalletIcon;
}

type IdentifierString = `${string}:${string}`;

// Solana features (from @solana/wallet-standard-features)
type SolanaSignTransactionFeature = {
    'solana:signTransaction': {
        version: '1.0.0';
        supportedTransactionVersions: readonly ('legacy' | 0)[];
        signTransaction(...inputs: SolanaSignTransactionInput[]): Promise<SolanaSignTransactionOutput[]>;
    };
};

type SolanaSignAndSendTransactionFeature = {
    'solana:signAndSendTransaction': {
        version: '1.0.0';
        supportedTransactionVersions: readonly ('legacy' | 0)[];
        signAndSendTransaction(...inputs): Promise<{ signature: Uint8Array }[]>;
    };
};

type SolanaSignMessageFeature = {
    'solana:signMessage': {
        version: '1.0.0';
        signMessage(...inputs: { account, message: Uint8Array }[]): Promise<{ signedMessage, signature }[]>;
    };
};
```

## Appendix B: Current SeekerClaw ↔ OWS Mapping

| OWS Feature | Current SeekerClaw Equivalent | File |
|-------------|-------------------------------|------|
| `standard:connect` | `androidBridgeCall('/solana/authorize')` | `solana.js` |
| `standard:disconnect` | Delete `solana_wallet.json` | `ConfigManager.kt` |
| `solana:signTransaction` | `androidBridgeCall('/solana/sign-only')` | `AndroidBridge.kt` |
| `solana:signAndSendTransaction` | `androidBridgeCall('/solana/sign')` | `AndroidBridge.kt` |
| `solana:signMessage` | **Not implemented** | — |
| `solana:signIn` (SIWS) | **Not implemented** | — |
| Wallet discovery | MWA automatic (first compatible) | `SolanaWalletManager.kt` |
| Account storage | Encrypted SharedPrefs + workspace JSON | `ConfigManager.kt` |
| Feature detection | **None** (assumes full MWA support) | — |
| Multi-chain | **None** (Solana only) | — |
