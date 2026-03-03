use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use starknet::ContractAddress;
use shieldlend::interest::rate_model::{
    IInterestRateModelDispatcher, IInterestRateModelDispatcherTrait,
};
use shieldlend::utils::constants::{RAY, BPS, SECONDS_PER_YEAR};

fn deploy_rate_model(
    base_rate: u256, slope1: u256, slope2: u256, optimal_util: u256,
) -> IInterestRateModelDispatcher {
    let contract = declare("InterestRateModel").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    base_rate.serialize(ref calldata);
    slope1.serialize(ref calldata);
    slope2.serialize(ref calldata);
    optimal_util.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IInterestRateModelDispatcher { contract_address: address }
}

fn default_model() -> IInterestRateModelDispatcher {
    // 2% base, 4% slope1, 75% slope2, 80% optimal
    let base_rate = RAY * 2 / 100;
    let slope1 = RAY * 4 / 100;
    let slope2 = RAY * 75 / 100;
    let optimal = 8000_u256; // 80% in BPS
    deploy_rate_model(base_rate, slope1, slope2, optimal)
}

#[test]
fn test_get_params() {
    let model = default_model();
    let (base, s1, s2, opt) = model.get_params();
    assert(base == RAY * 2 / 100, 'base rate');
    assert(s1 == RAY * 4 / 100, 'slope1');
    assert(s2 == RAY * 75 / 100, 'slope2');
    assert(opt == 8000, 'optimal');
}

#[test]
fn test_borrow_rate_zero_utilization() {
    let model = default_model();
    // No borrows => utilization = 0 => rate = base_rate / SECONDS_PER_YEAR
    let rate = model.get_borrow_rate(1000, 0);
    let expected = (RAY * 2 / 100) / SECONDS_PER_YEAR;
    assert(rate == expected, 'rate 0% util');
}

#[test]
fn test_borrow_rate_zero_deposits() {
    let model = default_model();
    // No deposits => base_rate / SECONDS_PER_YEAR
    let rate = model.get_borrow_rate(0, 0);
    let expected = (RAY * 2 / 100) / SECONDS_PER_YEAR;
    assert(rate == expected, 'rate 0 deps');
}

#[test]
fn test_borrow_rate_at_optimal() {
    let model = default_model();
    // 80% utilization = at kink
    // rate = base + slope1 = 2% + 4% = 6%
    let rate = model.get_borrow_rate(10000, 8000);
    let annual_expected = RAY * 2 / 100 + RAY * 4 / 100; // 6% RAY
    let expected = annual_expected / SECONDS_PER_YEAR;
    assert(rate == expected, 'rate at optimal');
}

#[test]
fn test_borrow_rate_above_optimal() {
    let model = default_model();
    // 100% utilization
    // rate = base + slope1 + slope2 * (10000 - 8000) / (10000 - 8000) = 2% + 4% + 75% = 81%
    let rate = model.get_borrow_rate(10000, 10000);
    let annual_expected = RAY * 2 / 100 + RAY * 4 / 100 + RAY * 75 / 100; // 81% RAY
    let expected = annual_expected / SECONDS_PER_YEAR;
    assert(rate == expected, 'rate 100% util');
}

#[test]
fn test_supply_rate_zero_deposits() {
    let model = default_model();
    let rate = model.get_supply_rate(0, 0, 1000); // 10% reserve factor
    assert(rate == 0, 'supply 0 deps');
}

#[test]
fn test_supply_rate_below_borrow_rate() {
    let model = default_model();
    // Supply rate should always be <= borrow rate
    let borrow_rate = model.get_borrow_rate(10000, 5000);
    let supply_rate = model.get_supply_rate(10000, 5000, 1000); // 10% reserve
    assert(supply_rate <= borrow_rate, 'supply <= borrow');
}

#[test]
fn test_supply_rate_with_reserve_factor() {
    let model = default_model();
    // Higher reserve factor => lower supply rate
    let supply_low_reserve = model.get_supply_rate(10000, 5000, 500); // 5% reserve
    let supply_high_reserve = model.get_supply_rate(10000, 5000, 2000); // 20% reserve
    assert(supply_low_reserve > supply_high_reserve, 'reserve impact');
}
