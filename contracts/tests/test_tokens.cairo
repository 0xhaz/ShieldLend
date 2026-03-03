use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const};
use shieldlend::tokens::sl_token::{ISlTokenDispatcher, ISlTokenDispatcherTrait};
use shieldlend::tokens::debt_token::{IDebtTokenDispatcher, IDebtTokenDispatcherTrait};

fn POOL() -> ContractAddress {
    contract_address_const::<'pool'>()
}

fn USER() -> ContractAddress {
    contract_address_const::<'user'>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<'user2'>()
}

// ===== SlToken Tests =====

fn deploy_sl_token() -> ISlTokenDispatcher {
    let contract = declare("SlToken").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "ShieldLend BTC";
    let symbol: ByteArray = "slBTC";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    POOL().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    ISlTokenDispatcher { contract_address: address }
}

#[test]
fn test_sl_token_mint() {
    let sl = deploy_sl_token();

    start_cheat_caller_address(sl.contract_address, POOL());
    sl.mint(USER(), 1000);

    // Verify pool address
    assert(sl.pool() == POOL(), 'pool address');
}

#[test]
fn test_sl_token_mint_and_burn() {
    let sl = deploy_sl_token();

    start_cheat_caller_address(sl.contract_address, POOL());
    sl.mint(USER(), 1000);
    sl.burn(USER(), 400);
}

#[test]
#[should_panic(expected: 'SL: only pool')]
fn test_sl_token_mint_unauthorized() {
    let sl = deploy_sl_token();
    let attacker = contract_address_const::<'attacker'>();

    start_cheat_caller_address(sl.contract_address, attacker);
    sl.mint(USER(), 1000);
}

#[test]
#[should_panic(expected: 'SL: only pool')]
fn test_sl_token_burn_unauthorized() {
    let sl = deploy_sl_token();

    // First mint as pool
    start_cheat_caller_address(sl.contract_address, POOL());
    sl.mint(USER(), 1000);

    // Try burn as non-pool
    let attacker = contract_address_const::<'attacker'>();
    start_cheat_caller_address(sl.contract_address, attacker);
    sl.burn(USER(), 500);
}

// ===== DebtToken Tests =====

fn deploy_debt_token() -> IDebtTokenDispatcher {
    let contract = declare("DebtToken").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "ShieldLend BTC Debt";
    let symbol: ByteArray = "debtBTC";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    POOL().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IDebtTokenDispatcher { contract_address: address }
}

#[test]
fn test_debt_token_mint() {
    let dt = deploy_debt_token();

    start_cheat_caller_address(dt.contract_address, POOL());
    dt.mint(USER(), 500);

    let balance = dt.balance_of(USER());
    assert(balance == 500, 'debt balance');
}

#[test]
fn test_debt_token_total_supply() {
    let dt = deploy_debt_token();

    start_cheat_caller_address(dt.contract_address, POOL());
    dt.mint(USER(), 500);
    dt.mint(USER2(), 300);

    let supply = dt.total_supply();
    assert(supply == 800, 'total supply');
}

#[test]
fn test_debt_token_burn() {
    let dt = deploy_debt_token();

    start_cheat_caller_address(dt.contract_address, POOL());
    dt.mint(USER(), 500);
    dt.burn(USER(), 200);

    let balance = dt.balance_of(USER());
    assert(balance == 300, 'after burn');
}

#[test]
fn test_debt_token_pool_address() {
    let dt = deploy_debt_token();
    assert(dt.pool() == POOL(), 'pool addr');
}

#[test]
#[should_panic(expected: 'SL: only pool')]
fn test_debt_token_mint_unauthorized() {
    let dt = deploy_debt_token();
    let attacker = contract_address_const::<'attacker'>();

    start_cheat_caller_address(dt.contract_address, attacker);
    dt.mint(USER(), 500);
}

#[test]
#[should_panic(expected: 'SL: only pool')]
fn test_debt_token_burn_unauthorized() {
    let dt = deploy_debt_token();

    start_cheat_caller_address(dt.contract_address, POOL());
    dt.mint(USER(), 500);

    let attacker = contract_address_const::<'attacker'>();
    start_cheat_caller_address(dt.contract_address, attacker);
    dt.burn(USER(), 200);
}
