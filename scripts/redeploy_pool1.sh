#!/usr/bin/env bash
# ============================================================
# ShieldLend — Redeploy Pool1 (strkBTC/USDC) Only
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
STRK_BTC="${STRK_BTC_TOKEN:?}"
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
echo "  Redeploying Pool1 (strkBTC/USDC)"
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
echo "=== Step 2: Deploy new Pool1 ==="

SL_NAME=$(encode_short_string "SL strkBTC-USDC")
SL_SYM=$(encode_short_string "slBTC-USDC")
ADDR_SL=$(sn_deploy "$HASH_SL" $SL_NAME $SL_SYM "$OWNER")
echo "  SlToken: $ADDR_SL"

DT_NAME=$(encode_short_string "Debt strkBTC-USD")
DT_SYM=$(encode_short_string "dBTC-USDC")
ADDR_DT=$(sn_deploy "$HASH_DEBT" $DT_NAME $DT_SYM "$OWNER")
echo "  DebtToken: $ADDR_DT"

# LendingPool: collateral, loan, sl, debt, oracle, irm,
#   ltv_bps(u256), liq_threshold_bps(u256), liq_bonus_bps(u256), reserve_factor_bps(u256),
#   zk_verifier, commitment_store, nullifier_registry
ADDR_POOL=$(sn_deploy "$HASH_POOL" \
    "$STRK_BTC" "$USDC" "$ADDR_SL" "$ADDR_DT" \
    "$ORACLE" "$IRM" \
    7500 0 8000 0 500 0 1000 0 \
    "$ZK" "$CS" "$NR")
echo "  LendingPool: $ADDR_POOL"

# Step 3: Wire up
echo ""
echo "=== Step 3: Configure ==="
echo "  Setting pool on SlToken..."
sn_invoke --contract-address "$ADDR_SL" --function set_pool --calldata "$ADDR_POOL"
echo "  Setting pool on DebtToken..."
sn_invoke --contract-address "$ADDR_DT" --function set_pool --calldata "$ADDR_POOL"
echo "  Registering market on factory (may fail if already exists)..."
sn_invoke --contract-address "$FACTORY" --function register_market \
    --calldata "$ADDR_POOL" "$STRK_BTC" "$USDC" 7500 0 8000 0 || echo "  (already registered, ok)"
echo "  Authorizing pool on NullifierRegistry..."
sn_invoke --contract-address "$NR" --function authorize_pool --calldata "$ADDR_POOL"

cd ..

# Step 4: Fund pool with USDC liquidity
echo ""
echo "=== Step 4: Fund pool with USDC ==="
sn_invoke --contract-address "$USDC" --function "mint" \
    --calldata "$ADDR_POOL $(u256_eth 1000000)"

# Step 5: Seed with deposits + borrows for demo APY
echo ""
echo "=== Step 5: Deposit 10 strkBTC collateral ==="
echo "  Minting strkBTC..."
sn_invoke --contract-address "$STRK_BTC" --function "mint" \
    --calldata "$OWNER $(u256_eth 100)"
echo "  Approving..."
sn_invoke --contract-address "$STRK_BTC" --function "approve" \
    --calldata "$ADDR_POOL $(u256_eth 10)"
echo "  Depositing..."
sn_invoke --contract-address "$ADDR_POOL" --function "deposit" \
    --calldata "$(u256_eth 10)"

echo ""
echo "=== Step 6: Borrow 5 USDC (~50% util) ==="
sn_invoke --contract-address "$ADDR_POOL" --function "borrow" \
    --calldata "$(u256_eth 5)"

echo ""
echo "==========================================="
echo "  Pool1 Redeployment Complete!"
echo "==========================================="
echo ""
echo "  New addresses — update .env and frontend:"
echo "  POOL_STRKBTC_USDC=$ADDR_POOL"
echo "  SL_STRKBTC_USDC=$ADDR_SL"
echo "  DEBT_STRKBTC_USDC=$ADDR_DT"
echo ""
echo "  Frontend .env.local:"
echo "  NEXT_PUBLIC_POOL_STRKBTC_USDC=$ADDR_POOL"
echo "  NEXT_PUBLIC_SL_TOKEN_1=$ADDR_SL"
echo "  NEXT_PUBLIC_DEBT_TOKEN_1=$ADDR_DT"
