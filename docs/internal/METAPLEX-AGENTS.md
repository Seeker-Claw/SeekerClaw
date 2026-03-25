# Metaplex Agent Passport — Complete Reference

> **Sources**: [metaplex.com/docs/agents](https://www.metaplex.com/docs/agents) | [GitHub Skill](https://github.com/metaplex-foundation/skill) | [x402.org](https://www.x402.org/) | [8004-solana](https://github.com/QuantuLabs/8004-solana)
> **Last updated**: 2026-03-25

---

## 1. Architecture Overview

Four layers work together to give AI agents on-chain identity, autonomous spending, reputation, and payments:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: PAYMENTS — x402 Protocol                          │
│  HTTP 402 + USDC stablecoin micropayments                   │
│  Agent pays for API calls autonomously via HTTP              │
│  Created by Coinbase · Backed by Google, Visa, AWS, Anthropic│
├─────────────────────────────────────────────────────────────┤
│  Layer 3: REPUTATION — 8004-solana                          │
│  On-chain feedback (0-100), trust tiers, SEAL v1 integrity  │
│  Tracks: x402 success/fail, quality, uptime                 │
│  By QuantuLabs/PayAI                                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: DELEGATION — Agent Tools Program                  │
│  Executive profiles + execution delegation                   │
│  Enables autonomous spending from PDA wallet                 │
│  No on-chain spending limits — all safety is app-side        │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: IDENTITY — Metaplex 014 Agent Registry            │
│  Agent = Core NFT + AgentIdentity plugin + ERC-8004 metadata│
│  Asset Signer PDA = theft-proof wallet (no private key)      │
│  Programs: Agent Identity + Agent Tools                      │
└─────────────────────────────────────────────────────────────┘
```

### SeekerClaw Model C (Confirmed)

```
User's Wallet (Phantom/Backpack)          SeekerClaw App
  │                                         │
  │ OWNS the Core NFT (agent identity)      │ GENERATES executive keypair
  │ Can revoke delegation anytime            │ Stores in Android Keystore
  │ Funds the agent wallet                   │ Signs Execute autonomously
  │                                         │
  └──── Delegates execution ONCE via MWA ───►│
                                             │
              Agent Wallet                   │
              (Asset Signer PDA)             │
              ├─ Receives SOL/USDC           │
              ├─ Spends via Execute ◄────────┘
              └─ No private key (theft-proof)
```

---

## 2. Metaplex 014 Agent Registry

### What It Is

"014" is Metaplex's on-chain agent registry. Each agent is represented as:

1. **MPL Core NFT** — single-account asset on Solana
2. **AgentIdentity plugin** — attached to the NFT with Transfer/Update/Execute lifecycle hooks
3. **ERC-8004 metadata** — off-chain JSON describing the agent (name, services, trust)
4. **Asset Signer PDA** — built-in wallet derived from the NFT's public key

### On-Chain Programs

| Program | Address | Purpose |
|---------|---------|---------|
| **Agent Identity** | `1DREGFgysWYxLnRnKQnwrxnJQeSMk2HmGaC6whw2B2p` | Identity PDA, AgentIdentity plugin with lifecycle hooks |
| **Agent Tools** | `TLREGni9ZEyGC3vnPZtqUh95xQ8oPqJSvNjvB7FGK8S` | Executive profiles, execution delegation |

Same addresses on **Mainnet and Devnet**.

### Instructions

| Program | Instruction | Purpose |
|---------|-------------|---------|
| Agent Identity | `RegisterIdentityV1` | Creates identity PDA, attaches AgentIdentity plugin |
| Agent Tools | `RegisterExecutiveV1` | Creates executive profile PDA (one-time per wallet) |
| Agent Tools | `DelegateExecutionV1` | Links agent to executive (per-asset delegation) |

### On-Chain Account Structures

**AgentIdentityV1** (40 bytes)
| Field | Size | Description |
|-------|------|-------------|
| key (discriminator) | 1 byte | Account type |
| bump | 1 byte | PDA bump seed |
| _padding | 6 bytes | Reserved |
| asset | 32 bytes | Core NFT public key |

Seeds: `["agent_identity", <asset_pubkey>]`

**ExecutiveProfileV1** (40 bytes)
| Field | Size | Description |
|-------|------|-------------|
| key | 1 byte | Account type |
| _padding | 7 bytes | Reserved |
| authority | 32 bytes | Executive wallet public key |

Seeds: `["executive_profile", <authority>]`

**ExecutionDelegateRecordV1** (104 bytes)
| Field | Size | Description |
|-------|------|-------------|
| key | 1 byte | Account type |
| bump | 1 byte | PDA bump seed |
| _padding | 6 bytes | Reserved |
| executiveProfile | 32 bytes | Executive profile PDA |
| authority | 32 bytes | Executive wallet |
| agentAsset | 32 bytes | Agent's Core NFT |

Seeds: `["execution_delegate_record", <executive_profile>, <agent_asset>]`

### Error Codes

**Agent Identity Program:**

| Code | Name |
|------|------|
| 0 | InvalidSystemProgram |
| 1 | InvalidInstructionData |
| 2 | InvalidAccountData |
| 3 | InvalidMplCoreProgram |
| 4 | InvalidCoreAsset |

**Agent Tools Program:**

| Code | Name |
|------|------|
| 0 | InvalidSystemProgram |
| 1 | InvalidInstructionData |
| 2 | InvalidAccountData |
| 3 | InvalidMplCoreProgram |
| 4 | InvalidCoreAsset |
| 5 | ExecutiveProfileMustBeUninitialized |
| 6 | InvalidExecutionDelegateRecordDerivation |
| 7 | ExecutionDelegateRecordMustBeUninitialized |
| 8 | InvalidAgentIdentity |
| 9 | AgentIdentityNotRegistered |
| 10 | AssetOwnerMustBeTheOneToDelegateExecution |
| 11 | InvalidExecutiveProfileDerivation |

---

## 3. Asset Signer PDA (Agent Wallet)

### How It Works

Every MPL Core NFT automatically has a **built-in wallet** — the Asset Signer PDA. No registration, no initialization, no setup required.

| Property | Detail |
|----------|--------|
| Derivation | `findAssetSignerPda(umi, { asset: assetPublicKey })` |
| Private key | **None** — cannot be stolen |
| Receives funds | Yes — SOL and SPL tokens, immediately, no setup |
| Spends funds | Only via Core **Execute** instruction |
| Who can Execute | Asset **owner** OR **plugin-approved delegate** (executive) |

### How Execute Works (Step by Step)

1. Caller constructs transaction with Core `ExecuteV1` instruction
2. Passes: target program, instruction bytes, accounts
3. Core checks: is the caller the owner? Or does a plugin approve?
4. AgentIdentity plugin checks: does a valid `ExecutionDelegateRecordV1` exist for this caller?
5. If approved: Core does CPI with `invoke_signed()` using Asset Signer PDA seeds
6. Asset Signer PDA signs the target instruction (SOL transfer, token transfer, anything)

### Security Reality

**Delegation = full control. No on-chain limits.**

Once an executive is delegated:
- Can transfer ALL SOL from agent wallet — **no cap**
- Can transfer ALL SPL tokens — **no restriction**
- Can call ANY Solana program — **no allowlist**
- Can drain the entire wallet — **nothing stops it on-chain**

The `ExecutionDelegateRecordV1` stores only: executive profile, authority, agent asset. **No spending caps, no program allowlist, no rate limits.** 104 bytes — no room for permission scoping.

**The only on-chain brake:** `FreezeExecute` plugin — binary (freeze ALL Execute or none). Someone must call it proactively.

**All spending controls MUST be app-side.** This is how SeekerClaw handles it:

| Control | Default | Enforced by |
|---------|---------|-------------|
| Per-payment max | 0.01 SOL | App code (before signing) |
| Daily spending limit | 0.1 SOL | App code (cumulative tracker) |
| Auto-approve threshold | 0.001 SOL | App code (below = silent, above = Telegram confirm) |
| Kill switch | Settings toggle | Revoke delegation on-chain |
| Fund only what you can lose | User's choice | Agent wallet is separate from main wallet |

### Lifecycle Hooks

When AgentIdentity is registered, the plugin attaches with:

| Hook | Purpose |
|------|---------|
| Transfer | Validates asset transfers |
| Update | Validates metadata updates |
| Execute | **Approves Execute from delegated executives** |

---

## 4. ERC-8004 Registration Document

The `agentRegistrationUri` points to a JSON document (ideally on Arweave) following the ERC-8004 standard (Draft, created 2025-08-13).

### Full Schema

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "SeekerBot",
  "description": "A personal AI agent running 24/7 on Solana Seeker via SeekerClaw.",
  "image": "https://arweave.net/<tx-hash>",
  "services": [
    {
      "name": "web",
      "endpoint": "https://my-agent.seekerclaw.xyz"
    },
    {
      "name": "A2A",
      "endpoint": "https://my-agent.seekerclaw.xyz/agent-card.json",
      "version": "0.3.0"
    },
    {
      "name": "MCP",
      "endpoint": "https://my-agent.seekerclaw.xyz/mcp",
      "version": "2025-06-18"
    }
  ],
  "active": true,
  "registrations": [
    {
      "agentId": "<MINT_ADDRESS>",
      "agentRegistry": "solana:101:metaplex"
    }
  ],
  "supportedTrust": ["reputation", "crypto-economic"]
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| type | YES | Must be `https://eips.ethereum.org/EIPS/eip-8004#registration-v1` |
| name | YES | Human-readable agent name |
| description | YES | What the agent does and how to interact |
| image | YES | Avatar/logo URI |
| services | No | Array of service endpoints |
| active | No | Boolean — currently active? |
| registrations | No | Array: agentId (mint) + agentRegistry |
| supportedTrust | No | Trust models: reputation, crypto-economic, tee-attestation |

### Service Types

| Type | Description |
|------|-------------|
| web | Web interface |
| A2A | Agent-to-Agent protocol (Google A2A) |
| MCP | Model Context Protocol (Anthropic MCP) |
| OASF | Open Agent Service Framework |
| DID | Decentralized Identifier |
| email | Email contact |
| Custom | Any string |

---

## 5. Executive Delegation (How Autonomous Spending Works)

### Why It's Needed

The Asset Signer PDA has no private key — it can't sign by itself. For an agent to spend autonomously (x402 payments at 3am while user sleeps), an off-chain executor must be delegated.

### SeekerClaw Flow (Model C)

```
Step 1: SETUP (one-time)
  SeekerClaw generates Ed25519 keypair
  Private key → Android Keystore (AES-256-GCM encrypted)
  Public key → displayed in Settings

Step 2: REGISTER EXECUTIVE (one-time)
  SeekerClaw builds RegisterExecutiveV1 tx for its keypair
  User signs via MWA → broadcasts → executive profile created on-chain

Step 3: DELEGATE (one-time)
  SeekerClaw builds DelegateExecutionV1 tx
  User signs via MWA → broadcasts → delegation record created
  From now on: SeekerClaw can Execute autonomously

Step 4: FUND (anytime)
  User sends SOL/USDC to Asset Signer PDA address
  Standard transfer — no special tx needed

Step 5: AUTONOMOUS SPENDING
  Agent decides to pay (x402, A2A, etc.)
  App builds Execute tx → signs with stored executive key
  No MWA prompt, no user interaction
  Broadcasts → funds move from agent wallet
```

### Constraints

- One executive profile per wallet
- Delegation is per-asset (separate record per agent)
- Only the asset owner can delegate (enforced on-chain, error code 10)
- Owner can switch executives by creating new delegation record
- Owner can revoke by... (Note: revocation mechanism needs verification — may require program update or new delegation to null)

---

## 6. x402 Protocol

### What It Is

x402 is an open HTTP payment protocol created by **Coinbase** that revives the dormant HTTP 402 "Payment Required" status code. It enables instant, automatic stablecoin micropayments directly over HTTP.

**x402 Foundation** members: Coinbase, Cloudflare, Google, Visa, AWS, Circle, Anthropic, Vercel.

### How It Works (12-Step Flow)

```
Agent                           API Server                    Facilitator
  │                                │                              │
  │─── GET /premium-data ─────────►│                              │
  │                                │                              │
  │◄── 402 Payment Required ──────│                              │
  │    PAYMENT-REQUIRED header:    │                              │
  │    amount, asset (USDC),       │                              │
  │    network, recipient wallet   │                              │
  │                                │                              │
  │ [Agent signs payment locally   │                              │
  │  with private key — nothing    │                              │
  │  leaves the device]            │                              │
  │                                │                              │
  │─── GET /premium-data ─────────►│                              │
  │    PAYMENT-SIGNATURE header    │──── Verify signature ───────►│
  │                                │                              │
  │                                │◄─── Submit on-chain, ───────│
  │                                │     confirm settlement       │
  │                                │                              │
  │◄── 200 OK + data ─────────────│                              │
  │    PAYMENT-RESPONSE header     │                              │
  │    (tx hash, confirmation)     │                              │
```

### Key Properties

| Property | Detail |
|----------|--------|
| Creator | Coinbase Development Platform |
| Payment currency | USDC stablecoin (primary) |
| Supported chains | Solana, Base, Polygon, Ethereum, Stellar |
| Solana cost | ~$0.00025 per transaction |
| Solana finality | ~400ms |
| Settlement | Sub-2-second total (Solana) |
| Identity required | **No** — x402 separates payment from identity |
| Wallet type | **Any** — EOA, MPC, hardware, smart contract, PDA |
| Adoption | 100M+ payments, 35M+ on Solana, 10K+ paid endpoints |
| Facilitators | 22+ independent (Coinbase CDP, Corbits, PayAI, etc.) |

### x402 on SeekerClaw (with Agent Passport)

```
Step 1: Agent calls external API
  web_fetch("https://api.example.com/premium-data")
  → 402 Payment Required
  → Headers: X-Payment-Address, X-Payment-Amount, X-Payment-Currency

Step 2: Agent builds Execute transaction
  Build Core Execute instruction:
    → Target: SystemProgram.Transfer (or SPL Token transfer)
    → From: Asset Signer PDA (agent wallet)
    → To: service provider wallet
    → Amount: as specified in 402 response

Step 3: Executive signs (autonomous)
  SeekerClaw signs with stored executive keypair
  No MWA prompt — app-side spending limits enforced
  Broadcasts transaction

Step 4: Agent retries with payment proof
  web_fetch("https://api.example.com/premium-data", {
    headers: {
      "X-Payment-Signature": "<solana-tx-signature>",
      "X-Payment-Agent": "<agent-asset-id>"
    }
  })
  → 200 OK — data returned

Step 5: Reputation update (optional)
  If agent is registered on 8004-solana:
  → x402 payment success logged in reputation tags
  → Trust tier updates via SEAL v1 hash-chain
```

---

## 7. 8004-solana (Reputation Layer)

### What It Is

A Solana port of the ERC-8004 "Trustless Agents" standard, built by **QuantuLabs** (supported by PayAI). Provides on-chain reputation and validation for agents.

| Property | Detail |
|----------|--------|
| Mainnet Program | `8oo4dC4JvBLwy5tGgiH3WwK4B9PWxL9Z4XjA2jzkQMbQ` |
| Devnet Program | `8oo4J9tBB3Hna1jRQ3rWvJjojqM5DYTDJo5cejUuJy3C` |
| License | MIT |
| Version | 0.8.1 |
| npm | `8004-solana` |

### Three Modules

**1. Identity Module**
- Agent as Metaplex Core NFT (same as Metaplex 014)
- Single collection design (all agents in one collection)
- Immutable on-chain metadata

**2. Reputation Module**
- On-chain feedback scoring (0-100 scale)
- 5-tier Sybil resistance system
- SEAL v1 cryptographic integrity (rolling hash-chain)
- Event-based architecture (not account-based)
- Tags track: uptime, quality, x402 payment success/failure

**3. Validation Module (ATOM Engine)**
- Independent validator checks with proof recording
- External reputation aggregator
- Sophisticated signal filtering

### Connection to x402

8004-solana integrates with x402 by:
- Recording x402 payment success/failure as reputation feedback tags
- Building trust tiers based on payment history
- Agents proving payment reliability as part of identity
- Facilitators can log payment history for reputation scoring

---

## 8. SeekerClaw Integration Path

### What We Can Build Ourselves (No SDK, No Metaplex API)

All Metaplex programs are **on-chain and permissionless** — anyone can call them. We build raw transactions:

| Capability | How | Dependencies |
|------------|-----|-------------|
| Register agent identity | Borsh-serialize RegisterIdentityV1 instruction | Zero |
| Register executive | Borsh-serialize RegisterExecutiveV1 | Zero |
| Delegate execution | Borsh-serialize DelegateExecutionV1 | Zero |
| Spend SOL from agent wallet | Build Core Execute + SystemProgram.Transfer | Zero |
| Spend SPL from agent wallet | Build Core Execute + Token.Transfer | Zero |
| Upload ERC-8004 doc to Arweave | Irys REST API via web_fetch | Zero |
| Upload image to Arweave | Irys REST API via web_fetch | Zero |
| x402 payments | Execute + submit proof to facilitator | Zero |
| Read agent identity | Helius DAS API (already have) | Zero |
| Check agent wallet balance | Solana RPC getBalance (already have) | Zero |

**Implementation:** One file — `metaplex-tx-builder.js` (~300-400 lines)
- Manual Borsh serialization for 3 Agent program instructions
- Core Execute instruction builder
- PDA derivation (deterministic, just math)
- Transaction construction (blockhash, signatures, serialization)

### New Tools Needed (6)

| Tool | Description | Confirmation |
|------|-------------|-------------|
| `metaplex_register_agent` | Register agent identity on-chain | YES — costs SOL |
| `metaplex_agent_info` | Fetch agent identity + wallet address | No |
| `metaplex_delegate_executive` | Delegate execution to app keypair | YES — one-time |
| `metaplex_agent_balance` | Check agent wallet SOL/token balance | No |
| `metaplex_agent_send` | Send SOL/SPL from agent wallet | YES — spends funds |
| `metaplex_agent_pay` | x402 payment from agent wallet | Configurable |

### Spending Controls (App-Side)

| Setting | Default | Description |
|---------|---------|-------------|
| Auto-approve threshold | 0.001 SOL | Below = silent, above = ask in Telegram |
| Daily spending limit | 0.1 SOL | Hard cap per 24h |
| Per-payment max | 0.01 SOL | Single payment cap |
| Require Telegram confirmation | ON | User approves each payment in chat |
| Kill switch | Settings toggle | Revoke delegation on-chain |

### Setup Flow for Users

```
1. User opens Settings > Agent Identity
2. Taps "Register on Metaplex"
3. Fills in: name, description, avatar
4. MWA prompt: "Register agent for ~0.015 SOL?" → Approve
5. Auto: app registers executive + delegates (2 more MWA prompts)
6. Agent now has: on-chain identity + wallet + autonomous spending
7. User sends SOL/USDC to agent wallet address
8. Sets spending limits
9. Done — agent is live on Metaplex 014 registry
```

---

## 9. Raw Transaction Builder Approach

### Why Raw TX (Not SDK)

| | Raw TX Builder | Bundled SDK |
|---|---|---|
| Dependencies | Zero | Many (Umi, mpl-core, etc.) |
| Bundle size | ~5-10 KB | ~500KB+ |
| Node 18 compatible | Yes (pure JS) | Unknown |
| Maintenance | Manual update if program changes | npm update |
| Control | Full | Framework-dependent |

### What We Build

**File:** `metaplex-tx-builder.js` (~300-400 lines)

```
Borsh serialization:
  - RegisterIdentityV1 instruction data
  - RegisterExecutiveV1 instruction data
  - DelegateExecutionV1 instruction data

PDA derivation:
  - AgentIdentityV1 PDA from asset pubkey
  - ExecutiveProfileV1 PDA from authority
  - ExecutionDelegateRecordV1 PDA from executive + asset
  - Asset Signer PDA from asset pubkey

Transaction construction:
  - Recent blockhash fetch
  - Account meta lists (per instruction)
  - Transaction serialization (legacy format)
  - Signature placeholder for MWA signing

Core Execute wrapper:
  - Build ExecuteV1 with target instruction (SOL/SPL transfer)
  - Sign with executive keypair (stored in Android Keystore)
  - Broadcast via Solana RPC
```

### Irys REST API (for Arweave Uploads)

No SDK needed — Irys has HTTP endpoints:

```
1. Fund Irys balance: send SOL to Irys node address
2. Upload JSON: POST https://node1.irys.xyz/tx with signed data
3. Get receipt: returns Arweave transaction ID
4. URI: https://arweave.net/<tx-id>
```

---

## 10. The Metaplex Skill (Knowledge Base)

The [Metaplex Foundation skill](https://github.com/metaplex-foundation/skill) is an AI coding agent knowledge base. It uses progressive disclosure — a router directs to relevant reference files.

### Repository Structure

```
skills/metaplex/
  SKILL.md                          ← Router (~100 lines)
  references/
    ├── cli-agent.md                ← Agent CLI commands
    ├── cli-bubblegum.md            ← Compressed NFTs
    ├── cli-candy-machine.md        ← NFT drops
    ├── cli-core.md                 ← Core NFTs
    ├── cli-genesis.md              ← Token launches
    ├── cli-*.md (5 more)           ← Config, setup, toolbox, troubleshooting
    ├── concepts.md                 ← Account structures, PDAs, costs
    ├── metadata-json.md            ← NFT JSON schema
    ├── sdk-agent.md                ← Agent Registry SDK
    ├── sdk-bubblegum.md            ← Compressed NFTs SDK
    ├── sdk-core.md                 ← Core NFTs SDK
    ├── sdk-genesis.md              ← Token launches SDK
    ├── sdk-token-metadata.md       ← Legacy NFTs SDK (Umi)
    ├── sdk-token-metadata-kit.md   ← Legacy NFTs SDK (Kit)
    └── sdk-umi.md                  ← Umi framework setup
```

### 6 Programs Covered

| Program | What It Does |
|---------|-------------|
| **Core** | Next-gen NFTs with plugin architecture, royalty enforcement, soulbound |
| **Token Metadata** | Legacy/fungible tokens, pNFTs, collection verification |
| **Bubblegum** | Compressed NFTs via Merkle trees (~98% cheaper) |
| **Candy Machine** | NFT drops with guards (payment, access, time, bot protection) |
| **Genesis** | Token launches (project 48h / memecoin 1h), bonding curves, Raydium graduation |
| **Agent Registry** | On-chain AI identity, executive delegation, Asset Signer wallets |

### SeekerClaw Adaptation

For our partner skill, we:
- **Keep:** concepts, metadata-json, agent registry knowledge
- **Remove:** all CLI commands (can't run mplx), SDK code blocks (can't npm install)
- **Add:** DAS query patterns, SeekerClaw tool usage, mobile optimization

---

## 11. All Program IDs

```
Agent Identity:       1DREGFgysWYxLnRnKQnwrxnJQeSMk2HmGaC6whw2B2p
Agent Tools:          TLREGni9ZEyGC3vnPZtqUh95xQ8oPqJSvNjvB7FGK8S
8004-solana:          8oo4dC4JvBLwy5tGgiH3WwK4B9PWxL9Z4XjA2jzkQMbQ
Core:                 CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d
Token Metadata:       metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s
Bubblegum V1:         BGUMAp9SX3uS4efGcFjPjkAQZ4cUNZhtHaMq64nrGf9D
Bubblegum V2:         BGUMAp9Gq7iTEuizy4pqaxsTyUCBK68MDfK752saRPUY
Core Candy Machine:   CMACYFENjoBMHzapRXyo1JZkVS6EtaDDzkjMrmQLvr4J
Genesis:              GNS1S5J5AspKXgpjz6SvKL66kPaKWAhaGRhCqPRxii2B
```

---

## 12. Key Sources

### Official Documentation
- [Metaplex Agents](https://www.metaplex.com/docs/agents) — Agent Kit landing page
- [Register an Agent](https://www.metaplex.com/docs/agents/register-agent) — RegisterIdentityV1 + ERC-8004
- [Read Agent Data](https://www.metaplex.com/docs/agents/run-agent) — Fetch/verify identity
- [Run an Agent](https://www.metaplex.com/docs/agents/run-an-agent) — Executive delegation
- [MPL Core Execute](https://metaplex.com/docs/core/execute-asset-signing) — Asset Signer PDA
- [MPL Agent Smart Contracts](https://www.metaplex.com/docs/smart-contracts/mpl-agent) — Program reference

### x402 Protocol
- [x402.org](https://www.x402.org/) — Official standard
- [Coinbase x402](https://www.coinbase.com/developer-platform/products/x402) — Product page
- [x402 Docs](https://docs.cdp.coinbase.com/x402/welcome) — Developer docs
- [GitHub: coinbase/x402](https://github.com/coinbase/x402) — Source code
- [Solana x402](https://solana.com/x402) — Solana integration
- [x402 Getting Started](https://solana.com/developers/guides/getstarted/intro-to-x402) — Tutorial

### ERC-8004 / 8004-solana
- [EIP-8004](https://eips.ethereum.org/EIPS/eip-8004) — Ethereum standard
- [8004-solana GitHub](https://github.com/QuantuLabs/8004-solana) — Solana port
- [8004-solana Registry](https://8004.qnt.sh/) — Web interface
- [npm: 8004-solana](https://www.npmjs.com/package/8004-solana) — Package

### Metaplex Skill
- [GitHub: metaplex-foundation/skill](https://github.com/metaplex-foundation/skill) — Knowledge base
- [npm: @metaplex-foundation/mpl-agent-registry](https://www.npmjs.com/package/@metaplex-foundation/mpl-agent-registry) — SDK

### SDK References
- [Umi Framework](https://developers.metaplex.com/smart-contracts/core/sdk/javascript) — JavaScript SDK
- [MPL Core TypeDoc](https://mpl-core.typedoc.metaplex.com/) — API reference
- [Irys Docs](https://docs.irys.xyz) — Arweave upload REST API
