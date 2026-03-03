#!/usr/bin/env bash
# ============================================================
# ShieldLend — Market Setup Script
# ============================================================
# Run AFTER deploy.sh to create markets and set oracle prices.
#
# Usage:
#   1. Fill in .env with deployed addresses from deploy.sh output
#   2. ./scripts/setup_markets.sh
#
# Prerequisite: .env must have these filled in:
#   STARKNET_ACCOUNT_ADDRESS, ORACLE_ADDRESS,
#   MARKET_FACTORY_ADDRESS, and token addresses
# ============================================================

set -euo pipefail

# Load .env
if [ -f .env ]; then
    set -a; source .env; set +a
else
    echo "ERROR: .env not found"
    exit 1
fi

OWNER="${STARKNET_ACCOUNT_ADDRESS:?}"
NETWORK="${STARKNET_NETWORK:-sepolia}"

if [ -n "${STARKNET_RPC_URL:-}" ]; then
    RPC_URL="$STARKNET_RPC_URL"
elif [ "$NETWORK" = "sepolia" ]; then
    RPC_URL="https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10"
else
    RPC_URL="http://localhost:5050/rpc"
fi

SNCAST="sncast --url $RPC_URL"
if [ -n "${STARKNET_ACCOUNT_NAME:-}" ]; then
    SNCAST="$SNCAST --account $STARKNET_ACCOUNT_NAME"
fi

ORACLE="${ORACLE_ADDRESS:?Set ORACLE_ADDRESS in .env}"
FACTORY="${MARKET_FACTORY_ADDRESS:?Set MARKET_FACTORY_ADDRESS in .env}"

echo "=========================================="
echo "  ShieldLend Market Setup"
echo "  Network: $NETWORK"
echo "  Oracle:  $ORACLE"
echo "  Factory: $FACTORY"
echo "=========================================="

# ---- Step 1: Set Oracle Prices ----
echo ""
echo "Step 1: Setting oracle prices..."

# set_price(asset, price) — price is u256 (low, high)
# strkBTC = $67,500 in WAD = 67500 * 1e18
echo "  strkBTC = \$67,500"
$SNCAST invoke \
    --contract-address "$ORACLE" \
    --function "set_price" \
    --calldata "${STRK_BTC_TOKEN:-0x0}" 67500000000000000000000 0 \
     2>&1 || echo "  (may have failed)"

# tBTC = $67,300
echo "  tBTC = \$67,300"
$SNCAST invoke \
    --contract-address "$ORACLE" \
    --function "set_price" \
    --calldata "${TBTC_TOKEN:-0x0}" 67300000000000000000000 0 \
     2>&1 || echo "  (may have failed)"

# USDC = $1
echo "  USDC = \$1.00"
$SNCAST invoke \
    --contract-address "$ORACLE" \
    --function "set_price" \
    --calldata "${USDC_TOKEN:-0x0}" 1000000000000000000 0 \
     2>&1 || echo "  (may have failed)"

# ---- Step 2: Register Markets ----
echo ""
echo "Step 2: Registering markets in MarketFactory..."
echo ""
echo "  NOTE: Each market requires a deployed LendingPool, SlToken, and DebtToken."
echo "  The LendingPool constructor takes 10 arguments — deploy these manually"
echo "  then register via:"
echo ""
echo "  sncast invoke --contract-address $FACTORY \\"
echo "    --function register_market \\"
echo "    --calldata <POOL_ADDR> <COL_TOKEN> <LOAN_TOKEN> <LTV_BPS_LOW> 0 <LIQ_THRESHOLD_LOW> 0 \\"
echo "    "
echo ""
echo "  Suggested markets:"
echo "    1. strkBTC/USDC — LTV 7500, LiqThreshold 8000"
echo "    2. tBTC/USDC    — LTV 7000, LiqThreshold 7500"
echo "    3. strkBTC/tBTC — LTV 9500, LiqThreshold 9700 (eMode)"

echo ""
echo "=========================================="
echo "  Oracle prices set. Register markets manually."
echo "=========================================="
