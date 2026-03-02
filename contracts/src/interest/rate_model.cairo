// Two-slope interest rate model
// Inspired by Aave/Compound utilization-based model
//
// rate = base_rate + slope1 * (utilization / optimal)           [below kink]
// rate = base_rate + slope1 + slope2 * (util - optimal) / (1 - optimal)  [above kink]

use starknet::ContractAddress;
use shieldlend::utils::constants::{RAY, BPS, SECONDS_PER_YEAR};
use shieldlend::utils::math::{ray_mul, ray_div};

#[starknet::interface]
trait IInterestRateModel<TContractState> {
    fn get_borrow_rate(
        self: @TContractState,
        total_deposits: u256,
        total_borrows: u256,
    ) -> u256;

    fn get_supply_rate(
        self: @TContractState,
        total_deposits: u256,
        total_borrows: u256,
        reserve_factor_bps: u256,
    ) -> u256;

    fn get_params(self: @TContractState) -> (u256, u256, u256, u256);
}

#[starknet::contract]
mod InterestRateModel {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{RAY, BPS, SECONDS_PER_YEAR, ray_mul, ray_div};

    #[storage]
    struct Storage {
        base_rate: u256,               // RAY — annual rate at 0% utilization
        slope1: u256,                  // RAY — rate increase below optimal
        slope2: u256,                  // RAY — rate increase above optimal (steep)
        optimal_utilization: u256,     // BPS — kink point
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_rate: u256,
        slope1: u256,
        slope2: u256,
        optimal_utilization: u256,
    ) {
        self.base_rate.write(base_rate);
        self.slope1.write(slope1);
        self.slope2.write(slope2);
        self.optimal_utilization.write(optimal_utilization);
    }

    #[abi(embed_v0)]
    impl InterestRateModelImpl of super::IInterestRateModel<ContractState> {

        fn get_borrow_rate(
            self: @ContractState,
            total_deposits: u256,
            total_borrows: u256,
        ) -> u256 {
            if total_deposits == 0 {
                return self.base_rate.read() / SECONDS_PER_YEAR;
            }

            let utilization = (total_borrows * BPS) / total_deposits;
            let optimal = self.optimal_utilization.read();
            let base = self.base_rate.read();
            let s1 = self.slope1.read();
            let s2 = self.slope2.read();

            let annual_rate = if utilization <= optimal {
                // Below kink: linear increase
                base + ray_mul(s1, utilization * RAY / optimal)
            } else {
                // Above kink: steep increase
                let excess = utilization - optimal;
                let max_excess = BPS - optimal;
                base + s1 + ray_mul(s2, excess * RAY / max_excess)
            };

            // Convert annual rate to per-second rate
            annual_rate / SECONDS_PER_YEAR
        }

        fn get_supply_rate(
            self: @ContractState,
            total_deposits: u256,
            total_borrows: u256,
            reserve_factor_bps: u256,
        ) -> u256 {
            let borrow_rate = self.get_borrow_rate(total_deposits, total_borrows);

            if total_deposits == 0 {
                return 0;
            }

            let utilization_ray = (total_borrows * RAY) / total_deposits;
            let after_reserve = BPS - reserve_factor_bps;

            ray_mul(ray_mul(borrow_rate, utilization_ray), after_reserve * RAY / BPS)
        }

        fn get_params(self: @ContractState) -> (u256, u256, u256, u256) {
            (
                self.base_rate.read(),
                self.slope1.read(),
                self.slope2.read(),
                self.optimal_utilization.read(),
            )
        }
    }
}
