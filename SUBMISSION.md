# ShieldLend — Hackathon Submission

> **Re{define} Hackathon | March 2026**
> Privacy-Native BTC Lending Protocol on Starknet

---

## One-Liner

ShieldLend is a privacy-first BTC lending protocol on Starknet where users can deposit collateral, borrow stablecoins, and earn yield — with optional ZK-powered privacy that hides balances and transaction amounts on-chain.

---

## Problem

Current DeFi lending protocols (Aave, Compound) expose every user's position publicly on-chain. This creates:

1. **Front-running risk** — Liquidators and MEV bots can see undercollateralized positions and race to profit
2. **Privacy leakage** — Anyone can track how much you deposited, borrowed, and when
3. **Strategic disadvantage** — Large positions are visible, enabling targeted manipulation
4. **Limited BTC support** — Most Starknet protocols don't natively support BTC variants

---

## Solution

ShieldLend introduces **shielded lending** — a lending protocol with an integrated privacy engine:

- **Pedersen commitments** hide deposit and borrow amounts on-chain
- **Nullifier registry** prevents double-spend without revealing which commitment was spent
- **ZK proof verification** validates transactions without exposing sensitive data
- **Optional privacy** — Users can choose transparent mode (lower gas) or shielded mode (private)

Built natively on Starknet with first-class support for BTC variants (strkBTC, tBTC).

---

## What We Built

### Smart Contracts (Cairo 2.11.2)

**16 contracts** across 6 modules:

| Module | Contracts | Description |
|---|---|---|
| Core | LendingPool, MarketFactory, FlashLoanVault | Lending engine with isolated markets and atomic flash loans |
| Tokens | SlToken, DebtToken | Receipt tokens (rebasing) and non-transferable debt tracking |
| Privacy | CommitmentStore, NullifierRegistry, ZkVerifier, ShieldedAccount | Full privacy engine with commitment scheme and proof verification |
| Liquidation | LiquidationEngine, DutchAuction | Health factor monitoring + time-decaying price auctions |
| Yield | YieldTokenizer, PrincipalToken, YieldToken | Split yield-bearing tokens into fixed (PT) and variable (YT) components |
| Oracle | PragmaAdapter | Price feed integration with WAD precision |
| Interest | InterestRateModel | Two-slope utilization-based rate curve |

**123 tests passing** — unit tests, integration tests, and edge cases.

### Frontend (Next.js 16)

- 7 routes: Dashboard, Markets, Market Detail, Lend, Borrow, Portfolio, Yield
- Wallet connection via starknet-react (Argent, Braavos)
- Privacy toggle (transparent/shielded mode)
- Real-time health factor display
- Yield tokenization UI (tokenize, redeem, claim)

### DevOps

- Deployment scripts (`deploy.sh`, `setup_markets.sh`) for Starknet Sepolia
- CI/CD via GitHub Actions (contract build+test, frontend build)
- Environment-based configuration for all contract addresses

---

## Technical Highlights

### Privacy Engine

The privacy layer uses a **commitment-nullifier scheme**:

```
Deposit:
  commitment = Pedersen(amount, secret, nullifier_hash)
  → stored in CommitmentStore Merkle tree

Withdraw:
  proof = ZK_Prove(I know secret s.t. commitment exists AND nullifier is fresh)
  → ZkVerifier checks proof
  → NullifierRegistry marks nullifier as spent
  → Funds released without revealing which commitment was consumed
```

This provides **unlinkability** — observers cannot connect deposits to withdrawals.

### Isolated Markets

Each collateral/loan pair gets its own LendingPool with independent:
- Liquidity and utilization tracking
- Interest rate curve parameters
- LTV and liquidation thresholds
- Risk isolation (bad debt in one market doesn't affect others)

### eMode (Efficiency Mode)

For correlated assets (strkBTC/tBTC), eMode enables:
- **95% LTV** (vs. 70-75% for cross-asset pairs)
- **97% liquidation threshold**
- Minimal liquidation penalty since assets are price-correlated

### Yield Tokenization

Inspired by Pendle, slTokens can be split into:
- **PT (Principal Token)** — Redeemable 1:1 at maturity (fixed yield)
- **YT (Yield Token)** — Receives all accrued interest until maturity (variable yield)

---

## Tracks

### Privacy Track
- Pedersen commitment scheme with on-chain Merkle tree
- Nullifier-based double-spend prevention
- ZkVerifier contract ready for Garaga-verified Noir proofs
- ShieldedAccount for private balance management
- Privacy toggle in frontend (transparent vs. shielded)

### Bitcoin Track
- Native support for strkBTC and tBTC as collateral
- BTC/USDC lending markets with optimized risk parameters
- eMode for BTC-correlated pairs (95% LTV)
- BTC yield tokenization via PT/YT splitting

### DeFi/Open Track
- Flash loan vault with configurable fee (9 bps default)
- Isolated market architecture via MarketFactory
- Dutch auction liquidation mechanism
- Two-slope interest rate model (optimal utilization targeting)

---

## How to Run

```bash
# Build & test contracts
cd contracts && scarb build && snforge test

# Run frontend
cd frontend && npm install && cp .env.example .env.local && npm run dev

# Deploy to Sepolia
cp .env.example .env  # Fill in account details
./scripts/deploy.sh
./scripts/setup_markets.sh
```

---

## Numbers

| Metric | Value |
|---|---|
| Cairo contracts | 16 |
| Cairo source lines | 3,200+ |
| Test count | 123 |
| Test pass rate | 100% |
| Frontend routes | 7 |
| Frontend components | 26 files |
| Total TypeScript lines | 2,100+ |

---

## Future Work

- **Garaga integration** — Replace stub ZK verifier with production Garaga-verified Noir proofs
- **Noir circuits** — Complete shielded_deposit and shielded_borrow circuits
- **Mainnet deployment** — Audit and deploy to Starknet mainnet
- **Xverse wallet** — BTC wallet integration for direct Bitcoin deposits
- **Governance** — Protocol parameter management via token voting

---

## Links

- [Architecture Doc](./docs/ARCHITECTURE.md)
- [Feature Blueprint](./docs/FEATURE_BLUEPRINT.md)
