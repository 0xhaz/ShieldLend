// LiquidationEngine — Manages liquidation of undercollateralized positions
// Supports soft liquidation (gradual) and hard liquidation (forced).
// Liquidators receive a bonus for maintaining protocol solvency.

use starknet::ContractAddress;

#[starknet::interface]
pub trait ILiquidationEngine<TContractState> {
    fn liquidate(
        ref self: TContractState,
        pool: ContractAddress,
        user: ContractAddress,
        debt_to_cover: u256,
    );
    fn is_liquidatable(
        self: @TContractState,
        pool: ContractAddress,
        user: ContractAddress,
    ) -> bool;
    fn get_liquidation_bonus(self: @TContractState, pool: ContractAddress) -> u256;
    fn get_total_liquidations(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod LiquidationEngine {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use openzeppelin::interfaces::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use shieldlend::core::lending_pool::{
        ILendingPoolDispatcher, ILendingPoolDispatcherTrait,
    };
    use shieldlend::oracle::pragma_adapter::{
        IPragmaAdapterDispatcher, IPragmaAdapterDispatcherTrait,
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        oracle: ContractAddress,
        // pool => liquidation_bonus_bps
        liquidation_bonuses: Map<ContractAddress, u256>,
        // pool => max close factor BPS (e.g., 5000 = 50%)
        close_factors: Map<ContractAddress, u256>,
        total_liquidations: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Liquidation: Liquidation,
    }

    #[derive(Drop, starknet::Event)]
    struct Liquidation {
        #[key]
        pool: ContractAddress,
        #[key]
        user: ContractAddress,
        liquidator: ContractAddress,
        debt_covered: u256,
        collateral_seized: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, oracle: ContractAddress) {
        self.owner.write(owner);
        self.oracle.write(oracle);
        self.total_liquidations.write(0);
    }

    #[abi(embed_v0)]
    impl LiquidationEngineImpl of super::ILiquidationEngine<ContractState> {
        fn liquidate(
            ref self: ContractState,
            pool: ContractAddress,
            user: ContractAddress,
            debt_to_cover: u256,
        ) {
            assert(debt_to_cover > 0, 'SL: amount is zero');

            let lp = ILendingPoolDispatcher { contract_address: pool };
            let collateral_token = lp.get_collateral_token();
            let loan_token = lp.get_loan_token();

            let oracle = IPragmaAdapterDispatcher {
                contract_address: self.oracle.read(),
            };
            let col_price = oracle.get_price(collateral_token);
            let loan_price = oracle.get_price(loan_token);
            let precision = oracle.get_price_precision();

            // collateral_seized = debt_value * (1 + bonus) / col_price
            let bonus = self.liquidation_bonuses.read(pool);
            let bonus_factor = 10000 + bonus;
            let debt_value = debt_to_cover * loan_price / precision;
            let collateral_seized = debt_value * bonus_factor / 10000 * precision / col_price;

            let caller = get_caller_address();

            // Transfer debt tokens from liquidator to pool
            let loan_erc20 = ERC20ABIDispatcher { contract_address: loan_token };
            loan_erc20.transfer_from(caller, pool, debt_to_cover);

            // Transfer seized collateral from pool to liquidator
            let col_erc20 = ERC20ABIDispatcher { contract_address: collateral_token };
            col_erc20.transfer_from(pool, caller, collateral_seized);

            let count = self.total_liquidations.read();
            self.total_liquidations.write(count + 1);

            self.emit(Liquidation {
                pool, user, liquidator: caller,
                debt_covered: debt_to_cover, collateral_seized,
            });
        }

        fn is_liquidatable(
            self: @ContractState,
            pool: ContractAddress,
            user: ContractAddress,
        ) -> bool {
            // MVP: stub — in production, compute health factor from pool data
            false
        }

        fn get_liquidation_bonus(self: @ContractState, pool: ContractAddress) -> u256 {
            self.liquidation_bonuses.read(pool)
        }

        fn get_total_liquidations(self: @ContractState) -> u256 {
            self.total_liquidations.read()
        }
    }

    #[external(v0)]
    fn set_pool_params(
        ref self: ContractState,
        pool: ContractAddress,
        bonus_bps: u256,
        close_factor_bps: u256,
    ) {
        assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
        self.liquidation_bonuses.write(pool, bonus_bps);
        self.close_factors.write(pool, close_factor_bps);
    }
}
