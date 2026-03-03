#!/usr/bin/env bash
# ============================================================
# ShieldLend — Yield Tokenization Deployment Script
# ============================================================
# Deploys per-market:
#   1. YieldTokenizer (with pt=0, yt=0)
#   2. PrincipalToken (with tokenizer address)
#   3. YieldToken (with tokenizer address)
#   4. Calls set_tokens on YieldTokenizer
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

SNCAST_GLOBAL="sncast --wait"
if [ -n "${STARKNET_ACCOUNT_NAME:-}" ]; then
    SNCAST_GLOBAL="sncast --wait --account $STARKNET_ACCOUNT_NAME"
fi
SNCAST_URL="--url $RPC_URL"

# SL token addresses (from .env)
SL1="${SL_STRKBTC_USDC:?Set SL_STRKBTC_USDC in .env}"
SL2="${SL_TBTC_USDC:?Set SL_TBTC_USDC in .env}"
SL3="${SL_STRKBTC_TBTC:?Set SL_STRKBTC_TBTC in .env}"

# Maturity: June 30, 2026 00:00 UTC = 1782777600
MATURITY=1782777600

echo "==========================================="
echo "  ShieldLend Yield Deployment"
echo "  Owner:    $OWNER"
echo "  Maturity: $MATURITY (June 30, 2026)"
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

# ByteArray encoding for short strings (<=31 chars)
encode_short_string() {
    local str=$1
    local len=${#str}
    local hex="0x"
    for (( i=0; i<len; i++ )); do
        hex+=$(printf '%02x' "'${str:$i:1}")
    done
    echo "0 $hex $len"
}

echo ""
echo "Step 1: Declare contracts..."
echo "==========================================="

HASH_TOKENIZER=$(declare_and_get_hash "YieldTokenizer")
HASH_PT=$(declare_and_get_hash "PrincipalToken")
HASH_YT=$(declare_and_get_hash "YieldToken")

echo ""
echo "  YieldTokenizer class: $HASH_TOKENIZER"
echo "  PrincipalToken class: $HASH_PT"
echo "  YieldToken class:     $HASH_YT"

# ============================================================
# Deploy per-market yield tokenizers
# ============================================================

deploy_yield_market() {
    local market_name=$1
    local sl_token=$2
    local pt_name_str=$3
    local pt_symbol_str=$4
    local yt_name_str=$5
    local yt_symbol_str=$6

    echo ""
    echo "  Deploying YieldTokenizer for $market_name..."
    echo "  ---"

    # YieldTokenizer constructor: (owner, sl_token, pt_token, yt_token, maturity)
    # Deploy with pt=0x0, yt=0x0 initially
    local tokenizer_addr
    tokenizer_addr=$(deploy_contract "$HASH_TOKENIZER" \
        "$OWNER" "$sl_token" 0x0 0x0 "$MATURITY")
    echo "    YieldTokenizer: $tokenizer_addr"

    # PrincipalToken constructor: (name: ByteArray, symbol: ByteArray, tokenizer: ContractAddress, maturity: u64)
    echo "  Deploying PrincipalToken ($pt_symbol_str)..."
    local pt_name=$(encode_short_string "$pt_name_str")
    local pt_symbol=$(encode_short_string "$pt_symbol_str")
    local pt_addr
    pt_addr=$(deploy_contract "$HASH_PT" $pt_name $pt_symbol "$tokenizer_addr" "$MATURITY")
    echo "    PrincipalToken: $pt_addr"

    # YieldToken constructor: (name: ByteArray, symbol: ByteArray, tokenizer: ContractAddress, maturity: u64)
    echo "  Deploying YieldToken ($yt_symbol_str)..."
    local yt_name=$(encode_short_string "$yt_name_str")
    local yt_symbol=$(encode_short_string "$yt_symbol_str")
    local yt_addr
    yt_addr=$(deploy_contract "$HASH_YT" $yt_name $yt_symbol "$tokenizer_addr" "$MATURITY")
    echo "    YieldToken: $yt_addr"

    # Call set_tokens on YieldTokenizer
    echo "  Setting PT/YT on YieldTokenizer..."
    invoke_contract "$tokenizer_addr" "set_tokens" "$pt_addr" "$yt_addr"

    echo ""
    echo "  $market_name yield deployment complete:"
    echo "    TOKENIZER=$tokenizer_addr"
    echo "    PT=$pt_addr"
    echo "    YT=$yt_addr"

    # Return addresses (newline separated)
    echo "RESULT:$tokenizer_addr:$pt_addr:$yt_addr"
}

echo ""
echo "Step 2: Deploy Market 1 — strkBTC/USDC yield..."
echo "==========================================="
deploy_yield_market "strkBTC/USDC" "$SL1" \
    "PT slstrkBTC-USDC" "PT-slBTC" \
    "YT slstrkBTC-USDC" "YT-slBTC"

echo ""
echo "Step 3: Deploy Market 2 — tBTC/USDC yield..."
echo "==========================================="
deploy_yield_market "tBTC/USDC" "$SL2" \
    "PT sltBTC-USDC" "PT-slTBTC" \
    "YT sltBTC-USDC" "YT-slTBTC"

echo ""
echo "Step 4: Deploy Market 3 — strkBTC/tBTC yield..."
echo "==========================================="
deploy_yield_market "strkBTC/tBTC" "$SL3" \
    "PT slstrkBTC-tBTC" "PT-slBTCe" \
    "YT slstrkBTC-tBTC" "YT-slBTCe"

echo ""
echo "==========================================="
echo "  Yield Deployment Complete!"
echo "==========================================="
echo ""
echo "Update .env with the TOKENIZER, PT, and YT addresses above."
echo "Update frontend/.env.local with NEXT_PUBLIC_YIELD_TOKENIZER_* addresses."
