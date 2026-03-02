# ShieldLend — Workplan

> Privacy-Native BTC Lending Protocol on Starknet
> Re{define} Hackathon | March 2026

---

## Current State

- **architecture.md** — Full technical spec (contracts, circuits, frontend, flows) ✅
- **Reference files at root** — Formula/scaffold files (`*.cairo`, `*.nr`, `*.toml`, `package.json`, `shieldlend_feature_blueprint.md`) for reference only
- **contracts/** — Empty (nothing built)
- **frontend/** — Empty (nothing built)
- **circuits/** — Does not exist yet
- **No git repo initialized**

### Reference Files (delete after integration)

These root-level files contain formulas and patterns to incorporate into the actual project structure:

| File | Contains | Move To |
|---|---|---|
| `math.cairo` | WAD/RAY fixed-point math, health factor, compound interest | `contracts/src/utils/math.cairo` |
| `constants.cairo` | Protocol constants (rates, fees, limits) | `contracts/src/utils/constants.cairo` |
| `errors.cairo` | Custom error codes | `contracts/src/utils/errors.cairo` |
| `lib.cairo` | Module root declarations | `contracts/src/lib.cairo` |
| `rate_model.cairo` | Two-slope interest rate model | `contracts/src/interest/rate_model.cairo` |
| `commitment_store.cairo` | Merkle tree commitment storage | `contracts/src/privacy/commitment_store.cairo` |
| `nullifier_registry.cairo` | Double-spend prevention | `contracts/src/privacy/nullifier_registry.cairo` |
| `shielded_deposit.nr` | Noir deposit proof circuit | `circuits/src/shielded_deposit.nr` |
| `shielded_borrow.nr` | Noir borrow proof circuit | `circuits/src/shielded_borrow.nr` |
| `Scarb.toml` | Cairo package manifest | `contracts/Scarb.toml` |
| `Nargo.toml` | Noir package manifest | `circuits/Nargo.toml` |
| `package.json` | Frontend dependencies | `frontend/package.json` |

---

## Phase 1: Project Scaffolding & Setup

**Goal:** Initialize the project structure, git repo, and move reference files into place.

### Tasks

- [ ] 1.1 Initialize git repository
- [ ] 1.2 Create full directory structure per architecture.md
  ```
  contracts/src/{core,privacy,interest,liquidation,yield,tokens,oracle,utils}/
  contracts/tests/
  circuits/src/utils/
  frontend/app/{markets/[marketId],lend,borrow,portfolio,yield}/
  frontend/components/{layout,markets,lending,privacy,yield,shared}/
  frontend/hooks/
  frontend/lib/privacy/
  frontend/public/circuits/
  scripts/
  docs/
  .github/workflows/
  ```
- [ ] 1.3 Move reference Cairo files into `contracts/src/` (utils, interest, privacy)
- [ ] 1.4 Move `Scarb.toml` into `contracts/`, verify `scarb build` works
- [ ] 1.5 Move Noir circuit files into `circuits/src/`, move `Nargo.toml` into `circuits/`
- [ ] 1.6 Move `package.json` into `frontend/`, initialize Next.js project
- [ ] 1.7 Create `.gitignore` (target/, node_modules/, .env.local, etc.)
- [ ] 1.8 Move `ARCHITECTURE.md` and `shieldlend_feature_blueprint.md` into `docs/`
- [ ] 1.9 Delete original reference files from root after copying
- [ ] 1.10 First commit — project scaffolding

### Deliverables
- Working `scarb build` in contracts/
- Working `nargo compile` in circuits/
- Working `npm install` in frontend/
- Clean git repo with proper structure

---

## Phase 2: Core Smart Contracts — Transparent Mode

**Goal:** Build the foundational lending protocol with transparent (non-private) operations first. This gives us a working DeFi protocol before adding privacy.

### Tasks

#### 2A: Utility & Token Contracts
- [ ] 2.1 Finalize `contracts/src/utils/math.cairo` — confirm all math functions compile
- [ ] 2.2 Finalize `contracts/src/utils/errors.cairo` — add any missing error codes
- [ ] 2.3 Finalize `contracts/src/utils/constants.cairo` — validate all constants
- [ ] 2.4 Implement `contracts/src/tokens/sl_token.cairo` — ERC20 interest-bearing receipt token (like Aave's aToken)
  - Mint on deposit, burn on withdraw
  - Balance scales with supply index
  - Uses OpenZeppelin ERC20 component
- [ ] 2.5 Implement `contracts/src/tokens/debt_token.cairo` — non-transferable debt tracking token
  - Mint on borrow, burn on repay
  - Balance scales with borrow index
  - Transfer/approve disabled

#### 2B: Interest Rate Model
- [ ] 2.6 Finalize `contracts/src/interest/rate_model.cairo` — already drafted, verify logic
- [ ] 2.7 Implement `contracts/src/interest/rate_accumulator.cairo`
  - Track `borrow_index` and `supply_index` over time
  - `accrue_interest()` — update indices based on elapsed time and current rates
  - Compound interest formula using `math.cairo` helpers

#### 2C: Oracle Integration
- [ ] 2.8 Implement `contracts/src/oracle/pragma_adapter.cairo`
  - Wrap Pragma oracle interface
  - `get_price(asset)` → returns price in USD with precision
  - Handle staleness checks and price validation

#### 2D: Core Lending Logic (Transparent)
- [ ] 2.9 Implement `contracts/src/core/position_manager.cairo`
  - Store transparent positions (deposited, borrowed, last_index)
  - Calculate user's actual debt with accrued interest
  - Health factor computation
- [ ] 2.10 Implement `contracts/src/core/lending_pool.cairo` — transparent mode only first
  - `deposit(amount)` → transfer tokens in, mint slTokens
  - `withdraw(sl_token_amount)` → burn slTokens, transfer tokens out
  - `borrow(amount)` → health check, mint debtTokens, transfer loan tokens
  - `repay(amount)` → burn debtTokens, transfer loan tokens back
  - Interest accrual on every interaction
  - `get_market_data()` and `get_position()` view functions
- [ ] 2.11 Implement `contracts/src/core/market_factory.cairo`
  - `create_market()` — deploy new LendingPool with parameters
  - Store market registry (ID → pool address)
  - `get_markets()` and `get_market()` views

#### 2E: Unit Tests (Transparent)
- [ ] 2.12 Write `contracts/tests/test_lending_pool.cairo`
  - Test deposit/withdraw/borrow/repay flows
  - Test interest accrual
  - Test health factor and collateral checks
  - Test edge cases (zero amounts, insufficient liquidity, etc.)
- [ ] 2.13 Run `snforge test` — all transparent mode tests pass

### Deliverables
- Complete transparent lending protocol (deposit, borrow, repay, withdraw)
- Interest rate model with two-slope curve
- Oracle price feed integration
- slToken and debtToken ERC20s
- Market factory for creating isolated markets
- Passing unit tests

---

## Phase 3: Privacy Layer

**Goal:** Add the ZK privacy primitives and shielded operations to the lending pool.

### Tasks

#### 3A: Privacy Primitives (Cairo)
- [ ] 3.1 Finalize `contracts/src/privacy/commitment_store.cairo` — already drafted, verify and test
- [ ] 3.2 Finalize `contracts/src/privacy/nullifier_registry.cairo` — already drafted, verify and test
- [ ] 3.3 Implement `contracts/src/privacy/shielded_account.cairo`
  - Manage encrypted balances per user
  - Store `ShieldedNote` structs (commitment, encrypted_amount, note_type)
  - ElGamal encrypted value storage
- [ ] 3.4 Implement `contracts/src/privacy/zk_verifier.cairo`
  - Garaga proof verification wrapper
  - `verify_proof(proof, public_inputs)` → bool
  - Support multiple circuit types (deposit, borrow, withdraw, solvency)

#### 3B: Noir ZK Circuits
- [ ] 3.5 Finalize `circuits/src/shielded_deposit.nr` — already drafted, run `nargo test`
- [ ] 3.6 Finalize `circuits/src/shielded_borrow.nr` — already drafted, run `nargo test`
- [ ] 3.7 Implement `circuits/src/shielded_withdraw.nr`
  - Prove ownership of deposit commitment
  - Prove nullifier derivation
  - Prove withdrawal amount <= deposited amount
  - Output change commitment for remaining balance
- [ ] 3.8 Implement `circuits/src/solvency_proof.nr`
  - Prove health factor > threshold without revealing amounts
  - Used for ongoing position health verification
- [ ] 3.9 Implement `circuits/src/flash_loan_proof.nr`
  - Prove flash loan amount matches commitment
  - Prove repayment covers loan + fee
- [ ] 3.10 Implement `circuits/src/utils/pedersen.nr` — Pedersen commitment helpers
- [ ] 3.11 Implement `circuits/src/utils/merkle.nr` — shared Merkle tree verification
- [ ] 3.12 Implement `circuits/src/utils/range_proof.nr` — reusable range proofs
- [ ] 3.13 Compile all circuits: `nargo compile`, verify proof artifacts generated

#### 3C: Shielded Lending Pool Integration
- [ ] 3.14 Extend `lending_pool.cairo` with shielded functions:
  - `shielded_deposit(commitment, encrypted_amount, proof)`
  - `shielded_borrow(borrow_commitment, collateral_nullifier, encrypted_borrow_amount, proof)`
  - `shielded_withdraw(nullifier, new_commitment, proof)`
  - `shielded_repay(debt_nullifier, new_debt_commitment, proof)`
  - `verify_solvency(proof)` view
- [ ] 3.15 Wire up ZK verifier calls within shielded functions
- [ ] 3.16 Wire up commitment store insertions and nullifier checks

#### 3D: Privacy Tests
- [ ] 3.17 Write `contracts/tests/test_privacy.cairo`
  - Test commitment insertion and Merkle root updates
  - Test nullifier spending and double-spend prevention
  - Test shielded deposit/borrow/withdraw/repay with mock proofs
- [ ] 3.18 Run `nargo test` — all circuit tests pass
- [ ] 3.19 Run `snforge test` — all privacy integration tests pass

### Deliverables
- Working Pedersen commitment Merkle tree
- Nullifier registry with double-spend prevention
- ZK proof verification on-chain via Garaga
- 5 Noir circuits (deposit, borrow, withdraw, solvency, flash loan)
- Shielded lending operations integrated into LendingPool
- Passing tests for all privacy components

---

## Phase 4: Advanced Features

**Goal:** Implement flash loans, liquidation, and yield tokenization.

### Tasks

#### 4A: Flash Loans
- [ ] 4.1 Implement `contracts/src/core/flash_loan_vault.cairo`
  - `flash_loan(receiver, token, amount, params)` — transparent flash loan
  - `shielded_flash_loan(receiver, token, amount_commitment, proof, params)` — private flash loan
  - `IFlashLoanReceiver` callback pattern
  - Fee calculation (0.09% default)
  - Verify balance restored after callback
- [ ] 4.2 Write `contracts/tests/test_flash_loan.cairo`

#### 4B: Liquidation Engine
- [ ] 4.3 Implement `contracts/src/liquidation/liquidation_engine.cairo`
  - Soft liquidation: gradual collateral-to-loan conversion as price drops
  - Hard liquidation: traditional forced sale at penalty
  - Health factor check before allowing liquidation
  - Liquidation bonus distribution
- [ ] 4.4 Implement `contracts/src/liquidation/auction.cairo`
  - Dutch auction for liquidated collateral
  - Decreasing price over time to find market-clearing price
- [ ] 4.5 Write `contracts/tests/test_liquidation.cairo`

#### 4C: Yield Tokenization
- [ ] 4.6 Implement `contracts/src/yield/principal_token.cairo` — ERC20 for principal component
- [ ] 4.7 Implement `contracts/src/yield/yield_token.cairo` — ERC20 for yield component
- [ ] 4.8 Implement `contracts/src/yield/yield_tokenizer.cairo`
  - `tokenize(sl_amount, maturity)` → mint PT + YT
  - `redeem(pt_amount, yt_amount)` → burn PT + YT, return slTokens
  - `redeem_pt(pt_amount)` — at maturity, redeem principal only
  - `claim_yield()` — collect accrued yield from YT
  - `shielded_tokenize()` — private PT/YT minting
  - Yield index tracking per maturity
- [ ] 4.9 Write `contracts/tests/test_yield_tokenizer.cairo`

#### 4D: eMode
- [ ] 4.10 Add eMode support to LendingPool and MarketFactory
  - Detect correlated asset pairs (BTC variants)
  - Apply EMODE_LTV_BPS (95%) and reduced liquidation penalties
  - Flag `is_emode` on MarketInfo

### Deliverables
- Transparent + shielded flash loans
- Soft + hard liquidation with Dutch auction
- Yield tokenization (PT/YT split)
- eMode for correlated BTC pairs
- Tests for all advanced features

---

## Phase 5: Frontend Development

**Goal:** Build the Next.js frontend with wallet connection, market views, and privacy-preserving proof generation.

### Tasks

#### 5A: Project Setup & Layout
- [ ] 5.1 Initialize Next.js 16 (App Router + Turbopack) in `frontend/`
  - `npx create-next-app@latest` or manual setup
  - React 19.2, TypeScript 5.7+, Node.js 20.9+
  - Tailwind CSS v4 (no PostCSS config needed — built-in)
  - `next.config.ts` (TypeScript config, not .js)
  - Enable `reactCompiler: true` for automatic memoization
  - Enable `cacheComponents: true` for Cache Components + PPR
- [ ] 5.2 Implement `frontend/app/layout.tsx` — root layout with providers
  - StarknetConfig (Argent, Braavos connectors)
  - PrivacyProvider (client-side key management)
  - MarketDataProvider (cached market state)
  - All `params`/`searchParams` must be async (`await params`)
- [ ] 5.3 Implement `frontend/proxy.ts` — request interception (replaces middleware.ts)
  - Network-level routing for protected routes
- [ ] 5.4 Implement layout components:
  - `Header.tsx` — logo, nav, wallet status
  - `Sidebar.tsx` — navigation links
  - `WalletConnect.tsx` — Argent/Braavos wallet connection

#### 5B: Contract Integration Layer
- [ ] 5.5 Create `frontend/lib/contracts.ts` — ABIs, addresses, contract instances
- [ ] 5.6 Create `frontend/lib/constants.ts` — network config, token addresses
- [ ] 5.7 Create `frontend/lib/math.ts` — client-side interest/health calculations
- [ ] 5.8 Implement core hooks:
  - `useMarkets.ts` — fetch market list and data from MarketFactory
  - `usePositions.ts` — fetch user positions from LendingPool
  - `useShieldLend.ts` — deposit, borrow, repay, withdraw interactions
  - `usePriceFeeds.ts` — oracle price data

#### 5C: Privacy Client Layer
- [ ] 5.9 Implement `frontend/lib/privacy/commitments.ts` — Pedersen commitment generation
- [ ] 5.10 Implement `frontend/lib/privacy/encryption.ts` — ElGamal encrypt/decrypt
- [ ] 5.11 Implement `frontend/lib/privacy/proofWorker.ts` — Web Worker for ZK proof generation
- [ ] 5.12 Implement `frontend/lib/privacy/noir-circuits.ts` — load and execute Noir circuits
- [ ] 5.13 Implement `useProofGeneration.ts` hook — orchestrate client-side proof generation
- [ ] 5.14 Copy compiled circuit artifacts to `frontend/public/circuits/`

#### 5D: Market Pages
- [ ] 5.15 Implement `frontend/app/page.tsx` — landing dashboard
  - Protocol TVL, active markets, top rates
  - Use `"use cache"` directive for static market aggregates
- [ ] 5.16 Implement `frontend/app/markets/page.tsx` — market list
  - MarketTable component with sortable columns
  - MarketCard for mobile view
- [ ] 5.17 Implement `frontend/app/markets/[marketId]/page.tsx` — individual market
  - Async `params`: `{ params }: { params: Promise<{ marketId: string }> }`
  - Market stats (TVL, utilization, rates)
  - Interest rate curve chart (Recharts)
  - Deposit/borrow actions

#### 5E: Lending Interface
- [ ] 5.18 Implement `frontend/app/lend/page.tsx` + DepositForm + WithdrawForm
- [ ] 5.19 Implement `frontend/app/borrow/page.tsx` + BorrowForm + RepayForm
- [ ] 5.20 Implement shared components:
  - `AmountInput.tsx` — token amount input with max button
  - `TokenSelector.tsx` — select collateral/loan token
  - `TxButton.tsx` — transaction submit with loading state
  - `HealthFactor.tsx` — visual health factor indicator

#### 5F: Privacy UI
- [ ] 5.21 Implement `ShieldToggle.tsx` — toggle between transparent and shielded mode
- [ ] 5.22 Implement `ProofGenerator.tsx` — progress UI for client-side ZK proof generation
- [ ] 5.23 Implement `PrivacyBadge.tsx` — visual indicator of privacy level

#### 5G: Portfolio & Yield Pages
- [ ] 5.24 Implement `frontend/app/portfolio/page.tsx`
  - Show user positions (decrypted client-side for shielded)
  - Health factor per position
  - Total value summary
- [ ] 5.25 Implement `frontend/app/yield/page.tsx` + TokenizeForm + PTYTDisplay
  - Yield tokenization interface
  - PT/YT balance display
  - Claim yield button

#### 5H: Xverse BTC Wallet Integration
- [ ] 5.26 Implement `useXverse.ts` hook — Xverse BTC wallet connection
- [ ] 5.27 Add Xverse connect option to WalletConnect component

### Deliverables
- Full Next.js frontend with all pages
- Wallet connection (Argent, Braavos, Xverse)
- Client-side ZK proof generation in Web Worker
- Market browsing, lending, borrowing, yield tokenization UI
- Privacy toggle and shielded mode support

---

## Phase 6: Integration Testing & QA

**Goal:** End-to-end testing of contracts + frontend on local devnet.

### Tasks

- [ ] 6.1 Set up Starknet devnet for local testing
- [ ] 6.2 Write deployment scripts:
  - `scripts/deploy_contracts.ts` — deploy all contracts programmatically
  - `scripts/setup_markets.ts` — create default test markets (strkBTC/USDC, tBTC/USDC)
  - `scripts/seed_testnet.ts` — faucet tokens for testing
- [ ] 6.3 Integration test: full deposit → borrow → repay → withdraw flow (transparent)
- [ ] 6.4 Integration test: full shielded deposit → borrow → repay → withdraw flow
- [ ] 6.5 Integration test: flash loan execution
- [ ] 6.6 Integration test: liquidation trigger and auction
- [ ] 6.7 Integration test: yield tokenization (tokenize → claim yield → redeem)
- [ ] 6.8 Frontend E2E tests with Playwright
- [ ] 6.9 Fix all bugs found during integration testing
- [ ] 6.10 Gas optimization review for critical contract functions

### Deliverables
- All integration tests passing on devnet
- Deployment scripts working
- E2E frontend tests passing
- Gas report for contract operations

---

## Phase 7: Deployment & Hackathon Submission

**Goal:** Deploy to Starknet Sepolia testnet, polish, and submit.

### Tasks

- [ ] 7.1 Deploy all contracts to Starknet Sepolia
  - `scarb build` → `starkli declare` → `starkli deploy`
  - Create initial markets via factory
- [ ] 7.2 Configure frontend with deployed contract addresses (`.env.local`)
- [ ] 7.3 Deploy frontend to Vercel
- [ ] 7.4 Write `docs/HACKATHON_SUBMISSION.md` — 500-word project description
- [ ] 7.5 Write `docs/PRIVACY_SPEC.md` — privacy model specification
- [ ] 7.6 Write `docs/API.md` — contract interface documentation
- [ ] 7.7 Update `README.md` with final instructions, deployed links
- [ ] 7.8 Record 3-minute demo video
  - Show wallet connection
  - Demonstrate shielded deposit + borrow
  - Show privacy toggle (shielded vs transparent)
  - Show yield tokenization
  - Explain the tech (ZK proofs on Starknet)
- [ ] 7.9 Set up CI/CD (`.github/workflows/test.yml` and `deploy.yml`)
- [ ] 7.10 Final review and submission

### Deliverables
- Live testnet deployment (contracts + frontend)
- Complete documentation
- Demo video
- Hackathon submission package

---

## Phase Summary

| Phase | Description | Key Outcome |
|---|---|---|
| **1** | Project Scaffolding & Setup | Clean repo, directories, toolchain working |
| **2** | Core Contracts — Transparent Mode | Working lending protocol (deposit/borrow/repay/withdraw) |
| **3** | Privacy Layer | ZK circuits, shielded operations, Garaga verification |
| **4** | Advanced Features | Flash loans, liquidation, yield tokenization, eMode |
| **5** | Frontend Development | Full Next.js UI with wallet + privacy + proof generation |
| **6** | Integration Testing & QA | E2E tests passing, bugs fixed, gas optimized |
| **7** | Deployment & Submission | Live on Sepolia, demo video, docs, submitted |

---

## Risk Mitigation

| Risk | Mitigation |
|---|---|
| Garaga integration complexity | Start with mock verifier, swap in Garaga when ready |
| Noir circuit compilation issues | Test circuits independently before on-chain integration |
| Starknet devnet instability | Pin devnet version, have fallback to Sepolia testnet |
| Frontend proof generation slow | Web Worker isolation, loading states, proof caching |
| Scope creep | Phase 4 features (liquidation, yield) can be simplified for hackathon MVP |
| Time pressure | Phase 2 (transparent mode) is the minimum viable product — everything after adds differentiation |

---

## MVP Cutline

If time is tight, the **minimum submission** requires:

1. **Phase 1** — Setup ✅
2. **Phase 2** — Transparent lending (deposit/borrow/repay/withdraw) ✅
3. **Phase 3** — At least shielded deposit + borrow with ZK proofs ✅
4. **Phase 5A-5E** — Basic frontend with market + lending pages ✅
5. **Phase 7.1-7.3** — Testnet deployment ✅

Everything else (flash loans, liquidation, yield tokenization, portfolio page) is bonus that strengthens the submission but isn't required for a working demo.
