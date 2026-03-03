#!/usr/bin/env bash
# ============================================================
# ShieldLend — Seed Deposits + Borrows for Demo APY Display
# ============================================================
# Deposits collateral and makes borrows so utilization > 0
# and APYs show non-zero values on the frontend.
# ============================================================

set -euo pipefail

if [ -f .env ]; then
    set -a; source .env; set +a
    echo "Loaded .env"
else
    echo "ERROR: .env not found"
    exit 1
fi

OWNER="${STARKNET_ACCOUNT_ADDRESS:?}"
RPC_URL="${STARKNET_RPC_URL:?}"
ACCT="${STARKNET_ACCOUNT_NAME:-deployer}"

sn_invoke() {
    sncast --wait --account "$ACCT" invoke --url "$RPC_URL" "$@"
}
sn_call() {
    sncast --account "$ACCT" call --url "$RPC_URL" "$@"
}

STRK_BTC="${STRK_BTC_TOKEN:?}"
TBTC="${TBTC_TOKEN:?}"
USDC="${USDC_TOKEN:?}"

POOL1="${POOL_STRKBTC_USDC:?}"
POOL2="${POOL_TBTC_USDC:?}"
POOL3="${POOL_STRKBTC_TBTC:?}"

u256_eth() {
    python3 -c "v=int($1 * 10**18); print(f'{v} 0')"
}

echo "==========================================="
echo "  ShieldLend — Full Market Seeding"
echo "==========================================="

# ---- Step 1: Mint tokens to deployer ----
echo ""
echo "=== Step 1: Minting test tokens ==="

echo "Minting 100 strkBTC..."
sn_invoke --contract-address "$STRK_BTC" --function "mint" \
    --calldata "$OWNER $(u256_eth 100)" || echo "  (ok)"

echo "Minting 100 tBTC..."
sn_invoke --contract-address "$TBTC" --function "mint" \
    --calldata "$OWNER $(u256_eth 100)" || echo "  (ok)"

# ---- Step 2: Deposit collateral into each pool ----
echo ""
echo "=== Step 2: Depositing collateral ==="

# Pool1: Approve + Deposit 10 strkBTC
echo "Approving 10 strkBTC for Pool1..."
sn_invoke --contract-address "$STRK_BTC" --function "approve" \
    --calldata "$POOL1 $(u256_eth 10)"

echo "Depositing 10 strkBTC into Pool1..."
sn_invoke --contract-address "$POOL1" --function "deposit" \
    --calldata "$(u256_eth 10)"

# Pool2: Approve + Deposit 8 tBTC (may already have 2 from manual deposit)
echo "Approving 8 tBTC for Pool2..."
sn_invoke --contract-address "$TBTC" --function "approve" \
    --calldata "$POOL2 $(u256_eth 8)"

echo "Depositing 8 tBTC into Pool2..."
sn_invoke --contract-address "$POOL2" --function "deposit" \
    --calldata "$(u256_eth 8)"

# Pool3: Approve + Deposit 5 strkBTC
echo "Approving 5 strkBTC for Pool3..."
sn_invoke --contract-address "$STRK_BTC" --function "approve" \
    --calldata "$POOL3 $(u256_eth 5)"

echo "Depositing 5 strkBTC into Pool3..."
sn_invoke --contract-address "$POOL3" --function "deposit" \
    --calldata "$(u256_eth 5)"

# ---- Step 3: Borrow from each pool ----
echo ""
echo "=== Step 3: Borrowing to create utilization ==="

# Pool1: 10 strkBTC deposited. Borrow 5 USDC → ~50% util
echo "Borrowing 5 USDC from Pool1..."
sn_invoke --contract-address "$POOL1" --function "borrow" \
    --calldata "$(u256_eth 5)"

# Pool2: 10 tBTC deposited. Borrow 4 USDC → ~40% util
echo "Borrowing 4 USDC from Pool2..."
sn_invoke --contract-address "$POOL2" --function "borrow" \
    --calldata "$(u256_eth 4)"

# Pool3: 5 strkBTC deposited. Borrow 2 tBTC → ~40% util
echo "Borrowing 2 tBTC from Pool3..."
sn_invoke --contract-address "$POOL3" --function "borrow" \
    --calldata "$(u256_eth 2)"

# ---- Step 4: Verify market data ----
echo ""
echo "=== Step 4: Verifying market data ==="

echo "Pool1 (strkBTC/USDC):"
sn_call --contract-address "$POOL1" --function "get_market_data" 2>&1

echo ""
echo "Pool2 (tBTC/USDC):"
sn_call --contract-address "$POOL2" --function "get_market_data" 2>&1

echo ""
echo "Pool3 (strkBTC/tBTC):"
sn_call --contract-address "$POOL3" --function "get_market_data" 2>&1

echo ""
echo "==========================================="
echo "  Seeding complete! APYs should now be > 0"
echo "==========================================="
