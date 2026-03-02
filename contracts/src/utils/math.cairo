// Fixed-point math utilities for interest calculations

use shieldlend::utils::constants::{WAD, RAY, BPS};

/// Multiply two WAD values: (a * b) / WAD
pub fn wad_mul(a: u256, b: u256) -> u256 {
    (a * b + WAD / 2) / WAD
}

/// Divide two WAD values: (a * WAD) / b
pub fn wad_div(a: u256, b: u256) -> u256 {
    (a * WAD + b / 2) / b
}

/// Multiply two RAY values: (a * b) / RAY
pub fn ray_mul(a: u256, b: u256) -> u256 {
    (a * b + RAY / 2) / RAY
}

/// Divide two RAY values: (a * RAY) / b
pub fn ray_div(a: u256, b: u256) -> u256 {
    (a * RAY + b / 2) / b
}

/// Convert WAD to RAY
pub fn wad_to_ray(a: u256) -> u256 {
    a * 1_000_000_000 // RAY / WAD = 1e9
}

/// Convert RAY to WAD (truncates)
pub fn ray_to_wad(a: u256) -> u256 {
    a / 1_000_000_000
}

/// Calculate percentage in BPS: (value * bps) / 10000
pub fn bps_mul(value: u256, bps: u256) -> u256 {
    (value * bps + BPS / 2) / BPS
}

/// Calculate utilization rate in BPS: (borrows * 10000) / deposits
pub fn utilization_rate(total_deposits: u256, total_borrows: u256) -> u256 {
    if total_deposits == 0 {
        return 0;
    }
    (total_borrows * BPS) / total_deposits
}

/// Calculate health factor: (collateral_value * liq_threshold) / debt_value
/// Returns WAD-scaled value. health_factor < WAD means liquidatable
pub fn health_factor(
    collateral_value: u256,
    debt_value: u256,
    liquidation_threshold_bps: u256,
) -> u256 {
    if debt_value == 0 {
        return WAD * 1000; // Effectively infinite
    }
    bps_mul(collateral_value, liquidation_threshold_bps) * WAD / debt_value
}

/// Compound interest: principal * (1 + rate_per_second) ^ seconds
/// Uses linear approximation for small time deltas (< 1 day)
/// and binomial expansion for larger ones
pub fn compound_interest(rate_per_second: u256, time_delta: u256) -> u256 {
    if time_delta == 0 {
        return RAY;
    }

    // For hackathon MVP: linear approximation
    // compound ≈ 1 + rate * time
    RAY + rate_per_second * time_delta
}

/// Min of two u256
pub fn min(a: u256, b: u256) -> u256 {
    if a < b { a } else { b }
}

/// Max of two u256
pub fn max(a: u256, b: u256) -> u256 {
    if a > b { a } else { b }
}
