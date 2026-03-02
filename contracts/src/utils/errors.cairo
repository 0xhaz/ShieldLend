// Custom error codes for ShieldLend

pub mod Errors {
    // Market Factory
    pub const MARKET_ALREADY_EXISTS: felt252 = 'SL: market already exists';
    pub const INVALID_LTV: felt252 = 'SL: invalid LTV';
    pub const INVALID_LIQUIDATION_PARAMS: felt252 = 'SL: invalid liq params';
    pub const ZERO_ADDRESS: felt252 = 'SL: zero address';

    // Lending Pool
    pub const MARKET_NOT_ACTIVE: felt252 = 'SL: market not active';
    pub const INSUFFICIENT_COLLATERAL: felt252 = 'SL: insufficient collateral';
    pub const INSUFFICIENT_LIQUIDITY: felt252 = 'SL: insufficient liquidity';
    pub const HEALTH_FACTOR_OK: felt252 = 'SL: cannot liquidate healthy';
    pub const AMOUNT_ZERO: felt252 = 'SL: amount is zero';
    pub const POSITION_NOT_FOUND: felt252 = 'SL: position not found';
    pub const TRANSFER_FAILED: felt252 = 'SL: transfer failed';

    // Privacy
    pub const INVALID_PROOF: felt252 = 'SL: invalid ZK proof';
    pub const NULLIFIER_ALREADY_USED: felt252 = 'SL: nullifier used';
    pub const COMMITMENT_NOT_FOUND: felt252 = 'SL: commitment not found';
    pub const INVALID_MERKLE_ROOT: felt252 = 'SL: invalid merkle root';

    // Flash Loan
    pub const FLASH_LOAN_NOT_REPAID: felt252 = 'SL: flash loan not repaid';
    pub const FLASH_LOAN_CALLBACK_FAILED: felt252 = 'SL: callback failed';

    // Yield Tokenizer
    pub const MATURITY_IN_PAST: felt252 = 'SL: maturity in past';
    pub const NOT_MATURED: felt252 = 'SL: not yet matured';
    pub const INVALID_PT_YT_AMOUNTS: felt252 = 'SL: PT/YT mismatch';

    // Access
    pub const NOT_AUTHORIZED: felt252 = 'SL: not authorized';
    pub const ONLY_POOL: felt252 = 'SL: only pool';
}
