#!/usr/bin/env bash
# ============================================================
# ShieldLend — Fix shielded_repay: Redeploy LendingPools
# ============================================================
# Redeclares LendingPool with fixed shielded_repay (3 public inputs),
# redeploys all 3 pools, and updates SL/Debt tokens to point to new pools.
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
echo "  Fix shielded_repay — Redeploy Pools"
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

echo ""
echo "Step 1: Declare fixed LendingPool..."
echo "==========================================="
HASH_POOL=$(declare_and_get_hash "LendingPool")
echo "  New class hash: $HASH_POOL"

# ============================================================
# Constructor: collateral, loan, sl, debt, oracle, irm,
#   ltv(u256), liq_threshold(u256), liq_bonus(u256), reserve_factor(u256),
#   zk_verifier, commitment_store, nullifier_registry
# ============================================================

echo ""
echo "Step 2: Deploy Pool 1 — strkBTC/USDC..."
echo "==========================================="
NEW_POOL1=$(deploy_contract "$HASH_POOL" \
    "$STRK_BTC_TOKEN" "$USDC_TOKEN" "$SL_STRKBTC_USDC" "$DEBT_STRKBTC_USDC" \
    "$ORACLE" "$IRM" \
    7500 0 8000 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "  Pool 1: $NEW_POOL1"

echo "  Updating SL token -> new pool..."
invoke_contract "$SL_STRKBTC_USDC" "set_pool" "$NEW_POOL1"
echo "  Updating Debt token -> new pool..."
invoke_contract "$DEBT_STRKBTC_USDC" "set_pool" "$NEW_POOL1"

echo ""
echo "Step 3: Deploy Pool 2 — tBTC/USDC..."
echo "==========================================="
NEW_POOL2=$(deploy_contract "$HASH_POOL" \
    "$TBTC_TOKEN" "$USDC_TOKEN" "$SL_TBTC_USDC" "$DEBT_TBTC_USDC" \
    "$ORACLE" "$IRM" \
    7000 0 7500 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "  Pool 2: $NEW_POOL2"

echo "  Updating SL token -> new pool..."
invoke_contract "$SL_TBTC_USDC" "set_pool" "$NEW_POOL2"
echo "  Updating Debt token -> new pool..."
invoke_contract "$DEBT_TBTC_USDC" "set_pool" "$NEW_POOL2"

echo ""
echo "Step 4: Deploy Pool 3 — strkBTC/tBTC eMode..."
echo "==========================================="
NEW_POOL3=$(deploy_contract "$HASH_POOL" \
    "$STRK_BTC_TOKEN" "$TBTC_TOKEN" "$SL_STRKBTC_TBTC" "$DEBT_STRKBTC_TBTC" \
    "$ORACLE" "$IRM" \
    9500 0 9700 0 200 0 500 0 \
    "$ZK" "$CS" "$NR")
echo "  Pool 3: $NEW_POOL3"

echo "  Updating SL token -> new pool..."
invoke_contract "$SL_STRKBTC_TBTC" "set_pool" "$NEW_POOL3"
echo "  Updating Debt token -> new pool..."
invoke_contract "$DEBT_STRKBTC_TBTC" "set_pool" "$NEW_POOL3"

echo ""
echo "==========================================="
echo "  Pool Redeployment Complete!"
echo "==========================================="
echo ""
echo "New Pool Addresses:"
echo "  POOL_STRKBTC_USDC=$NEW_POOL1"
echo "  POOL_TBTC_USDC=$NEW_POOL2"
echo "  POOL_STRKBTC_TBTC=$NEW_POOL3"
echo ""
echo "SL/Debt tokens updated to new pools."
echo "Update .env and frontend/.env.local with these new pool addresses."
