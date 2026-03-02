// Protocol pub constants

// Precision
pub const WAD: u256 = 1_000_000_000_000_000_000;           // 1e18
pub const RAY: u256 = 1_000_000_000_000_000_000_000_000_000; // 1e27
pub const BPS: u256 = 10_000;                               // Basis points denominator

// Interest Rate Model defaults
pub const DEFAULT_BASE_RATE: u256 = 20_000_000_000_000_000_000_000_000;   // 2% in RAY
pub const DEFAULT_SLOPE1: u256 = 40_000_000_000_000_000_000_000_000;      // 4% in RAY
pub const DEFAULT_SLOPE2: u256 = 750_000_000_000_000_000_000_000_000;     // 75% in RAY
pub const DEFAULT_OPTIMAL_UTILIZATION: u256 = 8_000;                       // 80% in BPS

// Risk parameters
pub const MIN_LTV_BPS: u256 = 1_000;           // 10%
pub const MAX_LTV_BPS: u256 = 9_500;           // 95% (eMode max)
pub const MIN_LIQUIDATION_BONUS_BPS: u256 = 100;  // 1%
pub const MAX_LIQUIDATION_BONUS_BPS: u256 = 1_500; // 15%

// Flash loan
pub const FLASH_LOAN_FEE_BPS: u256 = 9;       // 0.09%

// Privacy
pub const MERKLE_TREE_DEPTH: u32 = 20;         // ~1M leaf capacity
pub const ZERO_VALUE: felt252 = 0;             // Empty leaf value

// eMode
pub const EMODE_LTV_BPS: u256 = 9_500;        // 95% for correlated assets
pub const EMODE_LIQUIDATION_THRESHOLD_BPS: u256 = 9_700; // 97%
pub const EMODE_LIQUIDATION_BONUS_BPS: u256 = 100; // 1%

// Seconds per year (for APR calculations)
pub const SECONDS_PER_YEAR: u256 = 31_536_000;
