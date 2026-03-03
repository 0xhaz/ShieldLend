#!/usr/bin/env bash
# ============================================================
# ShieldLend — Market-Specific Deployment Script
# ============================================================
# Run AFTER deploy.sh. Deploys:
#   1. MockERC20 tokens (strkBTC, tBTC, USDC)
#   2. Per-market SlToken + DebtToken + LendingPool
#   3. Registers markets in MarketFactory
#   4. Sets oracle prices
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

OWNER="${STARKNET_ACCOUNT_ADDRESS:?Set STARKNET_ACCOUNT_ADDRESS in .env}"
RPC_URL="${STARKNET_RPC_URL:?Set STARKNET_RPC_URL in .env}"
ORACLE="${ORACLE_ADDRESS:?Set ORACLE_ADDRESS in .env}"
IRM="${INTEREST_RATE_MODEL_ADDRESS:?Set INTEREST_RATE_MODEL_ADDRESS in .env}"
FACTORY="${MARKET_FACTORY_ADDRESS:?Set MARKET_FACTORY_ADDRESS in .env}"

SNCAST_GLOBAL="sncast --wait"
if [ -n "${STARKNET_ACCOUNT_NAME:-}" ]; then
    SNCAST_GLOBAL="sncast --wait --account $STARKNET_ACCOUNT_NAME"
fi
SNCAST_URL="--url $RPC_URL"

echo "==========================================="
echo "  ShieldLend Market Deployment"
echo "  Owner:   $OWNER"
echo "  Oracle:  $ORACLE"
echo "  IRM:     $IRM"
echo "  Factory: $FACTORY"
echo "==========================================="

cd contracts

# ---- Helpers ----
declare_and_get_hash() {
    local name=$1
    echo "  Declaring $name..." >&2
    local output
    output=$($SNCAST_GLOBAL declare \
        --contract-name "$name" \
        $SNCAST_URL 2>&1) || true

    local hash
    hash=$(echo "$output" | grep -i "class.hash" | grep -oE '0x[0-9a-fA-F]+' | head -1)

    if [ -z "$hash" ]; then
        hash=$(echo "$output" | grep -oE 'class hash.*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1)
    fi

    if [ -z "$hash" ]; then
        echo "    WARNING: Could not extract class hash for $name" >&2
        echo "    Output: $output" >&2
        echo "0x0"
        return
    fi

    echo "    Class hash: $hash" >&2
    echo "$hash"
}

deploy_contract() {
    local class_hash=$1
    shift
    local calldata="$*"

    local output
    output=$($SNCAST_GLOBAL deploy \
        --class-hash "$class_hash" \
        --constructor-calldata $calldata \
        $SNCAST_URL 2>&1) || true

    local addr
    addr=$(echo "$output" | grep -i "contract.address" | grep -oE '0x[0-9a-fA-F]+' | head -1)

    if [ -z "$addr" ]; then
        echo "    WARNING: Could not extract address" >&2
        echo "    Output: $output" >&2
        echo "0x0"
        return
    fi

    echo "$addr"
}

invoke_contract() {
    local contract=$1
    local func=$2
    shift 2
    local calldata="$*"

    local output
    output=$($SNCAST_GLOBAL invoke \
        --contract-address "$contract" \
        --function "$func" \
        --calldata $calldata \
        $SNCAST_URL 2>&1) || true

    echo "$output" >&2
}

# ByteArray encoding helper for Starknet
# ByteArray = { data: Array<bytes31>, pending_word: felt252, pending_word_len: felt252 }
# For short strings (<=31 chars): data_len=0, pending_word=hex(string), pending_word_len=len
encode_short_string() {
    local str=$1
    local len=${#str}
    # Convert string to hex
    local hex="0x"
    for (( i=0; i<len; i++ )); do
        hex+=$(printf '%02x' "'${str:$i:1}")
    done
    # ByteArray: data_len=0, pending_word=hex, pending_word_len=len
    echo "0 $hex $len"
}

echo ""
echo "Step 1: Declare new contracts..."
echo "==========================================="

HASH_MOCK=$(declare_and_get_hash "MockERC20")
HASH_SL=$(declare_and_get_hash "SlToken")
HASH_DEBT=$(declare_and_get_hash "DebtToken")
HASH_POOL=$(declare_and_get_hash "LendingPool")

echo ""
echo "Step 2: Deploy MockERC20 tokens..."
echo "==========================================="

# MockERC20 constructor: (name: ByteArray, symbol: ByteArray, owner: ContractAddress)
# strkBTC
echo "Deploying strkBTC..."
STRK_BTC_NAME=$(encode_short_string "Staked Bitcoin")
STRK_BTC_SYMBOL=$(encode_short_string "strkBTC")
ADDR_STRK_BTC=$(deploy_contract "$HASH_MOCK" $STRK_BTC_NAME $STRK_BTC_SYMBOL "$OWNER")
echo "  strkBTC: $ADDR_STRK_BTC"

# tBTC
echo "Deploying tBTC..."
TBTC_NAME=$(encode_short_string "Threshold Bitcoin")
TBTC_SYMBOL=$(encode_short_string "tBTC")
ADDR_TBTC=$(deploy_contract "$HASH_MOCK" $TBTC_NAME $TBTC_SYMBOL "$OWNER")
echo "  tBTC: $ADDR_TBTC"

# USDC
echo "Deploying USDC..."
USDC_NAME=$(encode_short_string "USD Coin")
USDC_SYMBOL=$(encode_short_string "USDC")
ADDR_USDC=$(deploy_contract "$HASH_MOCK" $USDC_NAME $USDC_SYMBOL "$OWNER")
echo "  USDC: $ADDR_USDC"

echo ""
echo "Step 3: Set Oracle Prices..."
echo "==========================================="

# set_price(asset, price_low, price_high) — price in WAD (1e18)
# strkBTC = $67,500
echo "  Setting strkBTC = \$67,500"
invoke_contract "$ORACLE" "set_price" "$ADDR_STRK_BTC" 67500000000000000000000 0

# tBTC = $67,300
echo "  Setting tBTC = \$67,300"
invoke_contract "$ORACLE" "set_price" "$ADDR_TBTC" 67300000000000000000000 0

# USDC = $1
echo "  Setting USDC = \$1.00"
invoke_contract "$ORACLE" "set_price" "$ADDR_USDC" 1000000000000000000 0

echo ""
echo "Step 4: Deploy Market 1 — strkBTC/USDC..."
echo "==========================================="

# Deploy SlToken: constructor(name, symbol, pool)
# Initially set pool = OWNER (deployer), then update after LendingPool is deployed
echo "  Deploying SlToken for strkBTC/USDC..."
SL1_NAME=$(encode_short_string "SL strkBTC-USDC")
SL1_SYMBOL=$(encode_short_string "slBTC-USDC")
ADDR_SL1=$(deploy_contract "$HASH_SL" $SL1_NAME $SL1_SYMBOL "$OWNER")
echo "    SlToken: $ADDR_SL1"

echo "  Deploying DebtToken for strkBTC/USDC..."
DT1_NAME=$(encode_short_string "Debt strkBTC-USDC")
DT1_SYMBOL=$(encode_short_string "dBTC-USDC")
ADDR_DT1=$(deploy_contract "$HASH_DEBT" $DT1_NAME $DT1_SYMBOL "$OWNER")
echo "    DebtToken: $ADDR_DT1"

# LendingPool constructor:
# (collateral_token, loan_token, sl_token, debt_token, oracle, interest_rate_model,
#  ltv_bps_low, ltv_bps_high, liq_threshold_low, liq_threshold_high,
#  liq_bonus_low, liq_bonus_high, reserve_factor_low, reserve_factor_high)
# strkBTC/USDC: LTV=7500 bps (75%), LiqThreshold=8000 (80%), Bonus=500 (5%), ReserveFactor=1000 (10%)
echo "  Deploying LendingPool for strkBTC/USDC..."
ADDR_POOL1=$(deploy_contract "$HASH_POOL" \
    "$ADDR_STRK_BTC" "$ADDR_USDC" "$ADDR_SL1" "$ADDR_DT1" \
    "$ORACLE" "$IRM" \
    7500 0 8000 0 500 0 1000 0)
echo "    LendingPool: $ADDR_POOL1"

# Update SlToken and DebtToken to point to the real pool
echo "  Updating SlToken pool -> LendingPool..."
invoke_contract "$ADDR_SL1" "set_pool" "$ADDR_POOL1"
echo "  Updating DebtToken pool -> LendingPool..."
invoke_contract "$ADDR_DT1" "set_pool" "$ADDR_POOL1"

# Register in MarketFactory
# register_market(pool, collateral, loan, ltv_low, ltv_high, liq_threshold_low, liq_threshold_high)
echo "  Registering market in MarketFactory..."
invoke_contract "$FACTORY" "register_market" \
    "$ADDR_POOL1" "$ADDR_STRK_BTC" "$ADDR_USDC" 7500 0 8000 0

echo ""
echo "Step 5: Deploy Market 2 — tBTC/USDC..."
echo "==========================================="

echo "  Deploying SlToken for tBTC/USDC..."
SL2_NAME=$(encode_short_string "SL tBTC-USDC")
SL2_SYMBOL=$(encode_short_string "slTBTC-USDC")
ADDR_SL2=$(deploy_contract "$HASH_SL" $SL2_NAME $SL2_SYMBOL "$OWNER")
echo "    SlToken: $ADDR_SL2"

echo "  Deploying DebtToken for tBTC/USDC..."
DT2_NAME=$(encode_short_string "Debt tBTC-USDC")
DT2_SYMBOL=$(encode_short_string "dTBTC-USDC")
ADDR_DT2=$(deploy_contract "$HASH_DEBT" $DT2_NAME $DT2_SYMBOL "$OWNER")
echo "    DebtToken: $ADDR_DT2"

# tBTC/USDC: LTV=7000 (70%), LiqThreshold=7500 (75%), Bonus=500 (5%), Reserve=1000 (10%)
echo "  Deploying LendingPool for tBTC/USDC..."
ADDR_POOL2=$(deploy_contract "$HASH_POOL" \
    "$ADDR_TBTC" "$ADDR_USDC" "$ADDR_SL2" "$ADDR_DT2" \
    "$ORACLE" "$IRM" \
    7000 0 7500 0 500 0 1000 0)
echo "    LendingPool: $ADDR_POOL2"

echo "  Updating SlToken pool -> LendingPool..."
invoke_contract "$ADDR_SL2" "set_pool" "$ADDR_POOL2"
echo "  Updating DebtToken pool -> LendingPool..."
invoke_contract "$ADDR_DT2" "set_pool" "$ADDR_POOL2"

echo "  Registering market in MarketFactory..."
invoke_contract "$FACTORY" "register_market" \
    "$ADDR_POOL2" "$ADDR_TBTC" "$ADDR_USDC" 7000 0 7500 0

echo ""
echo "Step 6: Deploy Market 3 — strkBTC/tBTC (eMode)..."
echo "==========================================="

echo "  Deploying SlToken for strkBTC/tBTC..."
SL3_NAME=$(encode_short_string "SL strkBTC-tBTC")
SL3_SYMBOL=$(encode_short_string "slBTC-tBTC")
ADDR_SL3=$(deploy_contract "$HASH_SL" $SL3_NAME $SL3_SYMBOL "$OWNER")
echo "    SlToken: $ADDR_SL3"

echo "  Deploying DebtToken for strkBTC/tBTC..."
DT3_NAME=$(encode_short_string "Debt strkBTC-tBTC")
DT3_SYMBOL=$(encode_short_string "dBTC-tBTC")
ADDR_DT3=$(deploy_contract "$HASH_DEBT" $DT3_NAME $DT3_SYMBOL "$OWNER")
echo "    DebtToken: $ADDR_DT3"

# eMode: LTV=9500 (95%), LiqThreshold=9700 (97%), Bonus=200 (2%), Reserve=500 (5%)
echo "  Deploying LendingPool for strkBTC/tBTC..."
ADDR_POOL3=$(deploy_contract "$HASH_POOL" \
    "$ADDR_STRK_BTC" "$ADDR_TBTC" "$ADDR_SL3" "$ADDR_DT3" \
    "$ORACLE" "$IRM" \
    9500 0 9700 0 200 0 500 0)
echo "    LendingPool: $ADDR_POOL3"

echo "  Updating SlToken pool -> LendingPool..."
invoke_contract "$ADDR_SL3" "set_pool" "$ADDR_POOL3"
echo "  Updating DebtToken pool -> LendingPool..."
invoke_contract "$ADDR_DT3" "set_pool" "$ADDR_POOL3"

echo "  Registering market in MarketFactory..."
invoke_contract "$FACTORY" "register_market" \
    "$ADDR_POOL3" "$ADDR_STRK_BTC" "$ADDR_TBTC" 9500 0 9700 0

echo ""
echo "==========================================="
echo "  Market Deployment Complete!"
echo "==========================================="
echo ""
echo "Token Addresses:"
echo "  STRK_BTC_TOKEN=$ADDR_STRK_BTC"
echo "  TBTC_TOKEN=$ADDR_TBTC"
echo "  USDC_TOKEN=$ADDR_USDC"
echo ""
echo "Market 1 — strkBTC/USDC (LTV 75%):"
echo "  POOL=$ADDR_POOL1"
echo "  SL_TOKEN=$ADDR_SL1"
echo "  DEBT_TOKEN=$ADDR_DT1"
echo ""
echo "Market 2 — tBTC/USDC (LTV 70%):"
echo "  POOL=$ADDR_POOL2"
echo "  SL_TOKEN=$ADDR_SL2"
echo "  DEBT_TOKEN=$ADDR_DT2"
echo ""
echo "Market 3 — strkBTC/tBTC eMode (LTV 95%):"
echo "  POOL=$ADDR_POOL3"
echo "  SL_TOKEN=$ADDR_SL3"
echo "  DEBT_TOKEN=$ADDR_DT3"
echo ""
echo "For frontend/.env.local:"
echo "  NEXT_PUBLIC_STRK_BTC=$ADDR_STRK_BTC"
echo "  NEXT_PUBLIC_TBTC=$ADDR_TBTC"
echo "  NEXT_PUBLIC_USDC=$ADDR_USDC"
echo "  NEXT_PUBLIC_POOL_STRKBTC_USDC=$ADDR_POOL1"
echo "  NEXT_PUBLIC_POOL_TBTC_USDC=$ADDR_POOL2"
echo "  NEXT_PUBLIC_POOL_STRKBTC_TBTC=$ADDR_POOL3"
