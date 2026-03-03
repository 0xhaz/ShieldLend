// Rate Accumulator — Tracks compound interest indices over time
// borrow_index and supply_index grow over time as interest accrues.
// User debt = debt_token_balance * borrow_index / user_index_at_borrow_time

use shieldlend::utils::constants::RAY;
use shieldlend::utils::math::{ray_mul, compound_interest};

#[starknet::interface]
pub trait IRateAccumulator<TContractState> {
    fn get_borrow_index(self: @TContractState) -> u256;
    fn get_supply_index(self: @TContractState) -> u256;
    fn get_last_update(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod RateAccumulator {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::get_block_timestamp;
    use super::{RAY, ray_mul, compound_interest};

    #[storage]
    struct Storage {
        borrow_index: u256,
        supply_index: u256,
        last_update_timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        IndicesUpdated: IndicesUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct IndicesUpdated {
        borrow_index: u256,
        supply_index: u256,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.borrow_index.write(RAY);
        self.supply_index.write(RAY);
        self.last_update_timestamp.write(get_block_timestamp());
    }

    #[abi(embed_v0)]
    impl RateAccumulatorImpl of super::IRateAccumulator<ContractState> {
        fn get_borrow_index(self: @ContractState) -> u256 {
            self.borrow_index.read()
        }

        fn get_supply_index(self: @ContractState) -> u256 {
            self.supply_index.read()
        }

        fn get_last_update(self: @ContractState) -> u64 {
            self.last_update_timestamp.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn accrue_interest(
            ref self: ContractState,
            borrow_rate_per_second: u256,
            supply_rate_per_second: u256,
        ) {
            let now = get_block_timestamp();
            let last = self.last_update_timestamp.read();

            if now <= last {
                return;
            }

            let time_delta: u256 = (now - last).into();

            let borrow_multiplier = compound_interest(borrow_rate_per_second, time_delta);
            let new_borrow_index = ray_mul(self.borrow_index.read(), borrow_multiplier);
            self.borrow_index.write(new_borrow_index);

            let supply_multiplier = compound_interest(supply_rate_per_second, time_delta);
            let new_supply_index = ray_mul(self.supply_index.read(), supply_multiplier);
            self.supply_index.write(new_supply_index);

            self.last_update_timestamp.write(now);

            self.emit(IndicesUpdated {
                borrow_index: new_borrow_index,
                supply_index: new_supply_index,
                timestamp: now,
            });
        }
    }
}
