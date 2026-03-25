# Metaplex x SeekerClaw — Partnership Proposal

> **From**: SeekerClaw Team
> **To**: Metaplex Foundation
> **Date**: 2026-03-24
> **Subject**: HTTP API for Agent Passport — enabling mobile-first AI agents on Solana

---

## Executive Summary

SeekerClaw is an Android app that turns Solana Seeker phones into 24/7 personal AI agents. Users interact via Telegram — the phone runs the agent autonomously in the background.

We want to integrate **Metaplex Agent Passport** so every SeekerClaw agent gets an on-chain identity, a theft-proof wallet, and the ability to participate in the agent economy (x402 payments, A2A interactions, MCP discovery).

**The problem**: Agent Passport currently requires the Umi SDK (`@metaplex-foundation/mpl-agent-registry`) to build transactions. SeekerClaw runs Node.js 18 via `nodejs-mobile` — we cannot install npm packages at runtime. We have wallet signing (Mobile Wallet Adapter) and HTTP capabilities, but no way to construct Metaplex program instructions.

**The ask**: A REST API that returns **unsigned Solana transactions** for Agent Passport operations. We sign locally via MWA, broadcast, done. This is the same pattern that works for Jupiter (swap API), ClawPump (token launches), and other Solana services.

---

## What SeekerClaw Has Today

| Capability | Implementation |
|------------|---------------|
| HTTP requests | `web_fetch` — any HTTPS endpoint, POST/GET, JSON |
| Wallet signing | Mobile Wallet Adapter (MWA) — signs ANY unsigned transaction |
| Transaction broadcast | MWA sign-and-broadcast or sign-only + manual broadcast |
| Read NFTs/assets | Helius DAS API (`getAssetsByOwner`, `getAsset`) |
| Read on-chain data | Solana RPC via HTTPS POST |
| SOL transfers | Built-in transaction builder + MWA signing |
| SPL token swaps | Jupiter Ultra API (gasless) |
| Agent runtime | Node.js 18 running 24/7 as foreground service |
| User interaction | Telegram bot (text, images, files, reactions) |

| What's Missing | Why |
|----------------|-----|
| Build Metaplex instructions | No SDK, no npm at runtime |
| Upload to Arweave/Irys | No SDK |
| Construct arbitrary program transactions | Only SOL transfers built-in |

---

## Proposed API

### Design Principles

1. **Unsigned transactions** — API returns base64-encoded transactions, client signs locally (no private keys leave the device)
2. **Stateless** — no sessions, no auth tokens (wallet signature = identity)
3. **Idempotent where possible** — safe to retry
4. **Mobile-friendly** — small payloads, fast responses, clear errors

### Base URL

```
https://api.metaplex.com/v1/agents
```

---

### Phase 1: Identity (Registration & Discovery)

#### 1.1 Register Agent Identity

Creates a new MPL Core asset, registers Agent Identity, uploads ERC-8004 metadata to Arweave.

```
POST /register
Content-Type: application/json

{
  "walletAddress": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
  "name": "SeekerBot",
  "description": "A personal AI agent running on Solana Seeker, available 24/7 via Telegram.",
  "image": "https://example.com/avatar.png",
  "services": [
    {
      "name": "MCP",
      "endpoint": "https://my-agent.seekerclaw.xyz/mcp",
      "version": "2025-06-18"
    },
    {
      "name": "A2A",
      "endpoint": "https://my-agent.seekerclaw.xyz/agent-card.json",
      "version": "0.3.0"
    },
    {
      "name": "web",
      "endpoint": "https://my-agent.seekerclaw.xyz"
    }
  ],
  "supportedTrust": ["reputation"],
  "collection": "optional-collection-address"
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64-encoded-transaction>",
  "assetId": "new-asset-public-key",
  "identityPda": "derived-identity-pda",
  "walletPda": "derived-asset-signer-pda",
  "registrationUri": "https://arweave.net/<tx-hash>",
  "estimatedFee": 0.015
}
```

**Client flow:**
1. Call API → get unsigned transaction
2. Present to user: "Register your agent on-chain for ~0.015 SOL?"
3. User approves → MWA signs → broadcast
4. Agent now has on-chain identity + wallet

**Notes:**
- API handles Arweave upload (image + ERC-8004 doc) server-side
- If `image` is a URL, API fetches and uploads it
- If `image` is base64 data URI, API uploads directly
- `collection` is optional — omit for standalone agents

---

#### 1.2 Update Agent Identity

Updates the ERC-8004 registration document (re-uploads to Arweave, updates on-chain URI).

```
POST /update
Content-Type: application/json

{
  "agentAsset": "asset-public-key",
  "walletAddress": "owner-wallet-address",
  "name": "SeekerBot v2",
  "description": "Updated description...",
  "services": [...],
  "active": true
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "registrationUri": "https://arweave.net/<new-tx-hash>",
  "estimatedFee": 0.005
}
```

---

#### 1.3 Fetch Agent Identity

Read an agent's on-chain identity and registration document. No transaction needed.

```
GET /identity/{assetId}
```

**Response (200):**
```json
{
  "registered": true,
  "assetId": "...",
  "owner": "owner-wallet-address",
  "identityPda": "...",
  "walletPda": "asset-signer-pda-address",
  "registrationUri": "https://arweave.net/...",
  "registrationDoc": {
    "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
    "name": "SeekerBot",
    "description": "...",
    "image": "...",
    "services": [...],
    "active": true,
    "supportedTrust": [...]
  },
  "lifecycleChecks": {
    "transfer": true,
    "update": true,
    "execute": true
  }
}
```

**Response (404):**
```json
{
  "registered": false,
  "assetId": "...",
  "error": "No agent identity registered for this asset"
}
```

---

#### 1.4 Search Agents

Discover registered agents by name, service type, or trust model.

```
GET /search?name=SeekerBot
GET /search?service=MCP
GET /search?trust=reputation
GET /search?owner=wallet-address
GET /search?page=1&limit=20
```

**Response (200):**
```json
{
  "total": 42,
  "page": 1,
  "limit": 20,
  "agents": [
    {
      "assetId": "...",
      "name": "SeekerBot",
      "description": "...",
      "image": "...",
      "services": ["MCP", "A2A", "web"],
      "active": true,
      "owner": "...",
      "walletPda": "..."
    }
  ]
}
```

---

### Phase 2: Delegation (Executive Control)

#### 2.1 Register Executive Profile

One-time setup — creates an executive profile PDA for a wallet.

```
POST /executive/register
Content-Type: application/json

{
  "walletAddress": "executive-wallet-address"
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "executiveProfilePda": "derived-pda",
  "estimatedFee": 0.003
}
```

**Response (409):**
```json
{
  "error": "Executive profile already exists",
  "executiveProfilePda": "existing-pda"
}
```

---

#### 2.2 Delegate Execution

Link an agent to an executive — allows the executive to sign transactions on behalf of the agent.

```
POST /executive/delegate
Content-Type: application/json

{
  "agentAsset": "agent-asset-public-key",
  "executiveWallet": "executive-wallet-address",
  "ownerWallet": "asset-owner-wallet-address"
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "delegationRecordPda": "derived-pda",
  "estimatedFee": 0.003
}
```

**Constraints:**
- Only the asset owner can delegate (enforced on-chain)
- One delegation record per agent-executive pair
- Owner can re-delegate to a different executive by creating a new record

---

#### 2.3 Revoke Delegation

Remove an executive's permission to act for an agent.

```
POST /executive/revoke
Content-Type: application/json

{
  "agentAsset": "agent-asset-public-key",
  "executiveWallet": "executive-wallet-address",
  "ownerWallet": "asset-owner-wallet-address"
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "estimatedFee": 0.001
}
```

---

### Phase 3: Wallet (Agent Economy)

This is the critical phase — the agent wallet (Asset Signer PDA) can hold funds, but spending requires Execute transactions built through the MPL Core program. Without these endpoints, the wallet is a dead drop.

#### 3.1 Agent Wallet Balance

```
GET /wallet/{assetId}/balance
```

**Response (200):**
```json
{
  "assetId": "...",
  "walletPda": "asset-signer-pda-address",
  "sol": 1.523,
  "lamports": 1523000000,
  "tokens": [
    {
      "mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      "symbol": "USDC",
      "amount": 25.50,
      "decimals": 6,
      "rawAmount": "25500000"
    },
    {
      "mint": "So11111111111111111111111111111111111111112",
      "symbol": "WSOL",
      "amount": 0.5,
      "decimals": 9,
      "rawAmount": "500000000"
    }
  ]
}
```

---

#### 3.2 Send SOL from Agent Wallet

Build an Execute transaction that transfers SOL from the Asset Signer PDA to a recipient.

```
POST /wallet/send-sol
Content-Type: application/json

{
  "agentAsset": "agent-asset-public-key",
  "executiveWallet": "executive-wallet-address",
  "to": "recipient-wallet-address",
  "amount": 0.01
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "from": "asset-signer-pda",
  "to": "recipient-wallet-address",
  "amount": 0.01,
  "estimatedFee": 0.000005
}
```

**Client flow:**
1. Agent decides to pay (x402, tip, A2A service fee)
2. Calls API → gets unsigned Execute transaction
3. Executive signs via MWA
4. Broadcast → SOL moves from agent wallet to recipient

---

#### 3.3 Send SPL Token from Agent Wallet

Build an Execute transaction that transfers SPL tokens from the Asset Signer PDA.

```
POST /wallet/send-token
Content-Type: application/json

{
  "agentAsset": "agent-asset-public-key",
  "executiveWallet": "executive-wallet-address",
  "to": "recipient-wallet-address",
  "mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
  "amount": 5.00
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "from": "asset-signer-pda",
  "to": "recipient-wallet-address",
  "mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
  "symbol": "USDC",
  "amount": 5.00,
  "estimatedFee": 0.000005
}
```

---

#### 3.4 Fund Agent Wallet

Build a simple SOL transfer TO the Asset Signer PDA (from the owner's wallet). This is a standard SystemProgram.Transfer — no Execute instruction needed.

```
POST /wallet/fund
Content-Type: application/json

{
  "walletAddress": "owner-wallet-address",
  "agentAsset": "agent-asset-public-key",
  "amount": 0.5
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "from": "owner-wallet-address",
  "to": "asset-signer-pda",
  "amount": 0.5,
  "estimatedFee": 0.000005
}
```

**Note:** SeekerClaw can already do this with `solana_send` by sending to the PDA address directly. This endpoint is a convenience.

---

### Phase 4: Payments (x402 Protocol)

These endpoints enable autonomous machine-to-machine payments following the HTTP 402 payment protocol.

#### 4.1 Build x402 Payment

When an agent receives a `402 Payment Required` response, it needs to construct a payment transaction quickly.

```
POST /wallet/pay
Content-Type: application/json

{
  "agentAsset": "agent-asset-public-key",
  "executiveWallet": "executive-wallet-address",
  "paymentDetails": {
    "to": "service-provider-wallet",
    "amount": 0.001,
    "currency": "SOL",
    "memo": "x402-payment-for-api-call-xyz"
  }
}
```

**Response (200):**
```json
{
  "unsignedTransaction": "<base64>",
  "paymentProof": {
    "type": "solana-transaction",
    "from": "asset-signer-pda",
    "to": "service-provider-wallet",
    "amount": 0.001,
    "currency": "SOL",
    "memo": "x402-payment-for-api-call-xyz"
  },
  "estimatedFee": 0.000005
}
```

**Full x402 flow on SeekerClaw:**

```
Step 1: Agent calls external API
─────────────────────────────────
  web_fetch("https://api.example.com/premium-data")
  → 402 Payment Required
  → Response headers:
      X-Payment-Address: <service-wallet>
      X-Payment-Amount: 0.001
      X-Payment-Currency: SOL

Step 2: Agent builds payment
─────────────────────────────────
  web_fetch("https://api.metaplex.com/v1/agents/wallet/pay", {
    method: "POST",
    body: {
      agentAsset: "...",
      executiveWallet: "...",
      paymentDetails: {
        to: "<service-wallet>",
        amount: 0.001,
        currency: "SOL"
      }
    }
  })
  → Returns unsigned transaction

Step 3: Executive signs
─────────────────────────────────
  androidBridge("/solana/sign", { tx: unsignedTransaction })
  → MWA prompts user (or auto-approves if within spending limit)
  → Returns signature

Step 4: Agent retries with payment proof
─────────────────────────────────
  web_fetch("https://api.example.com/premium-data", {
    headers: {
      "X-Payment-Signature": "<solana-tx-signature>",
      "X-Payment-Agent": "<agent-asset-id>"
    }
  })
  → 200 OK — data returned
```

---

#### 4.2 Payment History

Track payments made from the agent wallet — useful for budgeting, auditing, and spending limits.

```
GET /wallet/{assetId}/payments?page=1&limit=20
```

**Response (200):**
```json
{
  "assetId": "...",
  "walletPda": "...",
  "total": 15,
  "payments": [
    {
      "signature": "tx-signature",
      "to": "service-wallet",
      "amount": 0.001,
      "currency": "SOL",
      "memo": "x402-payment-for-...",
      "timestamp": "2026-03-24T10:30:00Z",
      "status": "confirmed"
    }
  ],
  "totalSpent": {
    "SOL": 0.015,
    "USDC": 5.50
  }
}
```

---

### Phase 5: Agent-to-Agent (A2A)

#### 5.1 Verify Agent

Verify that a wallet address or asset ID belongs to a registered Metaplex agent. Critical for A2A trust.

```
GET /verify/{assetIdOrWallet}
```

**Response (200):**
```json
{
  "verified": true,
  "agentAsset": "...",
  "walletPda": "...",
  "name": "SeekerBot",
  "active": true,
  "services": [
    { "name": "MCP", "endpoint": "...", "version": "2025-06-18" }
  ],
  "supportedTrust": ["reputation"],
  "registeredAt": "2026-03-24T08:00:00Z"
}
```

**Response (404):**
```json
{
  "verified": false,
  "error": "No registered agent found for this address"
}
```

---

#### 5.2 Agent Directory

Browse all active agents, filterable by capabilities.

```
GET /directory?service=MCP&active=true&page=1&limit=50
```

Returns same format as `/search` but optimized for discovery with service-type filtering.

---

## Error Codes

All endpoints return standard HTTP status codes with JSON error bodies:

| Status | Meaning | Example |
|--------|---------|---------|
| 200 | Success | Transaction built, data returned |
| 400 | Bad request | Invalid wallet address, missing required field |
| 404 | Not found | Asset not registered, agent not found |
| 409 | Conflict | Executive profile already exists |
| 422 | Validation error | Insufficient balance for payment |
| 429 | Rate limited | Too many requests |
| 500 | Server error | RPC failure, Arweave upload failed |

**Error body:**
```json
{
  "error": "INSUFFICIENT_BALANCE",
  "message": "Agent wallet has 0.005 SOL but payment requires 0.01 SOL + 0.000005 fee",
  "details": {
    "available": 0.005,
    "required": 0.010005
  }
}
```

---

## SeekerClaw Integration Plan

Once the API exists, SeekerClaw implementation is straightforward:

### New tools (6 total)

| Tool | API Endpoint | User Confirmation |
|------|-------------|-------------------|
| `metaplex_register_agent` | POST /register | YES — costs SOL |
| `metaplex_agent_info` | GET /identity/{id} | No |
| `metaplex_delegate_executive` | POST /executive/delegate | YES — on-chain action |
| `metaplex_agent_balance` | GET /wallet/{id}/balance | No |
| `metaplex_agent_send` | POST /wallet/send-sol, /send-token | YES — spends funds |
| `metaplex_agent_pay` | POST /wallet/pay | Configurable (auto/confirm) |

### Spending controls (SeekerClaw-side)

| Setting | Default | Description |
|---------|---------|-------------|
| Auto-approve threshold | 0.001 SOL | x402 payments below this skip MWA prompt |
| Daily spending limit | 0.1 SOL | Hard cap, agent stops paying after limit |
| Per-payment max | 0.01 SOL | Single payment cap |
| Require confirmation | ON | User approves each payment in Telegram |

Users configure these in Settings > Agent Wallet > Spending Limits.

### Setup flow for users

```
1. User opens SeekerClaw Settings > Agent Identity
2. Taps "Register on Metaplex"
3. Fills in: name, description, avatar
4. MWA prompt: "Register agent for ~0.015 SOL?" → Approve
5. Agent now has on-chain identity + wallet
6. Optional: Fund agent wallet (send SOL to PDA)
7. Optional: Set spending limits for x402
8. Done — agent is live on the Metaplex Agent Registry
```

---

## Why This Matters

### For Metaplex
- **Adoption**: Every SeekerClaw user = a registered agent on Metaplex
- **Mobile-first**: First mobile agent platform on Solana using Agent Passport
- **Ecosystem growth**: Agents with wallets = economic activity on Solana
- **Showcase**: Real-world demonstration of Agent Passport's value (not just SDK demos)

### For SeekerClaw
- **On-chain identity**: Agents become first-class Solana citizens
- **Agent economy**: x402 payments enable premium API access, A2A services
- **Discovery**: Other agents can find SeekerClaw agents via registry
- **Trust**: Verifiable on-chain identity builds user confidence

### For the Solana Ecosystem
- **Agent economy bootstrap**: Thousands of AI agents with wallets, making payments, using services
- **Standard adoption**: ERC-8004 + Metaplex Agent Registry as the default agent identity layer
- **Mobile-native**: Runs on the Solana Seeker phone — the hardware + software + identity stack

---

## API Phasing Suggestion

| Phase | Endpoints | Enables | Priority |
|-------|-----------|---------|----------|
| 1 | Register, Fetch, Search | Agent identity | **HIGH** — foundation |
| 2 | Executive Register, Delegate, Revoke | Delegation control | **HIGH** — needed for wallet ops |
| 3 | Wallet Balance, Send SOL, Send Token, Fund | Agent economy | **CRITICAL** — x402 payments |
| 4 | Pay (x402), Payment History | Autonomous payments | **CRITICAL** — the killer feature |
| 5 | Verify, Directory | Agent discovery, A2A | MEDIUM — ecosystem growth |

Phases 1-2 can ship together (identity + delegation).
Phases 3-4 can ship together (wallet + payments).
Phase 5 can come anytime.

---

## Technical Notes

- All transactions are **versioned transactions** (v0) for future compatibility
- API should set `computeUnits` and `priorityFee` appropriately
- Transactions should have a **5-minute TTL** (recent blockhash expiry)
- API should support both **mainnet** and **devnet** via query param (`?network=devnet`)
- Rate limits: 60 requests/minute per wallet address
- No API key required (wallet signature = authentication)

---

## Contact

**SeekerClaw**: [seekerclaw.xyz](https://seekerclaw.xyz)
**Metaplex Agents Docs**: [metaplex.com/docs/agents](https://www.metaplex.com/docs/agents)
