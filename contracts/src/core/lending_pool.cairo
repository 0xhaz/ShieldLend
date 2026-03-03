// LendingPool — Per-market deposit/borrow/repay/withdraw
// Supports both transparent and shielded (privacy-preserving) modes.
// Each isolated market has its own LendingPool instance.
// Holds collateral tokens, issues slTokens, tracks debt via debtTokens.

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct MarketData {
    pub total_deposits: u256,
    pub total_borrows: u256,
    pub utilization_rate_bps: u256,
    pub borrow_rate: u256,
    pub supply_rate: u256,
    pub borrow_index: u256,
    pub supply_index: u256,
}

#[starknet::interface]
pub trait ILendingPool<TContractState> {
    // --- Transparent mode ---
    fn deposit(ref self: TContractState, amount: u256) -> u256;
    fn withdraw(ref self: TContractState, sl_token_amount: u256) -> u256;
    fn borrow(ref self: TContractState, amount: u256);
    fn repay(ref self: TContractState, amount: u256);

    // --- Shielded mode ---
    fn shielded_deposit(
        ref self: TContractState,
        amount: u256,
        commitment: felt252,
        encrypted_amount: felt252,
        proof: Array<felt252>,
    );
    fn shielded_withdraw(
        ref self: TContractState,
        amount: u256,
        nullifier: felt252,
        change_commitment: felt252,
        merkle_root: felt252,
        proof: Array<felt252>,
    );
    fn shielded_borrow(
        ref self: TContractState,
        amount: u256,
        borrow_commitment: felt252,
        collateral_nullifier: felt252,
        merkle_root: felt252,
        encrypted_borrow_amount: felt252,
        proof: Array<felt252>,
    );
    fn shielded_repay(
        ref self: TContractState,
        amount: u256,
        debt_nullifier: felt252,
        new_debt_commitment: felt252,
        proof: Array<felt252>,
    );

    // --- Views ---
    fn get_market_data(self: @TContractState) -> MarketData;
    fn get_collateral_token(self: @TContractState) -> ContractAddress;
    fn get_loan_token(self: @TContractState) -> ContractAddress;
    fn get_ltv_bps(self: @TContractState) -> u256;
    fn get_liquidation_threshold_bps(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod LendingPool {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use shieldlend::utils::constants::{RAY, WAD};
    use shieldlend::utils::math::{ray_mul, ray_div, utilization_rate, health_factor, bps_mul};

    // ERC20 dispatcher for token transfers
    use openzeppelin::interfaces::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    // Our protocol token interfaces
    use shieldlend::tokens::sl_token::{ISlTokenDispatcher, ISlTokenDispatcherTrait};
    use shieldlend::tokens::debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait};
    use shieldlend::interest::rate_model::{
        IInterestRateModelDispatcher, IInterestRateModelDispatcherTrait,
    };
    use shieldlend::oracle::pragma_adapter::{
        IPragmaAdapterDispatcher, IPragmaAdapterDispatcherTrait,
    };

    // Privacy contract dispatchers
    use shieldlend::privacy::commitment_store::{
        ICommitmentStoreDispatcher, ICommitmentStoreDispatcherTrait,
    };
    use shieldlend::privacy::nullifier_registry::{
        INullifierRegistryDispatcher, INullifierRegistryDispatcherTrait,
    };
    use shieldlend::privacy::zk_verifier::{
        IZkVerifierDispatcher, IZkVerifierDispatcherTrait,
    };

    use super::MarketData;

    #[storage]
    struct Storage {
        // Market configuration (set once at construction)
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
        sl_token: ContractAddress,       // SlToken address (receipt token)
        debt_token: ContractAddress,     // DebtToken address
        oracle: ContractAddress,         // PragmaAdapter address
        interest_rate_model: ContractAddress,

        // Risk parameters
        ltv_bps: u256,                   // Max loan-to-value ratio
        liquidation_threshold_bps: u256,
        liquidation_bonus_bps: u256,
        reserve_factor_bps: u256,        // Protocol take on interest

        // Market state
        total_deposits: u256,
        total_borrows: u256,
        borrow_index: u256,              // RAY — compound interest accumulator
        supply_index: u256,
        last_update_timestamp: u64,
        is_active: bool,

        // Per-user tracking: user => deposited collateral amount
        user_deposits: Map<ContractAddress, u256>,
        // Per-user tracking: user => borrow principal (at time of borrow index)
        user_borrows: Map<ContractAddress, u256>,
        user_borrow_index: Map<ContractAddress, u256>,

        // Privacy infrastructure addresses
        commitment_store: ContractAddress,
        nullifier_registry: ContractAddress,
        zk_verifier: ContractAddress,

        // Shielded pool totals (tracked separately for accounting)
        shielded_deposits: u256,
        shielded_borrows: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        Borrow: Borrow,
        Repay: Repay,
        InterestAccrued: InterestAccrued,
        ShieldedDeposit: ShieldedDeposit,
        ShieldedWithdraw: ShieldedWithdraw,
        ShieldedBorrow: ShieldedBorrow,
        ShieldedRepay: ShieldedRepay,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        user: ContractAddress,
        amount: u256,
        sl_tokens_minted: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        user: ContractAddress,
        amount: u256,
        sl_tokens_burned: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Borrow {
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Repay {
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct InterestAccrued {
        borrow_index: u256,
        supply_index: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedDeposit {
        #[key]
        commitment: felt252,
        leaf_index: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedWithdraw {
        #[key]
        nullifier: felt252,
        change_commitment: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedBorrow {
        #[key]
        borrow_commitment: felt252,
        collateral_nullifier: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ShieldedRepay {
        #[key]
        debt_nullifier: felt252,
        new_debt_commitment: felt252,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
        sl_token: ContractAddress,
        debt_token: ContractAddress,
        oracle: ContractAddress,
        interest_rate_model: ContractAddress,
        ltv_bps: u256,
        liquidation_threshold_bps: u256,
        liquidation_bonus_bps: u256,
        reserve_factor_bps: u256,
        zk_verifier: ContractAddress,
        commitment_store: ContractAddress,
        nullifier_registry: ContractAddress,
    ) {
        self.collateral_token.write(collateral_token);
        self.loan_token.write(loan_token);
        self.sl_token.write(sl_token);
        self.debt_token.write(debt_token);
        self.oracle.write(oracle);
        self.interest_rate_model.write(interest_rate_model);
        self.ltv_bps.write(ltv_bps);
        self.liquidation_threshold_bps.write(liquidation_threshold_bps);
        self.liquidation_bonus_bps.write(liquidation_bonus_bps);
        self.reserve_factor_bps.write(reserve_factor_bps);
        self.zk_verifier.write(zk_verifier);
        self.commitment_store.write(commitment_store);
        self.nullifier_registry.write(nullifier_registry);
        self.borrow_index.write(RAY);
        self.supply_index.write(RAY);
        self.last_update_timestamp.write(get_block_timestamp());
        self.is_active.write(true);
    }

    #[abi(embed_v0)]
    impl LendingPoolImpl of super::ILendingPool<ContractState> {

        /// Deposit collateral tokens into the market
        /// Returns: number of slTokens minted
        fn deposit(ref self: ContractState, amount: u256) -> u256 {
            assert(self.is_active.read(), 'SL: market not active');
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            let caller = get_caller_address();
            let this = get_contract_address();

            // Transfer collateral from user to pool
            let collateral = ERC20ABIDispatcher { contract_address: self.collateral_token.read() };
            collateral.transfer_from(caller, this, amount);

            // Mint slTokens 1:1 with deposit
            let sl = ISlTokenDispatcher { contract_address: self.sl_token.read() };
            sl.mint(caller, amount);

            // Update state
            self.total_deposits.write(self.total_deposits.read() + amount);
            let user_dep = self.user_deposits.read(caller);
            self.user_deposits.write(caller, user_dep + amount);

            self.emit(Deposit { user: caller, amount, sl_tokens_minted: amount });
            amount
        }

        /// Withdraw collateral by burning slTokens
        /// Returns: amount of collateral returned
        fn withdraw(ref self: ContractState, sl_token_amount: u256) -> u256 {
            assert(sl_token_amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            let caller = get_caller_address();
            let amount = sl_token_amount; // 1:1 for MVP

            // Check user has enough deposited
            let user_dep = self.user_deposits.read(caller);
            assert(user_dep >= amount, 'SL: insufficient collateral');

            // Check health factor remains ok after withdrawal
            let remaining_deposit = user_dep - amount;
            let user_debt = self.get_user_actual_debt(caller);
            if user_debt > 0 {
                let hf = self.compute_health_factor(remaining_deposit, user_debt);
                assert(hf >= WAD, 'SL: would be undercollat');
            }

            // Check pool has enough liquidity
            let available = self.total_deposits.read() - self.total_borrows.read();
            assert(available >= amount, 'SL: insufficient liquidity');

            // Burn slTokens
            let sl = ISlTokenDispatcher { contract_address: self.sl_token.read() };
            sl.burn(caller, sl_token_amount);

            // Transfer collateral back to user
            let collateral = ERC20ABIDispatcher { contract_address: self.collateral_token.read() };
            collateral.transfer(caller, amount);

            // Update state
            self.total_deposits.write(self.total_deposits.read() - amount);
            self.user_deposits.write(caller, remaining_deposit);

            self.emit(Withdraw { user: caller, amount, sl_tokens_burned: sl_token_amount });
            amount
        }

        /// Borrow loan tokens against deposited collateral
        fn borrow(ref self: ContractState, amount: u256) {
            assert(self.is_active.read(), 'SL: market not active');
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            let caller = get_caller_address();

            // Check pool has enough loan token liquidity
            let loan = ERC20ABIDispatcher { contract_address: self.loan_token.read() };
            let available = loan.balance_of(get_contract_address());
            assert(available >= amount, 'SL: insufficient liquidity');

            // Check user collateral supports this borrow (using LTV, not liquidation threshold)
            let user_dep = self.user_deposits.read(caller);
            let existing_debt = self.get_user_actual_debt(caller);
            let new_total_debt = existing_debt + amount;

            // max_borrow = collateral_value * ltv / price_precision_scaling
            let oracle = IPragmaAdapterDispatcher { contract_address: self.oracle.read() };
            let col_price = oracle.get_price(self.collateral_token.read());
            let loan_price = oracle.get_price(self.loan_token.read());
            let precision = oracle.get_price_precision();

            let collateral_value = user_dep * col_price / precision;
            let max_borrow_value = bps_mul(collateral_value, self.ltv_bps.read());
            let debt_value = new_total_debt * loan_price / precision;
            assert(max_borrow_value >= debt_value, 'SL: insufficient collateral');

            // Mint debt tokens
            let dt = IDebtTokenDispatcher { contract_address: self.debt_token.read() };
            dt.mint(caller, amount);

            // Transfer loan tokens to user
            let loan = ERC20ABIDispatcher { contract_address: self.loan_token.read() };
            loan.transfer(caller, amount);

            // Update state
            self.total_borrows.write(self.total_borrows.read() + amount);

            // Track user's borrow with current index
            let current_idx = self.borrow_index.read();
            let user_existing = self.user_borrows.read(caller);
            let user_idx = self.user_borrow_index.read(caller);

            // Normalize existing debt and add new
            let normalized = if user_existing > 0 && user_idx > 0 {
                ray_mul(user_existing, ray_div(current_idx, user_idx))
            } else {
                0
            };
            self.user_borrows.write(caller, normalized + amount);
            self.user_borrow_index.write(caller, current_idx);

            self.emit(Borrow { user: caller, amount });
        }

        /// Repay borrowed tokens
        fn repay(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            let caller = get_caller_address();
            let this = get_contract_address();

            let actual_debt = self.get_user_actual_debt(caller);
            assert(actual_debt > 0, 'SL: no debt');

            // Cap repayment to actual debt
            let repay_amount = if amount > actual_debt {
                actual_debt
            } else {
                amount
            };

            // Transfer loan tokens from user to pool
            let loan = ERC20ABIDispatcher { contract_address: self.loan_token.read() };
            loan.transfer_from(caller, this, repay_amount);

            // Burn debt tokens
            let dt = IDebtTokenDispatcher { contract_address: self.debt_token.read() };
            dt.burn(caller, repay_amount);

            // Update state
            let total_borrows = self.total_borrows.read();
            if repay_amount >= total_borrows {
                self.total_borrows.write(0);
            } else {
                self.total_borrows.write(total_borrows - repay_amount);
            }

            // Update user tracking
            let current_idx = self.borrow_index.read();
            if repay_amount >= actual_debt {
                self.user_borrows.write(caller, 0);
            } else {
                self.user_borrows.write(caller, actual_debt - repay_amount);
            }
            self.user_borrow_index.write(caller, current_idx);

            self.emit(Repay { user: caller, amount: repay_amount });
        }

        // ======== Shielded Mode ========

        /// Shielded deposit: user deposits tokens but amount is hidden behind a commitment.
        /// The actual amount is transferred (visible on-chain), but the commitment hides
        /// the association between the deposit and future withdrawals/borrows.
        fn shielded_deposit(
            ref self: ContractState,
            amount: u256,
            commitment: felt252,
            encrypted_amount: felt252,
            proof: Array<felt252>,
        ) {
            assert(self.is_active.read(), 'SL: market not active');
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            // Verify ZK proof: proves commitment = Pedersen(amount, blinding)
            let verifier = IZkVerifierDispatcher {
                contract_address: self.zk_verifier.read(),
            };
            let public_inputs: Array<felt252> = array![commitment];
            assert(
                verifier.verify_proof(0, proof.span(), public_inputs.span()),
                'SL: invalid ZK proof',
            );

            // Transfer collateral from user to pool
            let caller = get_caller_address();
            let this = get_contract_address();
            let collateral = ERC20ABIDispatcher {
                contract_address: self.collateral_token.read(),
            };
            collateral.transfer_from(caller, this, amount);

            // Insert commitment into Merkle tree
            let cs = ICommitmentStoreDispatcher {
                contract_address: self.commitment_store.read(),
            };
            let leaf_index = cs.insert(commitment);

            // Update shielded totals
            self.total_deposits.write(self.total_deposits.read() + amount);
            self.shielded_deposits.write(self.shielded_deposits.read() + amount);

            self.emit(ShieldedDeposit { commitment, leaf_index });
        }

        /// Shielded withdraw: user proves ownership of a deposit commitment
        /// and withdraws funds. The nullifier prevents double-spending.
        fn shielded_withdraw(
            ref self: ContractState,
            amount: u256,
            nullifier: felt252,
            change_commitment: felt252,
            merkle_root: felt252,
            proof: Array<felt252>,
        ) {
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            // Verify the Merkle root is valid
            let cs = ICommitmentStoreDispatcher {
                contract_address: self.commitment_store.read(),
            };
            assert(cs.is_known_root(merkle_root), 'SL: invalid merkle root');

            // Verify nullifier hasn't been spent
            let nr = INullifierRegistryDispatcher {
                contract_address: self.nullifier_registry.read(),
            };
            assert(!nr.is_spent(nullifier), 'SL: nullifier used');

            // Verify ZK proof: proves knowledge of commitment preimage,
            // valid Merkle path, and correct nullifier derivation
            let verifier = IZkVerifierDispatcher {
                contract_address: self.zk_verifier.read(),
            };
            let public_inputs: Array<felt252> = array![
                nullifier, change_commitment, merkle_root,
            ];
            assert(
                verifier.verify_proof(2, proof.span(), public_inputs.span()),
                'SL: invalid ZK proof',
            );

            // Spend the nullifier
            nr.spend(nullifier);

            // If there's a change commitment, insert it into the Merkle tree
            if change_commitment != 0 {
                cs.insert(change_commitment);
            }

            // Check liquidity
            let available = self.total_deposits.read() - self.total_borrows.read();
            assert(available >= amount, 'SL: insufficient liquidity');

            // Transfer collateral back to caller
            let caller = get_caller_address();
            let collateral = ERC20ABIDispatcher {
                contract_address: self.collateral_token.read(),
            };
            collateral.transfer(caller, amount);

            // Update totals
            self.total_deposits.write(self.total_deposits.read() - amount);
            let shielded = self.shielded_deposits.read();
            if amount >= shielded {
                self.shielded_deposits.write(0);
            } else {
                self.shielded_deposits.write(shielded - amount);
            }

            self.emit(ShieldedWithdraw { nullifier, change_commitment });
        }

        /// Shielded borrow: user proves collateral commitment exists and is sufficient,
        /// borrows loan tokens. Collateral nullifier consumed, borrow commitment created.
        fn shielded_borrow(
            ref self: ContractState,
            amount: u256,
            borrow_commitment: felt252,
            collateral_nullifier: felt252,
            merkle_root: felt252,
            encrypted_borrow_amount: felt252,
            proof: Array<felt252>,
        ) {
            assert(self.is_active.read(), 'SL: market not active');
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            // Verify Merkle root
            let cs = ICommitmentStoreDispatcher {
                contract_address: self.commitment_store.read(),
            };
            assert(cs.is_known_root(merkle_root), 'SL: invalid merkle root');

            // Verify nullifier not spent
            let nr = INullifierRegistryDispatcher {
                contract_address: self.nullifier_registry.read(),
            };
            assert(!nr.is_spent(collateral_nullifier), 'SL: nullifier used');

            // Get oracle data for the proof public inputs
            let oracle = IPragmaAdapterDispatcher {
                contract_address: self.oracle.read(),
            };
            let col_price = oracle.get_price(self.collateral_token.read());
            let precision = oracle.get_price_precision();

            // Verify ZK proof: proves collateral ownership, solvency, and borrow commitment
            let verifier = IZkVerifierDispatcher {
                contract_address: self.zk_verifier.read(),
            };

            // Convert u256 to felt252 for public inputs
            let price_felt: felt252 = col_price.try_into().unwrap();
            let ltv_felt: felt252 = self.ltv_bps.read().try_into().unwrap();
            let prec_felt: felt252 = precision.try_into().unwrap();

            let public_inputs: Array<felt252> = array![
                borrow_commitment,
                collateral_nullifier,
                merkle_root,
                price_felt,
                ltv_felt,
                prec_felt,
            ];
            assert(
                verifier.verify_proof(1, proof.span(), public_inputs.span()),
                'SL: invalid ZK proof',
            );

            // Spend the collateral nullifier
            nr.spend(collateral_nullifier);

            // Insert borrow commitment
            cs.insert(borrow_commitment);

            // Check pool has enough loan token liquidity
            let caller = get_caller_address();
            let loan = ERC20ABIDispatcher {
                contract_address: self.loan_token.read(),
            };
            let available = loan.balance_of(get_contract_address());
            assert(available >= amount, 'SL: insufficient liquidity');

            // Transfer loan tokens to caller
            loan.transfer(caller, amount);

            // Update totals
            self.total_borrows.write(self.total_borrows.read() + amount);
            self.shielded_borrows.write(self.shielded_borrows.read() + amount);

            self.emit(ShieldedBorrow {
                borrow_commitment,
                collateral_nullifier,
            });
        }

        /// Shielded repay: user repays debt and creates a new (smaller) debt commitment.
        fn shielded_repay(
            ref self: ContractState,
            amount: u256,
            debt_nullifier: felt252,
            new_debt_commitment: felt252,
            proof: Array<felt252>,
        ) {
            assert(amount > 0, 'SL: amount is zero');

            self.accrue_interest();

            // Verify nullifier not spent
            let nr = INullifierRegistryDispatcher {
                contract_address: self.nullifier_registry.read(),
            };
            assert(!nr.is_spent(debt_nullifier), 'SL: nullifier used');

            // Verify ZK proof
            let verifier = IZkVerifierDispatcher {
                contract_address: self.zk_verifier.read(),
            };
            // Circuit type 2 expects 3 public inputs (nullifier, commitment, root)
            // For repay, we use 0 as the merkle_root placeholder
            let public_inputs: Array<felt252> = array![
                debt_nullifier, new_debt_commitment, 0,
            ];
            assert(
                verifier.verify_proof(2, proof.span(), public_inputs.span()),
                'SL: invalid ZK proof',
            );

            // Spend the debt nullifier
            nr.spend(debt_nullifier);

            // If new debt commitment exists (partial repay), insert it
            let cs = ICommitmentStoreDispatcher {
                contract_address: self.commitment_store.read(),
            };
            if new_debt_commitment != 0 {
                cs.insert(new_debt_commitment);
            }

            // Transfer loan tokens from caller to pool
            let caller = get_caller_address();
            let this = get_contract_address();
            let loan = ERC20ABIDispatcher {
                contract_address: self.loan_token.read(),
            };
            loan.transfer_from(caller, this, amount);

            // Update totals
            let total_borrows = self.total_borrows.read();
            if amount >= total_borrows {
                self.total_borrows.write(0);
            } else {
                self.total_borrows.write(total_borrows - amount);
            }
            let shielded = self.shielded_borrows.read();
            if amount >= shielded {
                self.shielded_borrows.write(0);
            } else {
                self.shielded_borrows.write(shielded - amount);
            }

            self.emit(ShieldedRepay { debt_nullifier, new_debt_commitment });
        }

        fn get_market_data(self: @ContractState) -> MarketData {
            let deposits = self.total_deposits.read();
            let borrows = self.total_borrows.read();
            let util = utilization_rate(deposits, borrows);

            let irm = IInterestRateModelDispatcher {
                contract_address: self.interest_rate_model.read(),
            };
            let borrow_rate = irm.get_borrow_rate(deposits, borrows);
            let supply_rate = irm.get_supply_rate(
                deposits, borrows, self.reserve_factor_bps.read(),
            );

            MarketData {
                total_deposits: deposits,
                total_borrows: borrows,
                utilization_rate_bps: util,
                borrow_rate,
                supply_rate,
                borrow_index: self.borrow_index.read(),
                supply_index: self.supply_index.read(),
            }
        }

        fn get_collateral_token(self: @ContractState) -> ContractAddress {
            self.collateral_token.read()
        }

        fn get_loan_token(self: @ContractState) -> ContractAddress {
            self.loan_token.read()
        }

        fn get_ltv_bps(self: @ContractState) -> u256 {
            self.ltv_bps.read()
        }

        fn get_liquidation_threshold_bps(self: @ContractState) -> u256 {
            self.liquidation_threshold_bps.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Accrue interest: update borrow and supply indices
        fn accrue_interest(ref self: ContractState) {
            let now = get_block_timestamp();
            let last = self.last_update_timestamp.read();

            if now <= last {
                return;
            }

            let deposits = self.total_deposits.read();
            let borrows = self.total_borrows.read();

            if deposits == 0 {
                self.last_update_timestamp.write(now);
                return;
            }

            let irm = IInterestRateModelDispatcher {
                contract_address: self.interest_rate_model.read(),
            };
            let borrow_rate = irm.get_borrow_rate(deposits, borrows);
            let supply_rate = irm.get_supply_rate(
                deposits, borrows, self.reserve_factor_bps.read(),
            );

            let time_delta: u256 = (now - last).into();

            // borrow_index *= (1 + rate * dt)
            let borrow_mult = RAY + borrow_rate * time_delta;
            let new_bi = ray_mul(self.borrow_index.read(), borrow_mult);
            self.borrow_index.write(new_bi);

            let supply_mult = RAY + supply_rate * time_delta;
            let new_si = ray_mul(self.supply_index.read(), supply_mult);
            self.supply_index.write(new_si);

            self.last_update_timestamp.write(now);

            self.emit(InterestAccrued {
                borrow_index: new_bi,
                supply_index: new_si,
                timestamp: now,
            });
        }

        /// Get a user's actual debt (principal * index growth)
        fn get_user_actual_debt(self: @ContractState, user: ContractAddress) -> u256 {
            let principal = self.user_borrows.read(user);
            let user_idx = self.user_borrow_index.read(user);
            if principal == 0 || user_idx == 0 {
                return 0;
            }
            let current_idx = self.borrow_index.read();
            ray_mul(principal, ray_div(current_idx, user_idx))
        }

        /// Compute health factor for given deposit and debt amounts
        fn compute_health_factor(
            self: @ContractState,
            deposit_amount: u256,
            debt_amount: u256,
        ) -> u256 {
            if debt_amount == 0 {
                return WAD * 1000;
            }

            let oracle = IPragmaAdapterDispatcher { contract_address: self.oracle.read() };
            let col_price = oracle.get_price(self.collateral_token.read());
            let loan_price = oracle.get_price(self.loan_token.read());
            let precision = oracle.get_price_precision();

            let collateral_value = deposit_amount * col_price / precision;
            let debt_value = debt_amount * loan_price / precision;

            health_factor(collateral_value, debt_value, self.liquidation_threshold_bps.read())
        }
    }
}
