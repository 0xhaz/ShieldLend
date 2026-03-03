// ShieldLend — Solvency Proof Circuit
//
// Proves that a shielded position is healthy without revealing amounts.
//
// Proves:
//   1. The collateral commitment exists in the Merkle tree
//   2. The debt commitment exists (or is provided)
//   3. health_factor = (collateral_value * liq_threshold) / debt_value >= 1
//   4. All amounts are within valid ranges
//
// Public inputs:  collateral_merkle_root, debt_commitment, oracle_price,
//                 liquidation_threshold_bps, price_precision
// Private inputs: collateral_amount, collateral_blinding, debt_amount,
//                 debt_blinding, merkle_path, merkle_indices

use dep::std;

global TREE_DEPTH: u32 = 20;
global MAX_AMOUNT: u64 = 2_100_000_000_000_000;
global BPS_BASE: u64 = 10_000;

fn main(
    // ---- Public inputs ----
    collateral_merkle_root: pub Field,
    debt_commitment: pub Field,
    oracle_price: pub Field,
    liquidation_threshold_bps: pub Field,
    price_precision: pub Field,

    // ---- Private inputs ----
    collateral_amount: Field,
    collateral_blinding: Field,
    debt_amount: Field,
    debt_blinding: Field,
    merkle_path: [Field; 20],
    merkle_indices: [u1; 20],
) {
    // 1. Verify collateral commitment is in the Merkle tree
    let collateral_commitment = std::hash::pedersen_hash(
        [collateral_amount, collateral_blinding],
    );
    let computed_root = compute_merkle_root(collateral_commitment, merkle_path, merkle_indices);
    assert(computed_root == collateral_merkle_root, "Invalid collateral Merkle proof");

    // 2. Verify debt commitment
    let expected_debt_commitment = std::hash::pedersen_hash([debt_amount, debt_blinding]);
    assert(expected_debt_commitment == debt_commitment, "Debt commitment mismatch");

    // 3. Solvency check: collateral_value * liq_threshold >= debt_value * BPS_BASE
    let col_u64 = collateral_amount as u64;
    let debt_u64 = debt_amount as u64;
    let price_u64 = oracle_price as u64;
    let liq_u64 = liquidation_threshold_bps as u64;
    let prec_u64 = price_precision as u64;

    // collateral_value = collateral_amount * oracle_price * liq_threshold
    // debt_value = debt_amount * price_precision * BPS_BASE
    let collateral_value: u128 = (col_u64 as u128) * (price_u64 as u128) * (liq_u64 as u128);
    let debt_value: u128 = (debt_u64 as u128) * (prec_u64 as u128) * (BPS_BASE as u128);

    assert(collateral_value >= debt_value, "Position is undercollateralized");

    // 4. Range checks
    assert(col_u64 > 0, "Collateral must be positive");
    assert(debt_u64 > 0, "Debt must be positive");
    assert(col_u64 < MAX_AMOUNT, "Collateral exceeds max");
    assert(debt_u64 < MAX_AMOUNT, "Debt exceeds max");
}

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
fn test_solvent_position() {
    // 1 BTC collateral @ $60,000, 30,000 USDC debt, 80% liq threshold
    let col_amount: Field = 100_000_000;
    let col_blinding: Field = 111111;
    let debt_amount: Field = 30_000_000_000;
    let debt_blinding: Field = 222222;

    let col_commitment = std::hash::pedersen_hash([col_amount, col_blinding]);
    let debt_commitment = std::hash::pedersen_hash([debt_amount, debt_blinding]);

    let path = [0 as Field; 20];
    let indices = [0 as u1; 20];

    let mut current = col_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    main(
        root,
        debt_commitment,
        6_000_000_000_000,  // price: 60000 * 1e8
        8000,               // 80% liq threshold
        100_000_000,        // 1e8 precision
        col_amount,
        col_blinding,
        debt_amount,
        debt_blinding,
        path,
        indices,
    );
}

#[test(should_fail_with = "Position is undercollateralized")]
fn test_undercollateralized() {
    // 1 BTC collateral @ $60,000, 55,000 USDC debt, 80% liq threshold
    // collateral_value = 100M * 6T * 8000 = 4.8e18
    // debt_value = 55B * 100M * 10000 = 5.5e22 — this should fail
    let col_amount: Field = 100_000_000;
    let col_blinding: Field = 111111;
    let debt_amount: Field = 55_000_000_000;
    let debt_blinding: Field = 222222;

    let col_commitment = std::hash::pedersen_hash([col_amount, col_blinding]);
    let debt_commitment = std::hash::pedersen_hash([debt_amount, debt_blinding]);

    let path = [0 as Field; 20];
    let indices = [0 as u1; 20];

    let mut current = col_commitment;
    for i in 0..20 {
        current = std::hash::pedersen_hash([current, 0]);
    }
    let root = current;

    main(
        root,
        debt_commitment,
        6_000_000_000_000,
        8000,
        100_000_000,
        col_amount,
        col_blinding,
        debt_amount,
        debt_blinding,
        path,
        indices,
    );
}
