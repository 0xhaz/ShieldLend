# ShieldLend — Technical Architecture & Stack

> Private BTC Lending Protocol on Starknet
> Re{define} Hackathon | Feb 2026

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Smart Contract Architecture](#smart-contract-architecture)
5. [Privacy Layer Design](#privacy-layer-design)
6. [Core Data Models](#core-data-models)
7. [Protocol Flows](#protocol-flows)
8. [Frontend Architecture](#frontend-architecture)
9. [Testing Strategy](#testing-strategy)
10. [Deployment](#deployment)
11. [Dependencies & Resources](#dependencies--resources)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FRONTEND (Next.js)                         │
│  starknet-react · starknet.js · Xverse SDK · Argent/Braavos       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ JSON-RPC
┌──────────────────────────────▼──────────────────────────────────────┐
│                      STARKNET NETWORK                              │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   SHIELDLEND CORE                            │   │
│  │                                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │   │
│  │  │  Market       │  │  Lending     │  │  Flash Loan      │   │   │
│  │  │  Factory      │  │  Pool        │  │  Vault           │   │   │
│  │  │              │  │  (per market)│  │                  │   │   │
│  │  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │   │
│  │         │                 │                    │              │   │
│  │  ┌──────▼─────────────────▼────────────────────▼─────────┐   │   │
│  │  │              PRIVACY ENGINE                            │   │   │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌────────────────┐  │   │   │
│  │  │  │ Commitment  │ │ Nullifier   │ │ ZK Verifier    │  │   │   │
│  │  │  │ Store       │ │ Registry    │ │ (Garaga)       │  │   │   │
│  │  │  └─────────────┘ └─────────────┘ └────────────────┘  │   │   │
│  │  └───────────────────────────────────────────────────────┘   │   │
│  │                                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │   │
│  │  │  Yield        │  │  Interest    │  │  Liquidation     │   │   │
│  │  │  Tokenizer    │  │  Rate Model  │  │  Engine          │   │   │
│  │  │  (PT/YT)      │  │              │  │  (Soft + Hard)   │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  EXTERNAL INTEGRATIONS                                      │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │    │
│  │  │ strkBTC  │ │ tBTC     │ │ USDC     │ │ Pragma       │  │    │
│  │  │ (Shield) │ │(Threshld)│ │ (Circle) │ │ Oracle       │  │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

### Smart Contracts

| Layer | Technology | Purpose |
|---|---|---|
| Language | **Cairo 2.x** | Starknet-native smart contract language |
| Framework | **Scarb** (v2.9+) | Cairo package manager and build tool |
| Testing | **Starknet Foundry** (`snforge`) | Unit + integration testing for Cairo |
| ZK Circuits | **Garaga** | Verify Noir/Groth16/PLONK proofs on Starknet |
| ZK DSL | **Noir** (Aztec) | Write privacy circuits, compile to proofs verifiable via Garaga |
| Standards | **OpenZeppelin Cairo** | ERC20, access control, reentrancy guards |
| Oracle | **Pragma** | Price feeds for BTC, ETH, USDC on Starknet |

### Frontend

| Layer | Technology | Purpose |
|---|---|---|
| Framework | **Next.js 16** (App Router) | React SSR framework with Turbopack |
| Starknet SDK | **starknet.js** v6+ | Core Starknet interaction library |
| React Hooks | **starknet-react** | Wallet connection, contract calls, tx state |
| BTC Wallet | **Xverse SDK** | Bitcoin wallet integration (hackathon sponsor) |
| Styling | **Tailwind CSS v4** | Utility-first CSS |
| State | **Zustand** | Lightweight client state management |
| Charts | **Recharts** | Interest rate curves, position visualization |
| ZK Client | **noir_js** + **bb.js** | Client-side proof generation in browser |
| React | **React 19.2** | View Transitions, useEffectEvent, Activity |

### Infrastructure

| Layer | Technology | Purpose |
|---|---|---|
| Node RPC | **Xverse Bitcoin RPC** | BTC chain data (sponsor prize eligible) |
| Starknet RPC | **Blast API** / **Nethermind Juno** | Starknet node access |
| Indexer | **Apibara** | Event streaming and indexing for Starknet |
| IPFS | **Pinata** | Store metadata, proof artifacts |
| CI/CD | **GitHub Actions** | Automated test + deploy pipeline |

---

## Project Structure

```
shieldlend/
│
├── contracts/                     # Cairo smart contracts
│   ├── Scarb.toml                 # Package manifest
│   ├── src/
│   │   ├── lib.cairo              # Module root
│   │   │
│   │   ├── core/
│   │   │   ├── market_factory.cairo      # Deploy new isolated markets
│   │   │   ├── lending_pool.cairo        # Per-market deposit/borrow/repay
│   │   │   ├── flash_loan_vault.cairo    # Shielded flash loan logic
│   │   │   └── position_manager.cairo    # Track user positions (shielded)
│   │   │
│   │   ├── privacy/
│   │   │   ├── commitment_store.cairo    # Pedersen commitment storage
│   │   │   ├── nullifier_registry.cairo  # Prevent double-spend
│   │   │   ├── shielded_account.cairo    # Encrypted balance management
│   │   │   └── zk_verifier.cairo         # Garaga proof verification wrapper
│   │   │
│   │   ├── interest/
│   │   │   ├── rate_model.cairo          # Two-slope utilization-based rates
│   │   │   └── rate_accumulator.cairo    # Compound interest tracking
│   │   │
│   │   ├── liquidation/
│   │   │   ├── liquidation_engine.cairo  # Soft + hard liquidation
│   │   │   └── auction.cairo             # Dutch auction for liquidated collateral
│   │   │
│   │   ├── yield/
│   │   │   ├── yield_tokenizer.cairo     # Split deposits into PT + YT
│   │   │   ├── principal_token.cairo     # ERC20 for principal component
│   │   │   └── yield_token.cairo         # ERC20 for yield component
│   │   │
│   │   ├── tokens/
│   │   │   ├── sl_token.cairo            # Interest-bearing receipt token (like aToken)
│   │   │   └── debt_token.cairo          # Non-transferable debt tracking
│   │   │
│   │   ├── oracle/
│   │   │   └── pragma_adapter.cairo      # Pragma oracle price feed integration
│   │   │
│   │   └── utils/
│   │       ├── math.cairo                # Fixed-point math, WAD/RAY
│   │       ├── errors.cairo              # Custom error codes
│   │       └── constants.cairo           # Protocol parameters
│   │
│   └── tests/
│       ├── test_lending_pool.cairo
│       ├── test_flash_loan.cairo
│       ├── test_privacy.cairo
│       ├── test_liquidation.cairo
│       └── test_yield_tokenizer.cairo
│
├── circuits/                      # Noir ZK circuits
│   ├── Nargo.toml
│   └── src/
│       ├── shielded_deposit.nr           # Prove deposit amount matches commitment
│       ├── shielded_borrow.nr            # Prove collateral > loan (without revealing either)
│       ├── solvency_proof.nr             # Prove position health > threshold
│       ├── shielded_withdraw.nr          # Prove withdrawal is valid
│       ├── flash_loan_proof.nr           # Prove flash loan was repaid
│       └── utils/
│           ├── pedersen.nr               # Pedersen commitment helpers
│           ├── merkle.nr                 # Merkle tree verification
│           └── range_proof.nr            # Range proofs for amounts
│
├── frontend/                      # Next.js 16 application
│   ├── package.json
│   ├── next.config.ts             # TypeScript config (Next.js 16)
│   ├── proxy.ts                   # Replaces middleware.ts (Next.js 16)
│   ├── tsconfig.json
│   │
│   ├── app/
│   │   ├── layout.tsx                    # Root layout + providers
│   │   ├── page.tsx                      # Landing / dashboard
│   │   ├── markets/
│   │   │   ├── page.tsx                  # Market list
│   │   │   └── [marketId]/
│   │   │       └── page.tsx              # Individual market view
│   │   ├── lend/
│   │   │   └── page.tsx                  # Deposit / lend interface
│   │   ├── borrow/
│   │   │   └── page.tsx                  # Borrow interface
│   │   ├── portfolio/
│   │   │   └── page.tsx                  # User positions (decrypted client-side)
│   │   └── yield/
│   │       └── page.tsx                  # PT/YT tokenization & trading
│   │
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Header.tsx
│   │   │   ├── Sidebar.tsx
│   │   │   └── WalletConnect.tsx
│   │   ├── markets/
│   │   │   ├── MarketCard.tsx
│   │   │   ├── MarketTable.tsx
│   │   │   └── CreateMarketModal.tsx
│   │   ├── lending/
│   │   │   ├── DepositForm.tsx
│   │   │   ├── BorrowForm.tsx
│   │   │   ├── RepayForm.tsx
│   │   │   └── WithdrawForm.tsx
│   │   ├── privacy/
│   │   │   ├── ShieldToggle.tsx          # Toggle shielded mode
│   │   │   ├── ProofGenerator.tsx        # Client-side ZK proof UI
│   │   │   └── PrivacyBadge.tsx          # Visual privacy indicator
│   │   ├── yield/
│   │   │   ├── TokenizeForm.tsx
│   │   │   └── PTYTDisplay.tsx
│   │   └── shared/
│   │       ├── AmountInput.tsx
│   │       ├── TokenSelector.tsx
│   │       ├── TxButton.tsx
│   │       └── HealthFactor.tsx
│   │
│   ├── hooks/
│   │   ├── useShieldLend.ts              # Core protocol interactions
│   │   ├── useMarkets.ts                 # Fetch market data
│   │   ├── usePositions.ts              # User position management
│   │   ├── useProofGeneration.ts         # Client-side ZK proof hooks
│   │   ├── usePriceFeeds.ts             # Oracle price data
│   │   └── useXverse.ts                 # Xverse BTC wallet hooks
│   │
│   ├── lib/
│   │   ├── contracts.ts                  # Contract ABIs + addresses
│   │   ├── privacy/
│   │   │   ├── commitments.ts            # Pedersen commitment generation
│   │   │   ├── encryption.ts             # ElGamal encrypt/decrypt balances
│   │   │   ├── proofWorker.ts            # Web Worker for proof generation
│   │   │   └── noir-circuits.ts          # Load & execute Noir circuits
│   │   ├── math.ts                       # Interest calculations, health factor
│   │   └── constants.ts                  # Addresses, ABIs, network config
│   │
│   └── public/
│       └── circuits/                     # Compiled Noir circuit artifacts (.json)
│           ├── shielded_deposit.json
│           ├── shielded_borrow.json
│           └── solvency_proof.json
│
├── scripts/
│   ├── deploy.sh                         # Deployment script
│   ├── deploy_contracts.ts               # Programmatic deployment
│   ├── setup_markets.ts                  # Initialize default markets
│   └── seed_testnet.ts                   # Faucet + test data
│
├── docs/
│   ├── ARCHITECTURE.md                   # This file
│   ├── PRIVACY_SPEC.md                   # Privacy model specification
│   ├── API.md                            # Contract interface docs
│   └── HACKATHON_SUBMISSION.md           # Project description (500 words)
│
├── .github/
│   └── workflows/
│       ├── test.yml                      # CI: run snforge + noir tests
│       └── deploy.yml                    # CD: deploy to testnet
│
└── README.md
```

---

## Smart Contract Architecture

### Module Dependency Graph

```
                    ┌────────────────────┐
                    │   MarketFactory    │
                    │  (entry point)     │
                    └────────┬───────────┘
                             │ creates
                    ┌────────▼───────────┐
                    │   LendingPool      │
                    │  (one per market)  │
                    └────────┬───────────┘
                             │ uses
           ┌─────────────────┼─────────────────────┐
           │                 │                       │
  ┌────────▼──────┐  ┌──────▼────────┐  ┌──────────▼────────┐
  │ PrivacyEngine │  │ InterestRate  │  │ LiquidationEngine │
  │               │  │ Model         │  │                   │
  └───────┬───────┘  └───────────────┘  └───────────────────┘
          │ verifies
  ┌───────▼───────┐
  │ ZK Verifier   │
  │ (Garaga)      │
  └───────────────┘
```

### Contract Interfaces

#### MarketFactory

```cairo
// contracts/src/core/market_factory.cairo

#[starknet::interface]
trait IMarketFactory<TContractState> {
    /// Creates a new isolated lending market
    /// Returns the deployed LendingPool address
    fn create_market(
        ref self: TContractState,
        collateral_token: ContractAddress,    // e.g., strkBTC address
        loan_token: ContractAddress,           // e.g., USDC address
        oracle: ContractAddress,               // Pragma price feed
        ltv_bps: u256,                         // Loan-to-Value in basis points (e.g., 7500 = 75%)
        liquidation_threshold_bps: u256,       // e.g., 8000 = 80%
        liquidation_bonus_bps: u256,           // e.g., 500 = 5%
        interest_rate_model: ContractAddress,   // IRM contract
        privacy_level: PrivacyLevel,           // Full, Partial, or Transparent
    ) -> ContractAddress;

    /// Returns all active markets
    fn get_markets(self: @TContractState) -> Array<MarketInfo>;

    /// Returns specific market info
    fn get_market(self: @TContractState, market_id: u256) -> MarketInfo;
}

#[derive(Drop, Serde, starknet::Store)]
enum PrivacyLevel {
    Full,          // All amounts shielded, ZK proofs required
    Partial,       // Deposit amounts visible, borrow amounts shielded
    Transparent,   // Standard DeFi — no privacy (for compliance-first users)
}

#[derive(Drop, Serde)]
struct MarketInfo {
    market_id: u256,
    pool_address: ContractAddress,
    collateral_token: ContractAddress,
    loan_token: ContractAddress,
    total_deposits: u256,          // Aggregate only (no individual data)
    total_borrows: u256,
    utilization_rate: u256,        // bps
    current_borrow_rate: u256,     // bps per second
    current_supply_rate: u256,
    privacy_level: PrivacyLevel,
    ltv_bps: u256,
    is_emode: bool,                // true if collateral and loan are correlated
}
```

#### LendingPool (per market)

```cairo
// contracts/src/core/lending_pool.cairo

#[starknet::interface]
trait ILendingPool<TContractState> {

    // ═══════════════════════════════════════════
    //  TRANSPARENT MODE (standard DeFi)
    // ═══════════════════════════════════════════

    /// Deposit collateral into the market
    fn deposit(ref self: TContractState, amount: u256) -> u256; // returns slTokens minted

    /// Withdraw collateral
    fn withdraw(ref self: TContractState, sl_token_amount: u256) -> u256;

    /// Borrow loan tokens against deposited collateral
    fn borrow(ref self: TContractState, amount: u256);

    /// Repay borrowed tokens
    fn repay(ref self: TContractState, amount: u256);

    // ═══════════════════════════════════════════
    //  SHIELDED MODE (privacy-preserving)
    // ═══════════════════════════════════════════

    /// Shielded deposit: amount is hidden, commitment stored on-chain
    /// `proof` verifies the deposit amount matches the commitment
    /// `encrypted_amount` is the amount encrypted with user's public key
    fn shielded_deposit(
        ref self: TContractState,
        commitment: felt252,              // Pedersen(amount, blinding_factor)
        encrypted_amount: EncryptedValue, // ElGamal encrypted for user
        proof: ShieldProof,               // ZK proof of valid deposit
    );

    /// Shielded borrow: proves collateral > loan * LTV without revealing either
    fn shielded_borrow(
        ref self: TContractState,
        borrow_commitment: felt252,
        collateral_nullifier: felt252,    // Links to deposit without revealing it
        encrypted_borrow_amount: EncryptedValue,
        proof: ShieldProof,
    );

    /// Shielded withdraw: proves ownership and sufficient balance
    fn shielded_withdraw(
        ref self: TContractState,
        nullifier: felt252,               // Prevents double-withdraw
        new_commitment: felt252,           // Change commitment (remaining balance)
        proof: ShieldProof,
    );

    /// Shielded repay
    fn shielded_repay(
        ref self: TContractState,
        debt_nullifier: felt252,
        new_debt_commitment: felt252,      // Remaining debt (if partial repay)
        proof: ShieldProof,
    );

    // ═══════════════════════════════════════════
    //  VIEWS
    // ═══════════════════════════════════════════

    /// Market-level aggregates (no individual data exposed)
    fn get_market_data(self: @TContractState) -> MarketData;

    /// User's transparent positions (only works in transparent mode)
    fn get_position(self: @TContractState, user: ContractAddress) -> Position;

    /// Verify a solvency proof for a shielded position
    fn verify_solvency(self: @TContractState, proof: ShieldProof) -> bool;
}
```

#### FlashLoanVault

```cairo
// contracts/src/core/flash_loan_vault.cairo

#[starknet::interface]
trait IFlashLoanVault<TContractState> {

    /// Standard flash loan (transparent)
    fn flash_loan(
        ref self: TContractState,
        receiver: ContractAddress,        // Contract that implements IFlashLoanReceiver
        token: ContractAddress,
        amount: u256,
        params: Array<felt252>,           // Arbitrary calldata for receiver
    );

    /// Shielded flash loan: amount and operations are hidden
    /// Only the net result (repaid + fee) is verified
    fn shielded_flash_loan(
        ref self: TContractState,
        receiver: ContractAddress,
        token: ContractAddress,
        amount_commitment: felt252,       // Hidden amount
        proof: ShieldProof,               // Proves repayment will satisfy loan + fee
        params: Array<felt252>,
    );

    fn get_flash_loan_fee_bps(self: @TContractState) -> u256; // e.g., 9 = 0.09%
}

#[starknet::interface]
trait IFlashLoanReceiver<TContractState> {
    /// Called by FlashLoanVault during flash loan execution
    /// Must return the borrowed amount + fee to the vault
    fn execute_operation(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        fee: u256,
        initiator: ContractAddress,
        params: Array<felt252>,
    ) -> bool;
}
```

#### YieldTokenizer

```cairo
// contracts/src/yield/yield_tokenizer.cairo

#[starknet::interface]
trait IYieldTokenizer<TContractState> {

    /// Tokenize a yield-bearing deposit into PT + YT
    /// User deposits slTokens (interest-bearing) and receives PT + YT
    fn tokenize(
        ref self: TContractState,
        sl_token_amount: u256,
        maturity: u64,                    // Unix timestamp
    ) -> (u256, u256);                    // (pt_amount, yt_amount)

    /// Redeem PT + YT back into slTokens (before or at maturity)
    fn redeem(
        ref self: TContractState,
        pt_amount: u256,
        yt_amount: u256,
    ) -> u256;                            // slTokens returned

    /// Redeem PT only (at or after maturity)
    fn redeem_pt(ref self: TContractState, pt_amount: u256) -> u256;

    /// Claim accrued yield from YT holdings
    fn claim_yield(ref self: TContractState) -> u256;

    /// Shielded tokenize: PT + YT amounts are hidden
    fn shielded_tokenize(
        ref self: TContractState,
        sl_token_commitment: felt252,
        maturity: u64,
        proof: ShieldProof,
    ) -> (felt252, felt252);              // (pt_commitment, yt_commitment)

    /// Get yield index for a maturity
    fn get_yield_index(self: @TContractState, maturity: u64) -> u256;
}
```

#### InterestRateModel

```cairo
// contracts/src/interest/rate_model.cairo
// Two-slope model inspired by Aave/Compound

#[starknet::interface]
trait IInterestRateModel<TContractState> {
    /// Calculate current borrow rate based on utilization
    fn get_borrow_rate(
        self: @TContractState,
        total_deposits: u256,
        total_borrows: u256,
    ) -> u256;  // Rate in RAY (1e27) per second

    /// Calculate current supply rate
    fn get_supply_rate(
        self: @TContractState,
        total_deposits: u256,
        total_borrows: u256,
        reserve_factor_bps: u256,
    ) -> u256;
}

// Parameters (set at deployment):
//   base_rate:       Rate at 0% utilization (e.g., 2% APR)
//   slope1:          Rate increase per utilization below optimal (e.g., 4%)
//   slope2:          Rate increase per utilization above optimal (e.g., 75%)
//   optimal_utilization: Kink point (e.g., 80%)
//
// Formula:
//   if utilization <= optimal:
//     borrow_rate = base_rate + (utilization / optimal) * slope1
//   else:
//     borrow_rate = base_rate + slope1 + ((utilization - optimal) / (1 - optimal)) * slope2
```

---

## Privacy Layer Design

### Cryptographic Primitives

```
┌─────────────────────────────────────────────────────────────┐
│                    PRIVACY STACK                             │
│                                                              │
│  Layer 3: APPLICATION LOGIC                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Shielded Deposit · Shielded Borrow · Shielded      │    │
│  │  Withdraw · Shielded Flash Loan · Solvency Proofs   │    │
│  └──────────────────────┬──────────────────────────────┘    │
│                          │                                    │
│  Layer 2: ZK PROOF SYSTEM                                    │
│  ┌──────────────────────▼──────────────────────────────┐    │
│  │  Noir Circuits (compiled to ACIR)                    │    │
│  │  → Barretenberg proving backend (client-side)        │    │
│  │  → Garaga on-chain verification (Starknet)           │    │
│  └──────────────────────┬──────────────────────────────┘    │
│                          │                                    │
│  Layer 1: CRYPTOGRAPHIC PRIMITIVES                           │
│  ┌──────────────────────▼──────────────────────────────┐    │
│  │  Pedersen Commitments · ElGamal Encryption           │    │
│  │  Nullifier Derivation · Merkle Trees                 │    │
│  │  (All native to Starknet's field: Stark252)          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Commitment Scheme

```
DEPOSIT:
  User has: amount (private), blinding_factor (random, private)
  Commitment = Pedersen(amount, blinding_factor)
  On-chain stores: commitment (public), encrypted_amount (public but encrypted)

  commitment ──► Stored in CommitmentStore (Merkle tree leaf)
  encrypted_amount ──► Encrypted with user's public key (only user can decrypt)
```

### Shielded Deposit Flow

```
User (client-side)                           Starknet (on-chain)
─────────────────                            ──────────────────
1. Choose amount (e.g., 1 strkBTC)
2. Generate random blinding_factor
3. Compute commitment = Pedersen(1 BTC, bf)
4. Encrypt amount with own public key
5. Generate Noir proof:
   - Public inputs: commitment, token, pool
   - Private inputs: amount, blinding_factor
   - Proves: commitment == Pedersen(amount, bf)
             AND amount > 0
             AND amount <= user's token balance
6. Submit tx: shielded_deposit(                ──►
     commitment, encrypted_amount, proof)
                                              7. Verify proof via Garaga
                                              8. Transfer tokens from user
                                              9. Store commitment in Merkle tree
                                              10. Emit event (commitment only,
                                                   no amount)
```

### Shielded Borrow Flow

```
User (client-side)                           Starknet (on-chain)
─────────────────                            ──────────────────
1. Knows own collateral (decrypted locally)
2. Choose borrow amount
3. Fetch current oracle price
4. Generate Noir proof:
   - Public inputs: borrow_commitment,
     collateral_nullifier, oracle_price, ltv
   - Private inputs: collateral_amount,
     collateral_blinding, borrow_amount,
     borrow_blinding, merkle_path
   - Proves:
     a) collateral_commitment exists in Merkle tree
     b) collateral_amount * price * ltv >= borrow_amount
     c) borrow_commitment == Pedersen(borrow_amount, bf2)
     d) nullifier is correctly derived
5. Submit tx: shielded_borrow(...)             ──►
                                              6. Verify nullifier not used
                                              7. Verify proof via Garaga
                                              8. Store borrow_commitment
                                              9. Register nullifier
                                              10. Transfer loan tokens to user
```

### Noir Circuit Example: Shielded Borrow

```rust
// circuits/src/shielded_borrow.nr

use dep::std;

// Public inputs (visible on-chain)
struct PublicInputs {
    borrow_commitment: Field,
    collateral_nullifier: Field,
    merkle_root: Field,
    oracle_price: Field,           // BTC/USD price (scaled)
    ltv_bps: Field,                // e.g., 7500
    market_id: Field,
}

// Private inputs (known only to prover)
struct PrivateInputs {
    collateral_amount: Field,
    collateral_blinding: Field,
    borrow_amount: Field,
    borrow_blinding: Field,
    nullifier_secret: Field,
    merkle_path: [Field; 20],      // Depth-20 Merkle tree
    merkle_indices: [u1; 20],
}

fn main(public: PublicInputs, private: PrivateInputs) {

    // 1. Verify collateral commitment exists in tree
    let collateral_commitment = std::hash::pedersen_hash(
        [private.collateral_amount, private.collateral_blinding]
    );
    let computed_root = compute_merkle_root(
        collateral_commitment,
        private.merkle_path,
        private.merkle_indices,
    );
    assert(computed_root == public.merkle_root);

    // 2. Verify nullifier derivation
    let expected_nullifier = std::hash::pedersen_hash(
        [collateral_commitment, private.nullifier_secret]
    );
    assert(expected_nullifier == public.collateral_nullifier);

    // 3. Verify borrow commitment
    let expected_borrow_commitment = std::hash::pedersen_hash(
        [private.borrow_amount, private.borrow_blinding]
    );
    assert(expected_borrow_commitment == public.borrow_commitment);

    // 4. Verify solvency: collateral_value * ltv >= borrow_amount
    // collateral_value = collateral_amount * oracle_price / PRICE_SCALE
    let collateral_value = private.collateral_amount * public.oracle_price;
    let max_borrow = collateral_value * public.ltv_bps / 10000;
    assert(max_borrow as u64 >= private.borrow_amount as u64);

    // 5. Range checks: amounts must be positive
    assert(private.collateral_amount as u64 > 0);
    assert(private.borrow_amount as u64 > 0);
}
```

---

## Core Data Models

### On-Chain Storage

```cairo
// What the contract stores (privacy-preserving)

#[derive(Drop, starknet::Store)]
struct MarketState {
    market_id: u256,
    collateral_token: ContractAddress,
    loan_token: ContractAddress,
    oracle: ContractAddress,

    // Aggregate data (public — needed for interest rate model)
    total_deposits: u256,          // Sum of all deposits (transparent mode)
    total_borrows: u256,           // Sum of all borrows (transparent mode)
    shielded_deposit_count: u256,  // Count only (not amounts)
    shielded_borrow_count: u256,

    // Merkle roots for commitment trees
    deposit_merkle_root: felt252,
    borrow_merkle_root: felt252,

    // Interest state
    borrow_index: u256,            // RAY — accumulates compound interest
    supply_index: u256,
    last_update_timestamp: u64,

    // Risk parameters
    ltv_bps: u256,
    liquidation_threshold_bps: u256,
    liquidation_bonus_bps: u256,
    privacy_level: PrivacyLevel,
    is_active: bool,
}

// Transparent position (only for transparent mode users)
#[derive(Drop, starknet::Store)]
struct Position {
    deposited: u256,               // Collateral deposited
    borrowed: u256,                // Debt outstanding (in borrow index units)
    last_index: u256,              // Index at last interaction
}

// Shielded position (on-chain representation)
// User decrypts encrypted_amount client-side with their private key
#[derive(Drop, starknet::Store)]
struct ShieldedNote {
    commitment: felt252,           // Pedersen(amount, blinding)
    encrypted_amount: EncryptedValue,  // ElGamal(amount, user_pubkey)
    note_type: NoteType,           // Deposit or Borrow
    timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct EncryptedValue {
    c1: felt252,                   // ElGamal component 1
    c2: felt252,                   // ElGamal component 2
}

#[derive(Drop, Serde, starknet::Store)]
enum NoteType {
    Deposit,
    Borrow,
}
```

### Client-Side State (Frontend)

```typescript
// frontend/lib/types.ts

interface UserPosition {
  marketId: string;
  // Decrypted client-side from on-chain encrypted values
  collateralAmount: bigint;
  borrowAmount: bigint;
  healthFactor: number;
  // For proof generation
  blindingFactor: bigint;
  nullifierSecret: bigint;
  merklePath: string[];
  merkleIndices: number[];
}

interface Market {
  marketId: string;
  collateralToken: TokenInfo;
  loanToken: TokenInfo;
  totalDeposits: bigint;
  totalBorrows: bigint;
  utilizationRate: number;
  supplyAPY: number;
  borrowAPY: number;
  ltv: number;
  liquidationThreshold: number;
  privacyLevel: 'full' | 'partial' | 'transparent';
  isEMode: boolean;
}

interface ShieldedNote {
  commitment: string;
  encryptedAmount: { c1: string; c2: string };
  // Decrypted locally:
  amount?: bigint;
  blindingFactor?: bigint;
}
```

---

## Protocol Flows

### Flow 1: Create Market

```
Admin/Governance
      │
      ▼
MarketFactory.create_market(
  collateral: strkBTC,
  loan: USDC,
  oracle: Pragma BTC/USD,
  ltv: 7500,                    // 75%
  liq_threshold: 8000,          // 80%
  liq_bonus: 500,               // 5%
  irm: TwoSlopeModel,
  privacy: Full
)
      │
      ▼
Deploys new LendingPool contract
      │
      ▼
Returns pool address → registered in factory
```

### Flow 2: Shielded Deposit → Borrow → Repay → Withdraw

```
 ┌─── DEPOSIT ──────────────────────────────────────────────────┐
 │ User approves strkBTC transfer to LendingPool                │
 │ User generates commitment + proof (client-side, ~2-5s)       │
 │ User calls shielded_deposit(commitment, enc_amount, proof)   │
 │ Pool verifies proof, stores commitment, transfers tokens     │
 └──────────────────────────────────────┬───────────────────────┘
                                        │
 ┌─── BORROW ───────────────────────────▼───────────────────────┐
 │ User generates solvency proof (client-side)                  │
 │ Proves: my_collateral * price * LTV >= borrow_amount         │
 │ User calls shielded_borrow(borrow_commitment, nullifier, ...) │
 │ Pool verifies proof, sends USDC to user                      │
 └──────────────────────────────────────┬───────────────────────┘
                                        │
 ┌─── REPAY ────────────────────────────▼───────────────────────┐
 │ User approves USDC transfer to LendingPool                   │
 │ User generates repayment proof                               │
 │ Proves: repay_amount reduces debt correctly                  │
 │ User calls shielded_repay(debt_nullifier, new_commitment...) │
 │ Pool verifies, updates debt Merkle tree                      │
 └──────────────────────────────────────┬───────────────────────┘
                                        │
 ┌─── WITHDRAW ─────────────────────────▼───────────────────────┐
 │ User generates withdrawal proof                              │
 │ Proves: owns deposit, no outstanding debt (or healthy)       │
 │ User calls shielded_withdraw(nullifier, change_commitment..) │
 │ Pool verifies, sends collateral back, nullifies old note     │
 └──────────────────────────────────────────────────────────────┘
```

### Flow 3: Shielded Flash Loan

```
 Borrower Contract                ShieldLend FlashLoanVault
       │                                    │
       │  shielded_flash_loan(              │
       │    receiver, token,                │
       │    amount_commitment, proof)       │
       │ ──────────────────────────────────►│
       │                                    │ Verify proof
       │                                    │ Transfer tokens to receiver
       │◄──────────────────────────────────│
       │  execute_operation(                │
       │    token, amount, fee, params)     │
       │                                    │
       │  ... arbitrage, liquidation, etc   │
       │  ... (all hidden from observers)   │
       │                                    │
       │  Transfer amount + fee back ──────►│
       │                                    │ Verify balance restored
       │                                    │ Verify fee paid
       │                                    │ ✓ Transaction succeeds
```

### Flow 4: Yield Tokenization

```
 User holds slTokens (from deposit)
       │
       ▼
 YieldTokenizer.tokenize(sl_amount, maturity)
       │
       ├──► Mint PT-strkBTC (principal claim, redeemable at maturity)
       │
       └──► Mint YT-strkBTC (yield claim, receives interest until maturity)
       
 User can now:
   • Use PT as collateral in another market (capital efficiency)
   • Sell YT to lock in fixed yield
   • Hold YT to collect variable yield
   • Trade PT/YT on any Starknet DEX (Ekubo, AVNU)
```

---

## Frontend Architecture

### Provider Stack

```tsx
// frontend/app/layout.tsx
// Next.js 16 — React 19.2, Turbopack default, async params

import { StarknetConfig, publicProvider } from '@starknet-react/core';
import { sepolia, mainnet } from '@starknet-react/chains';
import { InjectedConnector } from 'starknetkit/injectedConnector';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const connectors = [
    new InjectedConnector({ options: { id: 'argentX' }}),
    new InjectedConnector({ options: { id: 'braavos' }}),
  ];

  return (
    <html lang="en">
      <body>
        <StarknetConfig
          chains={[sepolia, mainnet]}
          provider={publicProvider()}
          connectors={connectors}
        >
          <PrivacyProvider>        {/* Client-side key management */}
            <MarketDataProvider>   {/* Cached market state */}
              {children}
            </MarketDataProvider>
          </PrivacyProvider>
        </StarknetConfig>
      </body>
    </html>
  );
}
```

> **Next.js 16 Notes:**
> - `middleware.ts` is replaced by `proxy.ts` for request interception
> - All `params` and `searchParams` must be `await`ed (async)
> - Turbopack is the default bundler (no config needed)
> - `cacheComponents` replaces the old `experimental.ppr` flag
> - React Compiler available via `reactCompiler: true` in `next.config.ts`

### Client-Side Proof Generation

```typescript
// frontend/lib/privacy/proofWorker.ts
// Runs in Web Worker to avoid blocking UI

import { BarretenbergBackend } from '@noir-lang/backend_barretenberg';
import { Noir } from '@noir-lang/noir_js';

// Load compiled circuit
import shieldedBorrowCircuit from '../../public/circuits/shielded_borrow.json';

export async function generateBorrowProof(inputs: {
  collateralAmount: bigint;
  collateralBlinding: bigint;
  borrowAmount: bigint;
  borrowBlinding: bigint;
  nullifierSecret: bigint;
  merklePath: string[];
  merkleIndices: number[];
  merkleRoot: string;
  oraclePrice: bigint;
  ltvBps: bigint;
  marketId: string;
}): Promise<{ proof: Uint8Array; publicInputs: string[] }> {

  const backend = new BarretenbergBackend(shieldedBorrowCircuit);
  const noir = new Noir(shieldedBorrowCircuit, backend);

  const { proof, publicInputs } = await noir.generateProof({
    // Map inputs to circuit parameters
    collateral_amount: inputs.collateralAmount.toString(),
    collateral_blinding: inputs.collateralBlinding.toString(),
    borrow_amount: inputs.borrowAmount.toString(),
    borrow_blinding: inputs.borrowBlinding.toString(),
    nullifier_secret: inputs.nullifierSecret.toString(),
    merkle_path: inputs.merklePath,
    merkle_indices: inputs.merkleIndices,
    merkle_root: inputs.merkleRoot,
    oracle_price: inputs.oraclePrice.toString(),
    ltv_bps: inputs.ltvBps.toString(),
    market_id: inputs.marketId,
  });

  return { proof, publicInputs };
}
```

### Key React Hooks

```typescript
// frontend/hooks/useShieldLend.ts

import { useContract, useSendTransaction } from '@starknet-react/core';
import { generateDepositProof } from '../lib/privacy/proofWorker';

export function useShieldedDeposit(marketAddress: string) {
  const { contract } = useContract({
    abi: LENDING_POOL_ABI,
    address: marketAddress,
  });

  const { sendAsync } = useSendTransaction({});

  async function shieldedDeposit(amount: bigint) {
    // 1. Generate cryptographic material
    const blindingFactor = generateRandomField();
    const commitment = pedersenHash(amount, blindingFactor);
    const encryptedAmount = elgamalEncrypt(amount, userPublicKey);

    // 2. Generate ZK proof (in web worker)
    const { proof } = await generateDepositProof({
      amount,
      blindingFactor,
      commitment,
    });

    // 3. Submit transaction
    const tx = await sendAsync([
      // Approve token transfer
      {
        contractAddress: collateralTokenAddress,
        entrypoint: 'approve',
        calldata: [marketAddress, amount.toString(), '0'],
      },
      // Shielded deposit
      {
        contractAddress: marketAddress,
        entrypoint: 'shielded_deposit',
        calldata: [
          commitment,
          encryptedAmount.c1,
          encryptedAmount.c2,
          ...serializeProof(proof),
        ],
      },
    ]);

    // 4. Store note locally (encrypted in localStorage or indexedDB)
    storeNote({
      commitment,
      amount,
      blindingFactor,
      nullifierSecret: generateRandomField(),
      txHash: tx.transaction_hash,
    });

    return tx;
  }

  return { shieldedDeposit };
}
```

---

## Testing Strategy

### Cairo Unit Tests (snforge)

```bash
# Run all contract tests
cd contracts
snforge test

# Run specific test file
snforge test test_lending_pool

# Run with gas reporting
snforge test --gas-report
```

### Noir Circuit Tests

```bash
# Run circuit tests
cd circuits
nargo test

# Generate proof for testing
nargo prove shielded_deposit

# Verify proof
nargo verify shielded_deposit
```

### Integration Test Flow

```bash
# 1. Start local Starknet devnet
starknet-devnet --seed 42

# 2. Deploy contracts
cd scripts && ts-node deploy_contracts.ts --network devnet

# 3. Setup test markets
ts-node setup_markets.ts --network devnet

# 4. Run E2E tests
cd frontend && npm run test:e2e
```

---

## Deployment

### Testnet Deployment (Starknet Sepolia)

```bash
# 1. Build contracts
cd contracts
scarb build

# 2. Declare contracts (upload bytecode)
starkli declare target/dev/shieldlend_MarketFactory.contract_class.json \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --network sepolia

# 3. Deploy factory
starkli deploy <CLASS_HASH> \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json \
  --network sepolia

# 4. Create initial markets via factory
ts-node scripts/setup_markets.ts --network sepolia

# 5. Deploy frontend
cd frontend && npm run build && vercel deploy
```

### Contract Addresses (fill after deployment)

```
# .env.local (frontend)
NEXT_PUBLIC_NETWORK=sepolia
NEXT_PUBLIC_MARKET_FACTORY=0x...
NEXT_PUBLIC_STRKBTC_TOKEN=0x...
NEXT_PUBLIC_TBTC_TOKEN=0x...
NEXT_PUBLIC_USDC_TOKEN=0x...
NEXT_PUBLIC_PRAGMA_ORACLE=0x...
```

---

## Dependencies & Resources

### Cairo / Contracts

| Dependency | Source | Purpose |
|---|---|---|
| OpenZeppelin Cairo | `openzeppelin = "0.17.0"` | ERC20, access control, reentrancy |
| Pragma Oracle | `pragma_lib` | On-chain price feeds |
| Garaga | `garaga` | ZK proof verification on Starknet |
| Alexandria | `alexandria` | Math utilities for Cairo |

### Noir / Circuits

| Dependency | Source | Purpose |
|---|---|---|
| noir_stdlib | Built-in | Pedersen, SHA256, Merkle |
| barretenberg | `@noir-lang/backend_barretenberg` | Proving backend |

### Frontend / JS

```json
{
  "dependencies": {
    "next": "^16.0.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "starknet": "^6.17.0",
    "@starknet-react/core": "^3.6.0",
    "@starknet-react/chains": "^1.0.0",
    "starknetkit": "^2.5.0",
    "@noir-lang/noir_js": "^0.30.0",
    "@noir-lang/backend_barretenberg": "^0.30.0",
    "zustand": "^4.5.0",
    "recharts": "^2.12.0",
    "tailwindcss": "^4.0.0",
    "@radix-ui/react-dialog": "^1.0.0",
    "@radix-ui/react-tabs": "^1.0.0"
  }
}
```

### Key Documentation Links

```
Starknet Docs:          https://docs.starknet.io/
Cairo Book:             https://book.cairo-lang.org/
Scarb:                  https://docs.swmansion.com/scarb/
Starknet Foundry:       https://foundry-rs.github.io/starknet-foundry/
OpenZeppelin Cairo:     https://docs.openzeppelin.com/contracts-cairo/
Garaga:                 https://github.com/keep-starknet-strange/garaga
Noir Language:          https://noir-lang.org/docs/
Pragma Oracle:          https://docs.pragma.build/
starknet.js:            https://www.starknetjs.com/
starknet-react:         https://starknet-react.com/
Xverse API:             https://docs.xverse.app/
Starknet AI Assistant:  https://agent.starknet.io/
```
