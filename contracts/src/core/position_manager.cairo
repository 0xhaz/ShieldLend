// Position Manager — Tracks transparent user positions per market
// Stores deposited collateral and borrowed amounts per user.

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Position {
    pub deposited: u256,       // Collateral deposited (in collateral token units)
    pub borrowed: u256,        // Debt principal (scaled by borrow index at time of borrow)
    pub last_borrow_index: u256, // Borrow index when position was last updated
}

#[starknet::interface]
pub trait IPositionManager<TContractState> {
    fn get_position(self: @TContractState, user: ContractAddress) -> Position;
    fn get_user_debt(self: @TContractState, user: ContractAddress, current_borrow_index: u256) -> u256;
    fn get_health_factor(
        self: @TContractState,
        user: ContractAddress,
        current_borrow_index: u256,
        collateral_price: u256,
        loan_price: u256,
        price_precision: u256,
        liquidation_threshold_bps: u256,
    ) -> u256;
}

#[starknet::contract]
pub mod PositionManager {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapReadAccess, StorageMapWriteAccess,
    };
    use shieldlend::utils::constants::WAD;
    use shieldlend::utils::math::{ray_mul, ray_div, health_factor};
    use super::Position;

    #[storage]
    struct Storage {
        positions: Map<ContractAddress, Position>,
        pool_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, pool: ContractAddress) {
        self.pool_address.write(pool);
    }

    #[abi(embed_v0)]
    impl PositionManagerImpl of super::IPositionManager<ContractState> {
        fn get_position(self: @ContractState, user: ContractAddress) -> Position {
            self.positions.read(user)
        }

        /// Returns actual debt including accrued interest
        fn get_user_debt(
            self: @ContractState,
            user: ContractAddress,
            current_borrow_index: u256,
        ) -> u256 {
            let pos = self.positions.read(user);
            if pos.borrowed == 0 || pos.last_borrow_index == 0 {
                return 0;
            }
            // debt = borrowed * current_index / stored_index
            ray_mul(pos.borrowed, ray_div(current_borrow_index, pos.last_borrow_index))
        }

        fn get_health_factor(
            self: @ContractState,
            user: ContractAddress,
            current_borrow_index: u256,
            collateral_price: u256,
            loan_price: u256,
            price_precision: u256,
            liquidation_threshold_bps: u256,
        ) -> u256 {
            let pos = self.positions.read(user);
            let debt = self.get_user_debt(user, current_borrow_index);

            if debt == 0 {
                return WAD * 1000; // Effectively infinite
            }

            // collateral_value = deposited * collateral_price / price_precision
            let collateral_value = pos.deposited * collateral_price / price_precision;
            // debt_value = debt * loan_price / price_precision
            let debt_value = debt * loan_price / price_precision;

            health_factor(collateral_value, debt_value, liquidation_threshold_bps)
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn assert_only_pool(self: @ContractState) {
            assert(get_caller_address() == self.pool_address.read(), 'SL: only pool');
        }

        fn increase_deposit(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256,
        ) {
            self.assert_only_pool();
            let mut pos = self.positions.read(user);
            pos.deposited += amount;
            self.positions.write(user, pos);
        }

        fn decrease_deposit(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256,
        ) {
            self.assert_only_pool();
            let mut pos = self.positions.read(user);
            assert(pos.deposited >= amount, 'SL: insufficient collateral');
            pos.deposited -= amount;
            self.positions.write(user, pos);
        }

        fn increase_borrow(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256,
            current_borrow_index: u256,
        ) {
            self.assert_only_pool();
            let mut pos = self.positions.read(user);
            // Normalize existing debt to current index before adding
            if pos.borrowed > 0 && pos.last_borrow_index > 0 {
                pos.borrowed = ray_mul(
                    pos.borrowed,
                    ray_div(current_borrow_index, pos.last_borrow_index),
                );
            }
            pos.borrowed += amount;
            pos.last_borrow_index = current_borrow_index;
            self.positions.write(user, pos);
        }

        fn decrease_borrow(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256,
            current_borrow_index: u256,
        ) {
            self.assert_only_pool();
            let mut pos = self.positions.read(user);
            // Normalize debt to current index
            if pos.borrowed > 0 && pos.last_borrow_index > 0 {
                pos.borrowed = ray_mul(
                    pos.borrowed,
                    ray_div(current_borrow_index, pos.last_borrow_index),
                );
            }
            if amount >= pos.borrowed {
                pos.borrowed = 0;
            } else {
                pos.borrowed -= amount;
            }
            pos.last_borrow_index = current_borrow_index;
            self.positions.write(user, pos);
        }
    }
}
