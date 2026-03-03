use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const};

// ===== Commitment Store Tests =====

use shieldlend::privacy::commitment_store::{
    ICommitmentStoreDispatcher, ICommitmentStoreDispatcherTrait,
};

fn POOL() -> ContractAddress {
    contract_address_const::<'pool'>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn deploy_commitment_store() -> ICommitmentStoreDispatcher {
    let contract = declare("CommitmentStore").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    POOL().serialize(ref calldata); // authorized_pool
    let (address, _) = contract.deploy(@calldata).unwrap();
    ICommitmentStoreDispatcher { contract_address: address }
}

#[test]
fn test_initial_state() {
    let cs = deploy_commitment_store();
    assert(cs.get_next_index() == 0, 'initial index 0');
    assert(cs.get_commitment_count() == 0, 'initial count 0');
    // Root should be non-zero (precomputed zeros hash)
    let root = cs.get_root();
    assert(cs.is_known_root(root), 'initial root valid');
}

#[test]
fn test_insert_commitment() {
    let cs = deploy_commitment_store();

    // Insert a commitment (anyone can call insert in the current impl)
    let commitment: felt252 = 0x1234567890abcdef;
    let leaf_index = cs.insert(commitment);

    assert(leaf_index == 0, 'first leaf index');
    assert(cs.get_next_index() == 1, 'next index after insert');
    assert(cs.get_commitment_count() == 1, 'count after insert');

    // Root should have changed
    let new_root = cs.get_root();
    assert(cs.is_known_root(new_root), 'new root valid');
}

#[test]
fn test_multiple_insertions() {
    let cs = deploy_commitment_store();

    let idx0 = cs.insert(0x111);
    let idx1 = cs.insert(0x222);
    let idx2 = cs.insert(0x333);

    assert(idx0 == 0, 'idx0');
    assert(idx1 == 1, 'idx1');
    assert(idx2 == 2, 'idx2');
    assert(cs.get_commitment_count() == 3, 'count 3');
}

#[test]
fn test_root_history() {
    let cs = deploy_commitment_store();

    let root0 = cs.get_root();
    cs.insert(0x111);
    let root1 = cs.get_root();
    cs.insert(0x222);
    let root2 = cs.get_root();

    // All historical roots should be recognized
    assert(cs.is_known_root(root0), 'root0 known');
    assert(cs.is_known_root(root1), 'root1 known');
    assert(cs.is_known_root(root2), 'root2 known');

    // Random value should not be a known root
    assert(!cs.is_known_root(0x999), 'random not known');
}

// ===== Nullifier Registry Tests =====

use shieldlend::privacy::nullifier_registry::{
    INullifierRegistryDispatcher, INullifierRegistryDispatcherTrait,
};

fn deploy_nullifier_registry() -> INullifierRegistryDispatcher {
    let contract = declare("NullifierRegistry").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    INullifierRegistryDispatcher { contract_address: address }
}

#[test]
fn test_nullifier_initial() {
    let nr = deploy_nullifier_registry();
    assert(!nr.is_spent(0x123), 'not spent initially');
}

#[test]
fn test_nullifier_batch_check() {
    let nr = deploy_nullifier_registry();

    // Test batch check — all should be unspent
    let nullifiers = array![0x111, 0x222, 0x333];
    let results = nr.are_spent(nullifiers);
    assert(*results.at(0) == false, 'batch 0');
    assert(*results.at(1) == false, 'batch 1');
    assert(*results.at(2) == false, 'batch 2');
}

#[test]
fn test_nullifier_is_spent_default() {
    let nr = deploy_nullifier_registry();
    assert(!nr.is_spent(0xDEAD), 'default unspent');
    assert(!nr.is_spent(0xBEEF), 'default unspent 2');
}

// ===== ZK Verifier Tests =====

use shieldlend::privacy::zk_verifier::{
    IZkVerifierDispatcher, IZkVerifierDispatcherTrait,
};

fn deploy_verifier() -> IZkVerifierDispatcher {
    let contract = declare("ZkVerifier").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IZkVerifierDispatcher { contract_address: address }
}

#[test]
fn test_verifier_circuit_supported() {
    let v = deploy_verifier();
    assert(v.is_circuit_supported(0), 'deposit supported');
    assert(v.is_circuit_supported(1), 'borrow supported');
    assert(v.is_circuit_supported(2), 'withdraw supported');
    assert(v.is_circuit_supported(3), 'solvency supported');
    assert(!v.is_circuit_supported(99), 'unknown not supported');
}

#[test]
fn test_verifier_mock_deposit_proof() {
    let v = deploy_verifier();

    // Circuit 0 (shielded_deposit) expects 1 public input (commitment)
    let proof: Array<felt252> = array![0x1]; // non-empty proof
    let public_inputs: Array<felt252> = array![0xABC]; // commitment

    let result = v.verify_proof(0, proof.span(), public_inputs.span());
    assert(result, 'deposit proof valid');
}

#[test]
fn test_verifier_mock_borrow_proof() {
    let v = deploy_verifier();

    // Circuit 1 (shielded_borrow) expects 6 public inputs
    let proof: Array<felt252> = array![0x1];
    let public_inputs: Array<felt252> = array![
        0xAAA, // borrow_commitment
        0xBBB, // nullifier
        0xCCC, // merkle_root
        0xDDD, // oracle_price
        0xEEE, // ltv_bps
        0xFFF, // price_precision
    ];

    let result = v.verify_proof(1, proof.span(), public_inputs.span());
    assert(result, 'borrow proof valid');
}

#[test]
fn test_verifier_mock_withdraw_proof() {
    let v = deploy_verifier();

    // Circuit 2 (shielded_withdraw) expects 3 public inputs
    let proof: Array<felt252> = array![0x1];
    let public_inputs: Array<felt252> = array![
        0xAAA, // nullifier
        0xBBB, // change_commitment
        0xCCC, // merkle_root
    ];

    let result = v.verify_proof(2, proof.span(), public_inputs.span());
    assert(result, 'withdraw proof valid');
}

#[test]
fn test_verifier_empty_proof_fails() {
    let v = deploy_verifier();

    let proof: Array<felt252> = array![];
    let public_inputs: Array<felt252> = array![0xABC];

    let result = v.verify_proof(0, proof.span(), public_inputs.span());
    assert(!result, 'empty proof fails');
}

#[test]
fn test_verifier_insufficient_inputs_fails() {
    let v = deploy_verifier();

    // Circuit 1 expects 6 inputs, only provide 2
    let proof: Array<felt252> = array![0x1];
    let public_inputs: Array<felt252> = array![0xAAA, 0xBBB];

    let result = v.verify_proof(1, proof.span(), public_inputs.span());
    assert(!result, 'too few inputs fails');
}

#[test]
fn test_verifier_solvency_proof() {
    let v = deploy_verifier();

    // Circuit 3 (solvency) expects 2 public inputs
    let proof: Array<felt252> = array![0x1];
    let public_inputs: Array<felt252> = array![0xAAA, 0xBBB]; // commitment, threshold

    let result = v.verify_proof(3, proof.span(), public_inputs.span());
    assert(result, 'solvency proof valid');
}

// ===== Shielded Account Tests =====

use shieldlend::privacy::shielded_account::{
    IShieldedAccountDispatcher, IShieldedAccountDispatcherTrait,
};

fn deploy_shielded_account() -> IShieldedAccountDispatcher {
    let contract = declare("ShieldedAccount").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IShieldedAccountDispatcher { contract_address: address }
}

#[test]
fn test_store_and_get_note() {
    let sa = deploy_shielded_account();

    let commitment: felt252 = 0xDEADBEEF;
    let encrypted: felt252 = 0x12345;

    // Store as owner (authorized)
    start_cheat_caller_address(sa.contract_address, OWNER());
    sa.store_note(commitment, encrypted, 0, POOL(), 42);

    let note = sa.get_note(commitment);
    assert(note.commitment == commitment, 'note commitment');
    assert(note.encrypted_amount == encrypted, 'note encrypted');
    assert(note.note_type == 0, 'note type deposit');
    assert(note.pool == POOL(), 'note pool');
    assert(note.leaf_index == 42, 'note leaf index');
}

#[test]
fn test_user_note_tracking() {
    let sa = deploy_shielded_account();

    start_cheat_caller_address(sa.contract_address, OWNER());
    sa.store_note(0xAAA, 0x111, 0, POOL(), 0);
    sa.store_note(0xBBB, 0x222, 1, POOL(), 1);

    // Notes are tracked under the caller (OWNER in this case)
    let count = sa.get_user_note_count(OWNER());
    assert(count == 2, 'note count 2');

    let first = sa.get_user_note(OWNER(), 0);
    assert(first == 0xAAA, 'first note');

    let second = sa.get_user_note(OWNER(), 1);
    assert(second == 0xBBB, 'second note');
}

#[test]
#[should_panic(expected: 'SL: not authorized')]
fn test_store_note_unauthorized() {
    let sa = deploy_shielded_account();
    let attacker = contract_address_const::<'attacker'>();

    start_cheat_caller_address(sa.contract_address, attacker);
    sa.store_note(0xAAA, 0x111, 0, POOL(), 0);
}
