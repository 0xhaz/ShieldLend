// MarketFactory — Deploys and registers isolated lending markets
// Each market is a separate LendingPool with its own risk parameters.

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct MarketInfo {
    pub market_id: u256,
    pub pool_address: ContractAddress,
    pub collateral_token: ContractAddress,
    pub loan_token: ContractAddress,
    pub ltv_bps: u256,
    pub liquidation_threshold_bps: u256,
    pub is_active: bool,
}

#[starknet::interface]
pub trait IMarketFactory<TContractState> {
    /// Register a new market (pool must be deployed separately for MVP)
    fn register_market(
        ref self: TContractState,
        pool_address: ContractAddress,
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
        ltv_bps: u256,
        liquidation_threshold_bps: u256,
    ) -> u256;

    fn get_market_count(self: @TContractState) -> u256;
    fn get_market(self: @TContractState, market_id: u256) -> MarketInfo;
    fn get_market_by_tokens(
        self: @TContractState,
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
    ) -> MarketInfo;
}

#[starknet::contract]
pub mod MarketFactory {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use shieldlend::utils::constants::{MIN_LTV_BPS, MAX_LTV_BPS};
    use core::num::traits::Zero;
    use super::MarketInfo;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        market_count: u256,
        // market_id => MarketInfo fields (stored flat since Store for struct with ContractAddress)
        market_pools: Map<u256, ContractAddress>,
        market_collaterals: Map<u256, ContractAddress>,
        market_loans: Map<u256, ContractAddress>,
        market_ltvs: Map<u256, u256>,
        market_liq_thresholds: Map<u256, u256>,
        market_active: Map<u256, bool>,
        // (collateral, loan) => market_id for lookup
        pair_to_market: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MarketCreated: MarketCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct MarketCreated {
        #[key]
        market_id: u256,
        pool_address: ContractAddress,
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.market_count.write(0);
    }

    #[abi(embed_v0)]
    impl MarketFactoryImpl of super::IMarketFactory<ContractState> {
        fn register_market(
            ref self: ContractState,
            pool_address: ContractAddress,
            collateral_token: ContractAddress,
            loan_token: ContractAddress,
            ltv_bps: u256,
            liquidation_threshold_bps: u256,
        ) -> u256 {
            assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
            assert(!pool_address.is_zero(), 'SL: zero address');
            assert(!collateral_token.is_zero(), 'SL: zero address');
            assert(!loan_token.is_zero(), 'SL: zero address');
            assert(ltv_bps >= MIN_LTV_BPS && ltv_bps <= MAX_LTV_BPS, 'SL: invalid LTV');
            assert(liquidation_threshold_bps > ltv_bps, 'SL: invalid liq params');

            // Check market doesn't already exist for this pair
            let existing = self.pair_to_market.read((collateral_token, loan_token));
            assert(existing == 0, 'SL: market already exists');

            let market_id = self.market_count.read() + 1;
            self.market_count.write(market_id);

            self.market_pools.write(market_id, pool_address);
            self.market_collaterals.write(market_id, collateral_token);
            self.market_loans.write(market_id, loan_token);
            self.market_ltvs.write(market_id, ltv_bps);
            self.market_liq_thresholds.write(market_id, liquidation_threshold_bps);
            self.market_active.write(market_id, true);
            self.pair_to_market.write((collateral_token, loan_token), market_id);

            self.emit(MarketCreated {
                market_id,
                pool_address,
                collateral_token,
                loan_token,
            });

            market_id
        }

        fn get_market_count(self: @ContractState) -> u256 {
            self.market_count.read()
        }

        fn get_market(self: @ContractState, market_id: u256) -> MarketInfo {
            assert(market_id > 0 && market_id <= self.market_count.read(), 'SL: invalid market');
            MarketInfo {
                market_id,
                pool_address: self.market_pools.read(market_id),
                collateral_token: self.market_collaterals.read(market_id),
                loan_token: self.market_loans.read(market_id),
                ltv_bps: self.market_ltvs.read(market_id),
                liquidation_threshold_bps: self.market_liq_thresholds.read(market_id),
                is_active: self.market_active.read(market_id),
            }
        }

        fn get_market_by_tokens(
            self: @ContractState,
            collateral_token: ContractAddress,
            loan_token: ContractAddress,
        ) -> MarketInfo {
            let market_id = self.pair_to_market.read((collateral_token, loan_token));
            assert(market_id > 0, 'SL: market not found');
            self.get_market(market_id)
        }
    }
}
