#!/usr/bin/env bash
# ============================================================
# ShieldLend — Fund Pools with Loan Token Liquidity
# ============================================================
# Mints loan tokens directly into pool contracts so that
# borrowers can actually borrow. Without this, borrow() fails
# with "SL: insufficient liquidity".
#
# Pool1 (strkBTC/USDC): loan token = USDC
# Pool2 (tBTC/USDC):    loan token = USDC
# Pool3 (strkBTC/tBTC): loan token = tBTC
# ============================================================

set -euo pipefail

# Load .env
if [ -f .env ]; then
    set -a; source .env; set +a
    echo "Loaded .env"
else
    echo "ERROR: .env not found"
    exit 1
fi

RPC_URL="${STARKNET_RPC_URL:?Set STARKNET_RPC_URL in .env}"
ACCT="${STARKNET_ACCOUNT_NAME:-deployer}"

sn_invoke() {
    sncast --wait --account "$ACCT" invoke --url "$RPC_URL" "$@"
}

# Token addresses
USDC="${USDC_TOKEN:?}"
TBTC="${TBTC_TOKEN:?}"

# Pool addresses
POOL1="${POOL_STRKBTC_USDC:?}"
POOL2="${POOL_TBTC_USDC:?}"
POOL3="${POOL_STRKBTC_TBTC:?}"

# u256 helper: amount_in_ether -> low high calldata
u256_eth() {
    python3 -c "v=int($1 * 10**18); print(f'{v} 0')"
}

echo "==========================================="
echo "  ShieldLend — Fund Pools with Loan Tokens"
echo "==========================================="

# ---- Pool1: strkBTC/USDC — mint USDC into pool ----
echo ""
echo "=== Funding Pool1 (strkBTC/USDC) with 1,000,000 USDC ==="
sn_invoke \
    --contract-address "$USDC" \
    --function "mint" \
    --calldata "$POOL1 $(u256_eth 1000000)"

# ---- Pool2: tBTC/USDC — mint USDC into pool ----
echo ""
echo "=== Funding Pool2 (tBTC/USDC) with 1,000,000 USDC ==="
sn_invoke \
    --contract-address "$USDC" \
    --function "mint" \
    --calldata "$POOL2 $(u256_eth 1000000)"

# ---- Pool3: strkBTC/tBTC — mint tBTC into pool ----
echo ""
echo "=== Funding Pool3 (strkBTC/tBTC) with 50 tBTC ==="
sn_invoke \
    --contract-address "$TBTC" \
    --function "mint" \
    --calldata "$POOL3 $(u256_eth 50)"

echo ""
echo "==========================================="
echo "  Pool funding complete!"
echo "  Pool1: 1,000,000 USDC"
echo "  Pool2: 1,000,000 USDC"
echo "  Pool3: 50 tBTC"
echo "==========================================="
