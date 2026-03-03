#!/usr/bin/env bash
# ============================================================
# ShieldLend — Fix shielded_repay: Full Redeploy (v2)
# ============================================================
# Deploys new SL+Debt tokens + new Pools with fixed shielded_repay.
# Reuses existing: tokens, oracle, IRM, privacy contracts.
# ============================================================

set -euo pipefail

if [ -f .env ]; then
    set -a; source .env; set +a
    echo "Loaded .env"
else
    echo "ERROR: .env not found"; exit 1
fi

OWNER="${STARKNET_ACCOUNT_ADDRESS}"
RPC_URL="${STARKNET_RPC_URL}"
ORACLE="${ORACLE_ADDRESS}"
IRM="${INTEREST_RATE_MODEL_ADDRESS}"
ZK="${ZK_VERIFIER_ADDRESS}"
CS="${COMMITMENT_STORE_ADDRESS}"
NR="${NULLIFIER_REGISTRY_ADDRESS}"

SNCAST="sncast --wait --account ${STARKNET_ACCOUNT_NAME}"
URL="--url $RPC_URL"

echo "==========================================="
echo "  Fix shielded_repay — Full Redeploy v2"
echo "==========================================="

cd contracts

# ---- Helpers ----
declare_and_get_hash() {
    local name=$1
    echo "  Declaring $name..." >&2
    local output
    output=$($SNCAST declare --contract-name "$name" $URL 2>&1) || true
    local hash
    hash=$(echo "$output" | grep -i "class.hash" | grep -oE '0x[0-9a-fA-F]+' | head -1)
    if [ -z "$hash" ]; then
        hash=$(echo "$output" | grep -oE 'class hash.*0x[0-9a-fA-F]+' | grep -oE '0x[0-9a-fA-F]+' | head -1)
    fi
    if [ -z "$hash" ]; then
        echo "    WARNING: Could not extract class hash" >&2
        echo "    Output: $output" >&2
        echo "0x0"; return
    fi
    echo "    Class hash: $hash" >&2
    echo "$hash"
}

deploy_contract() {
    local class_hash=$1; shift
    local calldata="$*"
    local output
    output=$($SNCAST deploy --class-hash "$class_hash" --constructor-calldata $calldata $URL 2>&1) || true
    local addr
    addr=$(echo "$output" | grep -i "contract.address" | grep -oE '0x[0-9a-fA-F]+' | head -1)
    if [ -z "$addr" ]; then
        echo "    WARNING: Could not extract address" >&2
        echo "    Output: $output" >&2
        echo "0x0"; return
    fi
    echo "$addr"
}

invoke_contract() {
    local contract=$1; local func=$2; shift 2
    local calldata="$*"
    local output
    output=$($SNCAST invoke --contract-address "$contract" --function "$func" --calldata $calldata $URL 2>&1) || true
    echo "$output" >&2
}

encode_short_string() {
    local str=$1; local len=${#str}
    local hex="0x"
    for (( i=0; i<len; i++ )); do
        hex+=$(printf '%02x' "'${str:$i:1}")
    done
    echo "0 $hex $len"
}

echo ""
echo "Step 1: Declare contracts..."
echo "==========================================="
# LendingPool already declared in previous run
HASH_POOL="0x5ead1b32a316c24453930078740300049ec188ff9ecb784c2210b65aefc7be9"
echo "  LendingPool class: $HASH_POOL (already declared)"

HASH_SL=$(declare_and_get_hash "SlToken")
HASH_DEBT=$(declare_and_get_hash "DebtToken")

# ============================================================
# Market 1: strkBTC/USDC
# ============================================================
echo ""
echo "Step 2: Market 1 — strkBTC/USDC..."
echo "==========================================="

SL1_NAME=$(encode_short_string "SL strkBTC-USDC")
SL1_SYMBOL=$(encode_short_string "slBTC-USDC")
echo "  Deploying new SlToken..."
NEW_SL1=$(deploy_contract "$HASH_SL" $SL1_NAME $SL1_SYMBOL "$OWNER")
echo "    SlToken: $NEW_SL1"

DT1_NAME=$(encode_short_string "Debt strkBTC-USDC")
DT1_SYMBOL=$(encode_short_string "dBTC-USDC")
echo "  Deploying new DebtToken..."
NEW_DT1=$(deploy_contract "$HASH_DEBT" $DT1_NAME $DT1_SYMBOL "$OWNER")
echo "    DebtToken: $NEW_DT1"

echo "  Deploying new LendingPool..."
NEW_POOL1=$(deploy_contract "$HASH_POOL" \
    "$STRK_BTC_TOKEN" "$USDC_TOKEN" "$NEW_SL1" "$NEW_DT1" \
    "$ORACLE" "$IRM" \
    7500 0 8000 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "    Pool: $NEW_POOL1"

echo "  Setting SL token pool..."
invoke_contract "$NEW_SL1" "set_pool" "$NEW_POOL1"
echo "  Setting Debt token pool..."
invoke_contract "$NEW_DT1" "set_pool" "$NEW_POOL1"

# ============================================================
# Market 2: tBTC/USDC
# ============================================================
echo ""
echo "Step 3: Market 2 — tBTC/USDC..."
echo "==========================================="

SL2_NAME=$(encode_short_string "SL tBTC-USDC")
SL2_SYMBOL=$(encode_short_string "slTBTC-USDC")
echo "  Deploying new SlToken..."
NEW_SL2=$(deploy_contract "$HASH_SL" $SL2_NAME $SL2_SYMBOL "$OWNER")
echo "    SlToken: $NEW_SL2"

DT2_NAME=$(encode_short_string "Debt tBTC-USDC")
DT2_SYMBOL=$(encode_short_string "dTBTC-USDC")
echo "  Deploying new DebtToken..."
NEW_DT2=$(deploy_contract "$HASH_DEBT" $DT2_NAME $DT2_SYMBOL "$OWNER")
echo "    DebtToken: $NEW_DT2"

echo "  Deploying new LendingPool..."
NEW_POOL2=$(deploy_contract "$HASH_POOL" \
    "$TBTC_TOKEN" "$USDC_TOKEN" "$NEW_SL2" "$NEW_DT2" \
    "$ORACLE" "$IRM" \
    7000 0 7500 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "    Pool: $NEW_POOL2"

echo "  Setting SL token pool..."
invoke_contract "$NEW_SL2" "set_pool" "$NEW_POOL2"
echo "  Setting Debt token pool..."
invoke_contract "$NEW_DT2" "set_pool" "$NEW_POOL2"

# ============================================================
# Market 3: strkBTC/tBTC eMode
# ============================================================
echo ""
echo "Step 4: Market 3 — strkBTC/tBTC eMode..."
echo "==========================================="

SL3_NAME=$(encode_short_string "SL strkBTC-tBTC")
SL3_SYMBOL=$(encode_short_string "slBTC-tBTC")
echo "  Deploying new SlToken..."
NEW_SL3=$(deploy_contract "$HASH_SL" $SL3_NAME $SL3_SYMBOL "$OWNER")
echo "    SlToken: $NEW_SL3"

DT3_NAME=$(encode_short_string "Debt strkBTC-tBTC")
DT3_SYMBOL=$(encode_short_string "dBTC-tBTC")
echo "  Deploying new DebtToken..."
NEW_DT3=$(deploy_contract "$HASH_DEBT" $DT3_NAME $DT3_SYMBOL "$OWNER")
echo "    DebtToken: $NEW_DT3"

echo "  Deploying new LendingPool..."
NEW_POOL3=$(deploy_contract "$HASH_POOL" \
    "$STRK_BTC_TOKEN" "$TBTC_TOKEN" "$NEW_SL3" "$NEW_DT3" \
    "$ORACLE" "$IRM" \
    9500 0 9700 0 200 0 500 0 \
    "$ZK" "$CS" "$NR")
echo "    Pool: $NEW_POOL3"

echo "  Setting SL token pool..."
invoke_contract "$NEW_SL3" "set_pool" "$NEW_POOL3"
echo "  Setting Debt token pool..."
invoke_contract "$NEW_DT3" "set_pool" "$NEW_POOL3"

# ============================================================
echo ""
echo "==========================================="
echo "  Redeployment Complete!"
echo "==========================================="
echo ""
echo "New Pool Addresses:"
echo "  POOL_STRKBTC_USDC=$NEW_POOL1"
echo "  POOL_TBTC_USDC=$NEW_POOL2"
echo "  POOL_STRKBTC_TBTC=$NEW_POOL3"
echo ""
echo "New SL Token Addresses:"
echo "  SL_STRKBTC_USDC=$NEW_SL1"
echo "  SL_TBTC_USDC=$NEW_SL2"
echo "  SL_STRKBTC_TBTC=$NEW_SL3"
echo ""
echo "New Debt Token Addresses:"
echo "  DEBT_STRKBTC_USDC=$NEW_DT1"
echo "  DEBT_TBTC_USDC=$NEW_DT2"
echo "  DEBT_STRKBTC_TBTC=$NEW_DT3"
echo ""
echo "For frontend/.env.local:"
echo "  NEXT_PUBLIC_POOL_STRKBTC_USDC=$NEW_POOL1"
echo "  NEXT_PUBLIC_POOL_TBTC_USDC=$NEW_POOL2"
echo "  NEXT_PUBLIC_POOL_STRKBTC_TBTC=$NEW_POOL3"
echo "  NEXT_PUBLIC_SL_TOKEN_1=$NEW_SL1"
echo "  NEXT_PUBLIC_SL_TOKEN_2=$NEW_SL2"
echo "  NEXT_PUBLIC_SL_TOKEN_3=$NEW_SL3"
