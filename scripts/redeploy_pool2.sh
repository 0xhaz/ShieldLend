#!/usr/bin/env bash
# ============================================================
# ShieldLend — Redeploy Pool2 (tBTC/USDC) Only
# ============================================================
set -euo pipefail

if [ -f .env ]; then
    set -a; source .env; set +a
    echo "Loaded .env"
else
    echo "ERROR: .env not found"; exit 1
fi

OWNER="${STARKNET_ACCOUNT_ADDRESS:?}"
RPC_URL="${STARKNET_RPC_URL:?}"
ORACLE="${ORACLE_ADDRESS:?}"
IRM="${INTEREST_RATE_MODEL_ADDRESS:?}"
FACTORY="${MARKET_FACTORY_ADDRESS:?}"
ZK="${ZK_VERIFIER_ADDRESS:?}"
CS="${COMMITMENT_STORE_ADDRESS:?}"
NR="${NULLIFIER_REGISTRY_ADDRESS:?}"
TBTC="${TBTC_TOKEN:?}"
USDC="${USDC_TOKEN:?}"
ACCT="${STARKNET_ACCOUNT_NAME:-deployer}"

sn_declare() {
    local name=$1
    echo "  Declaring $name..." >&2
    local output
    output=$(sncast --wait --account "$ACCT" declare \
        --contract-name "$name" --url "$RPC_URL" 2>&1) || true
    local hash
    hash=$(echo "$output" | grep -oE '0x[0-9a-fA-F]{50,}' | head -1)
    [ -z "$hash" ] && { echo "  WARN: no class hash from $output" >&2; echo "0x0"; return; }
    echo "  Class hash: $hash" >&2
    echo "$hash"
}
sn_deploy() {
    local ch=$1; shift
    local output
    output=$(sncast --wait --account "$ACCT" deploy \
        --class-hash "$ch" --constructor-calldata $@ --url "$RPC_URL" 2>&1) || true
    local addr
    addr=$(echo "$output" | grep -i "contract.address" | grep -oE '0x[0-9a-fA-F]+' | head -1)
    [ -z "$addr" ] && { echo "  WARN: no addr from $output" >&2; echo "0x0"; return; }
    echo "$addr"
}
sn_invoke() {
    sncast --wait --account "$ACCT" invoke --url "$RPC_URL" "$@" 2>&1
}

encode_short_string() {
    local str="$1"
    local len=${#str}
    local hex="0x"
    for (( i=0; i<len; i++ )); do hex+=$(printf '%02x' "'${str:$i:1}"); done
    echo "0 $hex $len"
}

u256_eth() {
    python3 -c "v=int($1 * 10**18); print(f'{v} 0')"
}

echo "==========================================="
echo "  Redeploying Pool2 (tBTC/USDC)"
echo "==========================================="

cd contracts

# Step 1: Declare
echo ""
echo "=== Step 1: Declare contracts ==="
HASH_SL=$(sn_declare "SlToken")
HASH_DEBT=$(sn_declare "DebtToken")
HASH_POOL=$(sn_declare "LendingPool")

# Step 2: Deploy tokens + pool
echo ""
echo "=== Step 2: Deploy new Pool2 ==="

SL_NAME=$(encode_short_string "SL tBTC-USDC")
SL_SYM=$(encode_short_string "slTBTC-USDC")
ADDR_SL=$(sn_deploy "$HASH_SL" $SL_NAME $SL_SYM "$OWNER")
echo "  SlToken: $ADDR_SL"

DT_NAME=$(encode_short_string "Debt tBTC-USDC")
DT_SYM=$(encode_short_string "dTBTC-USDC")
ADDR_DT=$(sn_deploy "$HASH_DEBT" $DT_NAME $DT_SYM "$OWNER")
echo "  DebtToken: $ADDR_DT"

ADDR_POOL=$(sn_deploy "$HASH_POOL" \
    "$TBTC" "$USDC" "$ADDR_SL" "$ADDR_DT" \
    "$ORACLE" "$IRM" \
    7000 0 7500 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "  LendingPool: $ADDR_POOL"

# Step 3: Wire up
echo ""
echo "=== Step 3: Configure ==="
echo "  Setting pool on SlToken..."
sn_invoke --contract-address "$ADDR_SL" --function set_pool --calldata "$ADDR_POOL"
echo "  Setting pool on DebtToken..."
sn_invoke --contract-address "$ADDR_DT" --function set_pool --calldata "$ADDR_POOL"
echo "  Registering market on factory..."
sn_invoke --contract-address "$FACTORY" --function register_market \
    --calldata "$ADDR_POOL" "$TBTC" "$USDC" 7000 0 7500 0
echo "  Authorizing pool on NullifierRegistry..."
sn_invoke --contract-address "$NR" --function authorize_pool --calldata "$ADDR_POOL"

cd ..

# Step 4: Fund + Seed
echo ""
echo "=== Step 4: Fund pool with USDC ==="
sn_invoke --contract-address "$USDC" --function "mint" \
    --calldata "$ADDR_POOL $(u256_eth 1000000)"

echo ""
echo "=== Step 5: Deposit 8 tBTC collateral ==="
echo "  Minting tBTC..."
sn_invoke --contract-address "$TBTC" --function "mint" \
    --calldata "$OWNER $(u256_eth 100)"
echo "  Approving..."
sn_invoke --contract-address "$TBTC" --function "approve" \
    --calldata "$ADDR_POOL $(u256_eth 8)"
echo "  Depositing..."
sn_invoke --contract-address "$ADDR_POOL" --function "deposit" \
    --calldata "$(u256_eth 8)"

echo ""
echo "=== Step 6: Borrow 3 USDC (~37.5% util) ==="
sn_invoke --contract-address "$ADDR_POOL" --function "borrow" \
    --calldata "$(u256_eth 3)"

echo ""
echo "==========================================="
echo "  Pool2 Redeployment Complete!"
echo "==========================================="
echo ""
echo "  New addresses — update .env and frontend:"
echo "  POOL_TBTC_USDC=$ADDR_POOL"
echo "  SL_TBTC_USDC=$ADDR_SL"
echo "  DEBT_TBTC_USDC=$ADDR_DT"
echo ""
echo "  Frontend .env.local:"
echo "  NEXT_PUBLIC_POOL_TBTC_USDC=$ADDR_POOL"
echo "  NEXT_PUBLIC_SL_TOKEN_2=$ADDR_SL"
