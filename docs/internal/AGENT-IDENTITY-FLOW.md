# Agent Identity — Settings & Flow

> One-pager covering how SeekerClaw integrates Metaplex Agent Passport.

---

## Three Components

| Component | What | Stored | Survives reinstall? |
|-----------|------|--------|---------------------|
| **Core NFT** | Agent's on-chain identity | On-chain (Solana) | Yes — tied to user's wallet |
| **Asset Signer PDA** | Agent's wallet (no private key) | On-chain (derived from NFT) | Yes — deterministic |
| **Executive Keypair** | SeekerClaw's signing key | Android Keystore | No — re-delegate on new device |

---

## Setup Flow (One-Time, Settings Screen)

```
Settings > Agent Identity > [Register Agent]

Step 1: Create Core NFT                    → MWA approve (~0.003 SOL)
Step 2: Register Agent Identity on NFT     → MWA approve (~0.005 SOL)
Step 3: Generate executive keypair         → local, instant, no MWA
Step 4: Register executive profile         → MWA approve (~0.003 SOL)
Step 5: Delegate execution to executive    → MWA approve (~0.003 SOL)
Step 6: Fund agent wallet (PDA)            → MWA approve (user chooses amount)
Step 7: Fund executive gas                 → MWA approve (0.01 SOL)

Total: ~5 MWA taps + user-chosen funding amount
After this: NO MORE MWA NEEDED for spending.
```

---

## Runtime Flow (Autonomous, No MWA)

```
Agent decides to pay (x402, A2A, etc.)
  → Node.js calls Android Bridge: "execute transfer 0.001 SOL to <address>"
  → Bridge reads executive keypair from Android Keystore
  → Builds Core Execute transaction locally
  → Signs with executive keypair (no MWA, no UI)
  → Broadcasts to Solana
  → PDA wallet sends funds, executive wallet pays gas
  → Done. User not involved.
```

---

## Settings Screen

```
Settings > Agent Identity

  ┌─────────────────────────────────────────┐
  │  Status: ✅ Registered                  │
  │                                         │
  │  Agent:    SeekerBot                    │
  │  Address:  7xKXtg...  [Copy]            │
  │                                         │
  │  Agent Wallet (PDA)                     │
  │  Address:  4pQzR8b...  [Copy]           │
  │  Balance:  0.50 SOL                     │
  │  [Fund Wallet]                          │
  │                                         │
  │  Executive Gas                          │
  │  Balance:  0.008 SOL                    │
  │  [Fund Gas ⛽]                          │
  │                                         │
  │  Spending Limits                        │
  │  Per payment:   0.01 SOL               │
  │  Daily limit:   0.1 SOL                │
  │  Confirm via Telegram: ON              │
  │                                         │
  │  Security                               │
  │  Key Rotation:  Every 7 days           │
  │  Last Rotated:  2 days ago             │
  │  [🔄 Rotate Now]                       │
  │                                         │
  │  [🚫 Revoke Delegation]                │
  └─────────────────────────────────────────┘
```

---

## What Needs MWA vs What Doesn't

| Action | MWA? | When |
|--------|------|------|
| Register agent | Yes | Setup (once) |
| Delegate executive | Yes | Setup (once) |
| Fund wallet | Yes | User-initiated |
| Fund gas | Yes | User-initiated |
| Rotate key | Yes | Periodic / manual |
| Revoke delegation | Yes | Emergency / manual |
| **Agent spends from PDA** | **No** | **Autonomous, 24/7** |
| **Agent pays x402** | **No** | **Autonomous, 24/7** |
| **Agent sends SOL/tokens** | **No** | **Autonomous, 24/7** |

---

## Security Model

### What's at risk if executive keypair is compromised

| Asset | At Risk? |
|-------|----------|
| PDA wallet balance | **YES** — attacker can drain it |
| User's main wallet | No — executive has no access |
| Core NFT (identity) | No — executive can't transfer it |
| Reputation / history | No — on-chain, tied to NFT |

### Defense layers

| Layer | Description |
|-------|-------------|
| Small PDA balance | "Prepaid card" — only fund what you need |
| App-side limits | Per-payment cap, daily limit, enforced before signing |
| Telegram confirmation | Optional: agent asks before paying |
| Key rotation | Proactive: rotate weekly, old key becomes useless |
| Kill switch | Instant revoke in Settings |
| Android Keystore | Hardware-backed storage on Seeker |
| Prompt injection defense | Existing security.js — content trust, injection detection |

### User framing

> "Your agent wallet is a prepaid card. Load what you need. If anything goes wrong, you lose the balance — not your main wallet. Tap Revoke to cut off access instantly."

---

## Device Change / Reinstall

Agent identity and wallet survive. Only executive keypair is lost.

```
New phone:
  1. Install SeekerClaw
  2. Connect same Phantom wallet
  3. Agent identity auto-detected (on-chain, owned by wallet)
  4. Generate NEW executive keypair
  5. Delegate to new executive (one MWA tap)
  6. Fund gas (one MWA tap)
  7. Back in business
```

PDA balance, identity, reputation — all intact. Just a new executor.

---

## Architecture Separation

```
SETTINGS (Kotlin/Android)          AGENT (Node.js)
  │                                  │
  │ Identity management              │ Just spending:
  │ Key generation                   │   metaplex_agent_pay()
  │ Key rotation                     │   metaplex_agent_send()
  │ Funding (MWA)                    │   metaplex_agent_balance()
  │ Spending limits                  │
  │ Revoke / kill switch             │ Knows nothing about:
  │                                  │   keypairs, MWA, delegation,
  │ All MWA happens here.            │   rotation, or identity setup.
  │ All key management here.         │
  │                                  │ Calls Bridge → Bridge signs →
  │                                  │ Broadcasts → Done.
```

---

## On-Chain Accounts Created

| Account | Size | Cost | Created during |
|---------|------|------|---------------|
| Core NFT (agent) | ~200 bytes | ~0.003 SOL | Setup step 1 |
| AgentIdentityV1 PDA | 40 bytes | ~0.005 SOL | Setup step 2 |
| ExecutiveProfileV1 PDA | 40 bytes | ~0.003 SOL | Setup step 4 |
| ExecutionDelegateRecordV1 PDA | 104 bytes | ~0.003 SOL | Setup step 5 |
| Asset Signer PDA (wallet) | 0 bytes | Free | Auto-derived |

Total setup cost: **~0.015 SOL** + funding amount

---

## Programs Involved

```
Agent Identity:  1DREGFgysWYxLnRnKQnwrxnJQeSMk2HmGaC6whw2B2p
Agent Tools:     TLREGni9ZEyGC3vnPZtqUh95xQ8oPqJSvNjvB7FGK8S
MPL Core:        CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d
```
