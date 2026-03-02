// ShieldLend — Shielded Borrow Circuit
//
// Proves:
//   1. Collateral commitment exists in the Merkle tree
//   2. Nullifier is correctly derived from commitment + secret
//   3. Borrow commitment matches Pedersen(borrow_amount, borrow_blinding)
//   4. Solvency: collateral_amount * oracle_price * ltv >= borrow_amount * PRICE_PRECISION
//   5. Amounts are within valid ranges
//
// Public inputs:  borrow_commitment, collateral_nullifier, merkle_root,
//                 oracle_price, ltv_bps, price_precision
// Private inputs: collateral_amount, collateral_blinding, borrow_amount,
//                 borrow_blinding, nullifier_secret, merkle_path, merkle_indices

use dep::std;

global TREE_DEPTH: u32 = 20;
global MAX_AMOUNT: u64 = 2_100_000_000_000_000;
global BPS_BASE: u64 = 10_000;

fn main(
    // ---- Public inputs ----
    borrow_commitment: pub Field,
    collateral_nullifier: pub Field,
    merkle_root: pub Field,
    oracle_price: pub Field,         // BTC price in USD (scaled by price_precision)
    ltv_bps: pub Field,              // e.g., 7500 = 75%
    price_precision: pub Field,      // e.g., 1e8

    // ---- Private inputs ----
    collateral_amount: Field,
    collateral_blinding: Field,
    borrow_amount: Field,
    borrow_blinding: Field,
    nullifier_secret: Field,
    merkle_path: [Field; 20],
    merkle_indices: [u1; 20],
) {
    // 1. Reconstruct collateral commitment
    let collateral_commitment = std::hash::pedersen_hash(
        [collateral_amount, collateral_blinding]
    );

    // 2. Verify collateral commitment is in the Merkle tree
    let computed_root = compute_merkle_root(
        collateral_commitment,
        merkle_path,
        merkle_indices,
    );
    assert(computed_root == merkle_root, "Invalid Merkle proof");

    // 3. Verify nullifier derivation
    let expected_nullifier = std::hash::pedersen_hash(
        [collateral_commitment, nullifier_secret]
    );
    assert(expected_nullifier == collateral_nullifier, "Invalid nullifier");

    // 4. Verify borrow commitment
    let expected_borrow = std::hash::pedersen_hash(
        [borrow_amount, borrow_blinding]
    );
    assert(expected_borrow == borrow_commitment, "Borrow commitment mismatch");

    // 5. Solvency check:
    //    collateral_amount * oracle_price * ltv_bps
    //        >= borrow_amount * price_precision * BPS_BASE
    let col_u64 = collateral_amount as u64;
    let bor_u64 = borrow_amount as u64;
    let price_u64 = oracle_price as u64;
    let ltv_u64 = ltv_bps as u64;
    let prec_u64 = price_precision as u64;

    // Use u128 to prevent overflow in multiplication
    let collateral_value: u128 = (col_u64 as u128) * (price_u64 as u128) * (ltv_u64 as u128);
    let borrow_required: u128 = (bor_u64 as u128) * (prec_u64 as u128) * (BPS_BASE as u128);

    assert(collateral_value >= borrow_required, "Insufficient collateral");

    // 6. Range checks
    assert(col_u64 > 0, "Collateral must be positive");
    assert(bor_u64 > 0, "Borrow must be positive");
    assert(col_u64 < MAX_AMOUNT, "Collateral exceeds max");
    assert(bor_u64 < MAX_AMOUNT, "Borrow exceeds max");
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
fn test_valid_borrow() {
    // Setup: 1 BTC collateral, borrow 30000 USDC at 75% LTV
    // BTC price = 60000 USD, price_precision = 1e8

    let col_amount: Field = 100_000_000;     // 1 BTC in smallest unit
    let col_blinding: Field = 111111;
    let bor_amount: Field = 30_000_000_000;  // 30000 USDC (6 decimals * some scaling)
    let bor_blinding: Field = 222222;
    let nul_secret: Field = 333333;

    let col_commitment = std::hash::pedersen_hash([col_amount, col_blinding]);
    let bor_commitment = std::hash::pedersen_hash([bor_amount, bor_blinding]);
    let nullifier = std::hash::pedersen_hash([col_commitment, nul_secret]);

    // For test: build a trivial Merkle tree with just this leaf
    let mut path = [0 as Field; 20];
    let mut indices = [0 as u1; 20];

    // Compute expected root
    let mut current = col_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    main(
        bor_commitment,
        nullifier,
        root,
        6_000_000_000_000,       // oracle_price (60000 * 1e8)
        7500,                     // ltv 75%
        100_000_000,              // price_precision 1e8
        col_amount,
        col_blinding,
        bor_amount,
        bor_blinding,
        nul_secret,
        path,
        indices,
    );
}
