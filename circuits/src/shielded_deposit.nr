// ShieldLend — Shielded Deposit Circuit
//
// Proves:
//   1. The commitment matches Pedersen(amount, blinding_factor)
//   2. The amount is within a valid range (> 0, < MAX_AMOUNT)
//   3. The depositor knows the preimage (amount + blinding)
//
// Public inputs:  commitment
// Private inputs: amount, blinding_factor

use dep::std;

// Maximum deposit amount (prevents overflow): 21M BTC in satoshi-like units
global MAX_AMOUNT: u64 = 2_100_000_000_000_000;

fn main(
    // Public inputs — visible on-chain
    commitment: pub Field,

    // Private inputs — known only to depositor
    amount: Field,
    blinding_factor: Field,
) {
    // 1. Verify commitment = Pedersen(amount, blinding_factor)
    let computed_commitment = std::hash::pedersen_hash([amount, blinding_factor]);
    assert(computed_commitment == commitment, "Commitment mismatch");

    // 2. Range check: amount > 0
    let amount_u64 = amount as u64;
    assert(amount_u64 > 0, "Amount must be positive");

    // 3. Range check: amount < MAX_AMOUNT
    assert(amount_u64 < MAX_AMOUNT, "Amount exceeds maximum");
}

#[test]
fn test_valid_deposit() {
    let amount: Field = 100_000_000; // 1 BTC (in satoshi-like units)
    let blinding: Field = 12345678901234567890;
    let commitment = std::hash::pedersen_hash([amount, blinding]);

    main(commitment, amount, blinding);
}

#[test(should_fail_with = "Amount must be positive")]
fn test_zero_amount() {
    let amount: Field = 0;
    let blinding: Field = 12345678901234567890;
    let commitment = std::hash::pedersen_hash([amount, blinding]);

    main(commitment, amount, blinding);
}

#[test(should_fail_with = "Commitment mismatch")]
fn test_wrong_commitment() {
    let amount: Field = 100_000_000;
    let blinding: Field = 12345678901234567890;
    let wrong_commitment: Field = 999;

    main(wrong_commitment, amount, blinding);
}
