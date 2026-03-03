use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const};
use shieldlend::core::market_factory::{
    IMarketFactoryDispatcher, IMarketFactoryDispatcherTrait,
};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn POOL() -> ContractAddress {
    contract_address_const::<'pool'>()
}

fn COL_TOKEN() -> ContractAddress {
    contract_address_const::<'collateral'>()
}

fn LOAN_TOKEN() -> ContractAddress {
    contract_address_const::<'loan'>()
}

fn deploy_factory() -> IMarketFactoryDispatcher {
    let contract = declare("MarketFactory").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IMarketFactoryDispatcher { contract_address: address }
}

#[test]
fn test_initial_market_count() {
    let factory = deploy_factory();
    assert(factory.get_market_count() == 0, 'initial count 0');
}

#[test]
fn test_register_market() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    let market_id = factory.register_market(
        POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000, // 75% LTV, 80% liq threshold
    );

    assert(market_id == 1, 'first market id');
    assert(factory.get_market_count() == 1, 'count after register');
}

#[test]
fn test_get_market() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);

    let market = factory.get_market(1);
    assert(market.market_id == 1, 'market id');
    assert(market.pool_address == POOL(), 'pool addr');
    assert(market.collateral_token == COL_TOKEN(), 'col token');
    assert(market.loan_token == LOAN_TOKEN(), 'loan token');
    assert(market.ltv_bps == 7500, 'ltv');
    assert(market.liquidation_threshold_bps == 8000, 'liq threshold');
    assert(market.is_active, 'is active');
}

#[test]
fn test_get_market_by_tokens() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);

    let market = factory.get_market_by_tokens(COL_TOKEN(), LOAN_TOKEN());
    assert(market.market_id == 1, 'lookup by tokens');
    assert(market.pool_address == POOL(), 'pool addr');
}

#[test]
fn test_multiple_markets() {
    let factory = deploy_factory();
    let pool2 = contract_address_const::<'pool2'>();
    let col2 = contract_address_const::<'col2'>();
    let loan2 = contract_address_const::<'loan2'>();

    start_cheat_caller_address(factory.contract_address, OWNER());
    let id1 = factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);
    let id2 = factory.register_market(pool2, col2, loan2, 6000, 7000);

    assert(id1 == 1, 'first id');
    assert(id2 == 2, 'second id');
    assert(factory.get_market_count() == 2, 'count 2');
}

#[test]
#[should_panic(expected: 'SL: not authorized')]
fn test_register_unauthorized() {
    let factory = deploy_factory();
    let attacker = contract_address_const::<'attacker'>();

    start_cheat_caller_address(factory.contract_address, attacker);
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);
}

#[test]
#[should_panic(expected: 'SL: invalid LTV')]
fn test_invalid_ltv_too_low() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 500, 8000); // 5% < MIN_LTV 10%
}

#[test]
#[should_panic(expected: 'SL: invalid LTV')]
fn test_invalid_ltv_too_high() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 9800, 9900); // 98% > MAX_LTV 95%
}

#[test]
#[should_panic(expected: 'SL: invalid liq params')]
fn test_liq_threshold_must_exceed_ltv() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 8000, 7500); // threshold < ltv
}

#[test]
#[should_panic(expected: 'SL: market already exists')]
fn test_duplicate_market() {
    let factory = deploy_factory();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);
    factory.register_market(POOL(), COL_TOKEN(), LOAN_TOKEN(), 6000, 7000); // same pair
}

#[test]
#[should_panic(expected: 'SL: zero address')]
fn test_zero_pool_address() {
    let factory = deploy_factory();
    let zero = contract_address_const::<0>();

    start_cheat_caller_address(factory.contract_address, OWNER());
    factory.register_market(zero, COL_TOKEN(), LOAN_TOKEN(), 7500, 8000);
}

#[test]
#[should_panic(expected: 'SL: invalid market')]
fn test_get_invalid_market() {
    let factory = deploy_factory();
    factory.get_market(99);
}
