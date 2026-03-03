use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const};
use shieldlend::oracle::pragma_adapter::{
    IPragmaAdapterDispatcher, IPragmaAdapterDispatcherTrait,
};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn ASSET_A() -> ContractAddress {
    contract_address_const::<'asset_a'>()
}

fn ASSET_B() -> ContractAddress {
    contract_address_const::<'asset_b'>()
}

fn deploy_oracle() -> IPragmaAdapterDispatcher {
    let contract = declare("PragmaAdapter").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IPragmaAdapterDispatcher { contract_address: address }
}

#[test]
fn test_set_and_get_price() {
    let oracle = deploy_oracle();
    let price: u256 = 5000_00000000; // $5000 with 8 decimals

    start_cheat_caller_address(oracle.contract_address, OWNER());
    oracle.set_price(ASSET_A(), price);

    let fetched = oracle.get_price(ASSET_A());
    assert(fetched == price, 'price mismatch');
}

#[test]
fn test_price_precision() {
    let oracle = deploy_oracle();
    let precision = oracle.get_price_precision();
    assert(precision == 100_000_000, 'precision 1e8');
}

#[test]
fn test_multiple_assets() {
    let oracle = deploy_oracle();

    start_cheat_caller_address(oracle.contract_address, OWNER());
    oracle.set_price(ASSET_A(), 5000_00000000); // BTC $50k
    oracle.set_price(ASSET_B(), 1_00000000); // USDC $1

    let price_a = oracle.get_price(ASSET_A());
    let price_b = oracle.get_price(ASSET_B());
    assert(price_a == 5000_00000000, 'asset a price');
    assert(price_b == 1_00000000, 'asset b price');
}

#[test]
fn test_update_price() {
    let oracle = deploy_oracle();

    start_cheat_caller_address(oracle.contract_address, OWNER());
    oracle.set_price(ASSET_A(), 5000_00000000);
    oracle.set_price(ASSET_A(), 5500_00000000); // Price goes up

    let price = oracle.get_price(ASSET_A());
    assert(price == 5500_00000000, 'updated price');
}

#[test]
#[should_panic(expected: 'SL: price not available')]
fn test_get_unset_price_panics() {
    let oracle = deploy_oracle();
    oracle.get_price(ASSET_A()); // Never set
}

#[test]
#[should_panic(expected: 'SL: not authorized')]
fn test_set_price_unauthorized() {
    let oracle = deploy_oracle();
    let non_owner = contract_address_const::<'attacker'>();

    start_cheat_caller_address(oracle.contract_address, non_owner);
    oracle.set_price(ASSET_A(), 5000_00000000);
}
