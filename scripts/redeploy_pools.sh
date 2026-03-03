#!/usr/bin/env bash
# ============================================================
# ShieldLend — Redeploy Pools with Privacy Infrastructure
# ============================================================
# Re-declares LendingPool and deploys new pool instances
# with zk_verifier, commitment_store, nullifier_registry set.
# Existing tokens (strkBTC, tBTC, USDC) are reused.
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
ORACLE="${ORACLE_ADDRESS:?}"
IRM="${INTEREST_RATE_MODEL_ADDRESS:?}"
FACTORY="${MARKET_FACTORY_ADDRESS:?}"
ZK_VERIFIER="${ZK_VERIFIER_ADDRESS:?}"
COMMITMENT_STORE="${COMMITMENT_STORE_ADDRESS:?}"
NULLIFIER_REGISTRY="${NULLIFIER_REGISTRY_ADDRESS:?}"

# Existing token addresses
ADDR_STRK_BTC="${STRK_BTC_TOKEN:?}"
ADDR_TBTC="${TBTC_TOKEN:?}"
ADDR_USDC="${USDC_TOKEN:?}"

ACCT="${STARKNET_ACCOUNT_NAME:-deployer}"

sn_declare() {
    local name=$1
    echo "  Declaring $name..." >&2
    local output
    output=$(sncast --wait --account "$ACCT" declare \
        --contract-name "$name" \
        --url "$RPC_URL" 2>&1) || true

    local hash
    # Extract class hash — try multiple patterns
    hash=$(echo "$output" | grep -i "class.hash" | grep -oE '0x[0-9a-fA-F]+' | head -1)
    if [ -z "$hash" ]; then
        hash=$(echo "$output" | grep -oE 'class hash.*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1)
    fi
    if [ -z "$hash" ]; then
        # Already declared — extract hash from error message
        hash=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{50,}' | head -1)
    fi
    if [ -z "$hash" ]; then
        echo "    WARNING: Could not extract class hash" >&2
        echo "    Output: $output" >&2
        echo "0x0"
        return
    fi
    echo "    Class hash: $hash" >&2
    echo "$hash"
}

sn_deploy() {
    local class_hash=$1
    shift
    local calldata="$*"

    local output
    output=$(sncast --wait --account "$ACCT" deploy \
        --class-hash "$class_hash" \
        --constructor-calldata $calldata \
        --url "$RPC_URL" 2>&1) || true

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

sn_invoke() {
    sncast --wait --account "$ACCT" invoke --url "$RPC_URL" "$@" 2>&1
}

# ByteArray encoding for short strings
encode_short_string() {
    local str=$1
    local len=${#str}
    local hex="0x"
    for (( i=0; i<len; i++ )); do
        hex+=$(printf '%02x' "'${str:$i:1}")
    done
    echo "0 $hex $len"
}

echo "==========================================="
echo "  ShieldLend Pool Redeployment"
echo "  ZK Verifier:      $ZK_VERIFIER"
echo "  Commitment Store:  $COMMITMENT_STORE"
echo "  Nullifier Registry: $NULLIFIER_REGISTRY"
echo "==========================================="

cd contracts

echo ""
echo "Step 1: Declare updated contracts..."
HASH_SL=$(sn_declare "SlToken")
HASH_DEBT=$(sn_declare "DebtToken")
HASH_POOL=$(sn_declare "LendingPool")

echo ""
echo "Step 2: Deploy Market 1 — strkBTC/USDC..."
echo "==========================================="

SL1_NAME=$(encode_short_string "SL strkBTC-USDC")
SL1_SYMBOL=$(encode_short_string "slBTC-USDC")
ADDR_SL1=$(sn_deploy "$HASH_SL" $SL1_NAME $SL1_SYMBOL "$OWNER")
echo "  SlToken: $ADDR_SL1"

DT1_NAME=$(encode_short_string "Debt strkBTC-USDC")
DT1_SYMBOL=$(encode_short_string "dBTC-USDC")
ADDR_DT1=$(sn_deploy "$HASH_DEBT" $DT1_NAME $DT1_SYMBOL "$OWNER")
echo "  DebtToken: $ADDR_DT1"

# LendingPool constructor now includes: zk_verifier, commitment_store, nullifier_registry
echo "  Deploying LendingPool for strkBTC/USDC..."
ADDR_POOL1=$(sn_deploy "$HASH_POOL" \
    "$ADDR_STRK_BTC" "$ADDR_USDC" "$ADDR_SL1" "$ADDR_DT1" \
    "$ORACLE" "$IRM" \
    7500 0 8000 0 500 0 1000 0 \
    "$ZK_VERIFIER" "$COMMITMENT_STORE" "$NULLIFIER_REGISTRY")
echo "  LendingPool: $ADDR_POOL1"

echo "  Setting SlToken/DebtToken pool..."
sn_invoke --contract-address "$ADDR_SL1" --function set_pool --calldata "$ADDR_POOL1"
sn_invoke --contract-address "$ADDR_DT1" --function set_pool --calldata "$ADDR_POOL1"

echo "  Registering market 1..."
sn_invoke --contract-address "$FACTORY" --function register_market \
    --calldata "$ADDR_POOL1" "$ADDR_STRK_BTC" "$ADDR_USDC" 7500 0 8000 0

echo ""
echo "Step 3: Deploy Market 2 — tBTC/USDC..."
echo "==========================================="

SL2_NAME=$(encode_short_string "SL tBTC-USDC")
SL2_SYMBOL=$(encode_short_string "slTBTC-USDC")
ADDR_SL2=$(sn_deploy "$HASH_SL" $SL2_NAME $SL2_SYMBOL "$OWNER")
echo "  SlToken: $ADDR_SL2"

DT2_NAME=$(encode_short_string "Debt tBTC-USDC")
DT2_SYMBOL=$(encode_short_string "dTBTC-USDC")
ADDR_DT2=$(sn_deploy "$HASH_DEBT" $DT2_NAME $DT2_SYMBOL "$OWNER")
echo "  DebtToken: $ADDR_DT2"

echo "  Deploying LendingPool for tBTC/USDC..."
ADDR_POOL2=$(sn_deploy "$HASH_POOL" \
    "$ADDR_TBTC" "$ADDR_USDC" "$ADDR_SL2" "$ADDR_DT2" \
    "$ORACLE" "$IRM" \
    7000 0 7500 0 500 0 1000 0 \
    "$ZK_VERIFIER" "$COMMITMENT_STORE" "$NULLIFIER_REGISTRY")
echo "  LendingPool: $ADDR_POOL2"

echo "  Setting SlToken/DebtToken pool..."
sn_invoke --contract-address "$ADDR_SL2" --function set_pool --calldata "$ADDR_POOL2"
sn_invoke --contract-address "$ADDR_DT2" --function set_pool --calldata "$ADDR_POOL2"

echo "  Registering market 2..."
sn_invoke --contract-address "$FACTORY" --function register_market \
    --calldata "$ADDR_POOL2" "$ADDR_TBTC" "$ADDR_USDC" 7000 0 7500 0

echo ""
echo "Step 4: Deploy Market 3 — strkBTC/tBTC (eMode)..."
echo "==========================================="

SL3_NAME=$(encode_short_string "SL strkBTC-tBTC")
SL3_SYMBOL=$(encode_short_string "slBTC-tBTC")
ADDR_SL3=$(sn_deploy "$HASH_SL" $SL3_NAME $SL3_SYMBOL "$OWNER")
echo "  SlToken: $ADDR_SL3"

DT3_NAME=$(encode_short_string "Debt strkBTC-tBTC")
DT3_SYMBOL=$(encode_short_string "dBTC-tBTC")
ADDR_DT3=$(sn_deploy "$HASH_DEBT" $DT3_NAME $DT3_SYMBOL "$OWNER")
echo "  DebtToken: $ADDR_DT3"

echo "  Deploying LendingPool for strkBTC/tBTC..."
ADDR_POOL3=$(sn_deploy "$HASH_POOL" \
    "$ADDR_STRK_BTC" "$ADDR_TBTC" "$ADDR_SL3" "$ADDR_DT3" \
    "$ORACLE" "$IRM" \
    9500 0 9700 0 200 0 500 0 \
    "$ZK_VERIFIER" "$COMMITMENT_STORE" "$NULLIFIER_REGISTRY")
echo "  LendingPool: $ADDR_POOL3"

echo "  Setting SlToken/DebtToken pool..."
sn_invoke --contract-address "$ADDR_SL3" --function set_pool --calldata "$ADDR_POOL3"
sn_invoke --contract-address "$ADDR_DT3" --function set_pool --calldata "$ADDR_POOL3"

echo "  Registering market 3..."
sn_invoke --contract-address "$FACTORY" --function register_market \
    --calldata "$ADDR_POOL3" "$ADDR_STRK_BTC" "$ADDR_TBTC" 9500 0 9700 0

echo ""
echo "==========================================="
echo "  Pool Redeployment Complete!"
echo "==========================================="
echo ""
echo "New Pool Addresses:"
echo "  POOL_STRKBTC_USDC=$ADDR_POOL1"
echo "  POOL_TBTC_USDC=$ADDR_POOL2"
echo "  POOL_STRKBTC_TBTC=$ADDR_POOL3"
echo ""
echo "Update frontend/.env.local:"
echo "  NEXT_PUBLIC_POOL_STRKBTC_USDC=$ADDR_POOL1"
echo "  NEXT_PUBLIC_POOL_TBTC_USDC=$ADDR_POOL2"
echo "  NEXT_PUBLIC_POOL_STRKBTC_TBTC=$ADDR_POOL3"
