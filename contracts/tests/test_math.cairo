use shieldlend::utils::constants::{WAD, RAY, BPS};
use shieldlend::utils::math::{
    wad_mul, wad_div, ray_mul, ray_div,
    wad_to_ray, ray_to_wad, bps_mul,
    utilization_rate, health_factor, compound_interest,
    min, max,
};

#[test]
fn test_wad_mul_basic() {
    // 2 WAD * 3 WAD = 6 WAD
    let result = wad_mul(2 * WAD, 3 * WAD);
    assert(result == 6 * WAD, 'wad_mul 2*3');
}

#[test]
fn test_wad_mul_fractional() {
    // 1.5 WAD * 2 WAD = 3 WAD
    let a = WAD + WAD / 2; // 1.5e18
    let result = wad_mul(a, 2 * WAD);
    assert(result == 3 * WAD, 'wad_mul 1.5*2');
}

#[test]
fn test_wad_mul_zero() {
    assert(wad_mul(0, WAD) == 0, 'wad_mul 0*1');
    assert(wad_mul(WAD, 0) == 0, 'wad_mul 1*0');
}

#[test]
fn test_wad_div_basic() {
    // 6 WAD / 2 WAD = 3 WAD
    let result = wad_div(6 * WAD, 2 * WAD);
    assert(result == 3 * WAD, 'wad_div 6/2');
}

#[test]
fn test_wad_div_fractional() {
    // 1 WAD / 2 WAD = 0.5 WAD
    let result = wad_div(WAD, 2 * WAD);
    assert(result == WAD / 2, 'wad_div 1/2');
}

#[test]
fn test_ray_mul_basic() {
    let result = ray_mul(2 * RAY, 3 * RAY);
    assert(result == 6 * RAY, 'ray_mul 2*3');
}

#[test]
fn test_ray_div_basic() {
    let result = ray_div(6 * RAY, 2 * RAY);
    assert(result == 3 * RAY, 'ray_div 6/2');
}

#[test]
fn test_wad_to_ray() {
    let result = wad_to_ray(WAD);
    assert(result == RAY, 'wad_to_ray 1');
}

#[test]
fn test_ray_to_wad() {
    let result = ray_to_wad(RAY);
    assert(result == WAD, 'ray_to_wad 1');
}

#[test]
fn test_ray_wad_roundtrip() {
    let original = 42 * WAD;
    let as_ray = wad_to_ray(original);
    let back = ray_to_wad(as_ray);
    assert(back == original, 'roundtrip');
}

#[test]
fn test_bps_mul() {
    // 100 * 5000 BPS = 50
    let result = bps_mul(100, 5000);
    assert(result == 50, 'bps_mul 50%');
}

#[test]
fn test_bps_mul_full() {
    // 100 * 10000 BPS = 100
    let result = bps_mul(100, BPS);
    assert(result == 100, 'bps_mul 100%');
}

#[test]
fn test_utilization_rate_basic() {
    // 50% utilization: 500 borrowed / 1000 deposited = 5000 BPS
    let result = utilization_rate(1000, 500);
    assert(result == 5000, 'util 50%');
}

#[test]
fn test_utilization_rate_zero_deposits() {
    let result = utilization_rate(0, 0);
    assert(result == 0, 'util 0 deps');
}

#[test]
fn test_utilization_rate_full() {
    let result = utilization_rate(1000, 1000);
    assert(result == BPS, 'util 100%');
}

#[test]
fn test_health_factor_healthy() {
    // collateral = 200, debt = 100, liq_threshold = 8000 BPS (80%)
    // HF = (200 * 0.8) / 100 * WAD = 1.6 WAD
    let hf = health_factor(200 * WAD, 100 * WAD, 8000);
    // 200 * 8000 / 10000 = 160, 160/100 = 1.6
    let expected = WAD + WAD * 6 / 10; // 1.6e18
    assert(hf == expected, 'hf healthy');
}

#[test]
fn test_health_factor_exactly_one() {
    // collateral = 125, debt = 100, liq_threshold = 8000 BPS
    // HF = 125 * 0.8 / 100 = 1.0
    let hf = health_factor(125 * WAD, 100 * WAD, 8000);
    assert(hf == WAD, 'hf exactly 1');
}

#[test]
fn test_health_factor_undercollateralized() {
    // collateral = 100, debt = 100, liq_threshold = 8000 BPS
    // HF = 100 * 0.8 / 100 = 0.8 < 1.0
    let hf = health_factor(100 * WAD, 100 * WAD, 8000);
    let expected = WAD * 8 / 10; // 0.8e18
    assert(hf == expected, 'hf under');
    assert(hf < WAD, 'hf should be < 1');
}

#[test]
fn test_health_factor_no_debt() {
    let hf = health_factor(100 * WAD, 0, 8000);
    assert(hf == WAD * 1000, 'hf no debt');
}

#[test]
fn test_compound_interest_zero_time() {
    let result = compound_interest(RAY / 100, 0);
    assert(result == RAY, 'compound 0s');
}

#[test]
fn test_compound_interest_linear() {
    // rate = 10% per year in RAY, 1 second
    let rate_per_second = RAY / 10 / 31_536_000; // ~3.17e18
    let result = compound_interest(rate_per_second, 1);
    // Should be RAY + rate_per_second
    assert(result == RAY + rate_per_second, 'compound 1s');
}

#[test]
fn test_compound_interest_one_year() {
    // 5% annual rate per second
    let annual_rate = RAY * 5 / 100;
    let rate_per_second = annual_rate / 31_536_000;
    let result = compound_interest(rate_per_second, 31_536_000);
    // Linear approx: 1 + rate_per_second * seconds (integer truncation in rate_per_second)
    let expected = RAY + rate_per_second * 31_536_000;
    assert(result == expected, 'compound 1yr');
    // Should be approximately 1.05 RAY (within rounding)
    let diff = if result > RAY + annual_rate {
        result - (RAY + annual_rate)
    } else {
        (RAY + annual_rate) - result
    };
    assert(diff < RAY / 1_000_000, 'compound ~5%');
}

#[test]
fn test_min() {
    assert(min(1, 2) == 1, 'min 1,2');
    assert(min(5, 3) == 3, 'min 5,3');
    assert(min(7, 7) == 7, 'min 7,7');
}

#[test]
fn test_max() {
    assert(max(1, 2) == 2, 'max 1,2');
    assert(max(5, 3) == 5, 'max 5,3');
    assert(max(7, 7) == 7, 'max 7,7');
}
