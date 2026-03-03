// ShieldLend — Shielded Withdraw Circuit
//
// Proves:
//   1. The deposit commitment exists in the Merkle tree (via root)
//   2. The nullifier is correctly derived from commitment + secret
//   3. The withdrawal amount <= deposited amount
//   4. A change commitment is correctly formed for the remaining balance
//   5. Amounts are within valid ranges
//
// Public inputs:  nullifier, change_commitment, merkle_root, withdraw_amount_commitment
// Private inputs: deposit_amount, deposit_blinding, withdraw_amount, change_amount,
//                 change_blinding, nullifier_secret, merkle_path, merkle_indices

use dep::std;

global TREE_DEPTH: u32 = 20;
global MAX_AMOUNT: u64 = 2_100_000_000_000_000;

fn main(
    // ---- Public inputs ----
    nullifier: pub Field,
    change_commitment: pub Field,   // Commitment to remaining balance (0 if full withdraw)
    merkle_root: pub Field,

    // ---- Private inputs ----
    deposit_amount: Field,
    deposit_blinding: Field,
    withdraw_amount: Field,
    change_amount: Field,
    change_blinding: Field,
    nullifier_secret: Field,
    merkle_path: [Field; 20],
    merkle_indices: [u1; 20],
) {
    // 1. Reconstruct deposit commitment
    let deposit_commitment = std::hash::pedersen_hash([deposit_amount, deposit_blinding]);

    // 2. Verify deposit commitment is in the Merkle tree
    let computed_root = compute_merkle_root(deposit_commitment, merkle_path, merkle_indices);
    assert(computed_root == merkle_root, "Invalid Merkle proof");

    // 3. Verify nullifier derivation: nullifier = H(commitment, secret)
    let expected_nullifier = std::hash::pedersen_hash([deposit_commitment, nullifier_secret]);
    assert(expected_nullifier == nullifier, "Invalid nullifier");

    // 4. Verify amounts: withdraw + change = deposit
    let dep_u64 = deposit_amount as u64;
    let wit_u64 = withdraw_amount as u64;
    let chg_u64 = change_amount as u64;

    assert(wit_u64 > 0, "Withdraw amount must be positive");
    assert(wit_u64 <= dep_u64, "Withdraw exceeds deposit");
    assert(wit_u64 + chg_u64 == dep_u64, "Amounts don't balance");

    // 5. Verify change commitment (if there's a remaining balance)
    if chg_u64 > 0 {
        let expected_change = std::hash::pedersen_hash([change_amount, change_blinding]);
        assert(expected_change == change_commitment, "Change commitment mismatch");
    }

    // 6. Range checks
    assert(dep_u64 < MAX_AMOUNT, "Deposit exceeds max");
    assert(wit_u64 < MAX_AMOUNT, "Withdraw exceeds max");
}

/// Compute Merkle root from a leaf and its authentication path
fn compute_merkle_root(
    leaf: Field,
    path: [Field; 20],
    indices: [u1; 20],
) -> Field {
    let mut current = leaf;
    for i in 0..20 {
        let (left, right) = if indices[i] == 0 {
            (current, path[i])
        } else {
            (path[i], current)
        };
        current = std::hash::pedersen_hash([left, right]);
    }
    current
}

#[test]
fn test_full_withdraw() {
    let deposit_amount: Field = 100_000_000; // 1 BTC
    let deposit_blinding: Field = 111111;
    let withdraw_amount: Field = 100_000_000; // Full withdraw
    let change_amount: Field = 0;
    let change_blinding: Field = 0;
    let nul_secret: Field = 333333;

    let deposit_commitment = std::hash::pedersen_hash([deposit_amount, deposit_blinding]);
    let nullifier = std::hash::pedersen_hash([deposit_commitment, nul_secret]);

    // Build trivial Merkle path
    let path = [0 as Field; 20];
    let indices = [0 as u1; 20];

    // Compute expected root
    let mut current = deposit_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    // Change commitment = 0 for full withdraw (won't be checked since change_amount == 0)
    let change_commitment: Field = 0;

    main(
        nullifier,
        change_commitment,
        root,
        deposit_amount,
        deposit_blinding,
        withdraw_amount,
        change_amount,
        change_blinding,
        nul_secret,
        path,
        indices,
    );
}

#[test]
fn test_partial_withdraw() {
    let deposit_amount: Field = 100_000_000; // 1 BTC
    let deposit_blinding: Field = 111111;
    let withdraw_amount: Field = 60_000_000;  // 0.6 BTC
    let change_amount: Field = 40_000_000;    // 0.4 BTC remaining
    let change_blinding: Field = 222222;
    let nul_secret: Field = 333333;

    let deposit_commitment = std::hash::pedersen_hash([deposit_amount, deposit_blinding]);
    let nullifier = std::hash::pedersen_hash([deposit_commitment, nul_secret]);
    let change_commitment = std::hash::pedersen_hash([change_amount, change_blinding]);

    let path = [0 as Field; 20];
    let indices = [0 as u1; 20];

    let mut current = deposit_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    main(
        nullifier,
        change_commitment,
        root,
        deposit_amount,
        deposit_blinding,
        withdraw_amount,
        change_amount,
        change_blinding,
        nul_secret,
        path,
        indices,
    );
}

#[test(should_fail_with = "Withdraw exceeds deposit")]
fn test_withdraw_exceeds_deposit() {
    let deposit_amount: Field = 100_000_000;
    let deposit_blinding: Field = 111111;
    let withdraw_amount: Field = 200_000_000; // More than deposited
    let change_amount: Field = 0;
    let change_blinding: Field = 0;
    let nul_secret: Field = 333333;

    let deposit_commitment = std::hash::pedersen_hash([deposit_amount, deposit_blinding]);
    let nullifier = std::hash::pedersen_hash([deposit_commitment, nul_secret]);

    let path = [0 as Field; 20];
    let indices = [0 as u1; 20];

    let mut current = deposit_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    main(
        nullifier, 0, root,
        deposit_amount, deposit_blinding,
        withdraw_amount, change_amount, change_blinding,
        nul_secret, path, indices,
    );
}
