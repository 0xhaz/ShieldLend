#!/usr/bin/env bash
# ============================================================
# ShieldLend — Full Contract Deployment Script
# ============================================================
# Usage:
#   1. cp .env.example .env && edit .env
#   2. cd contracts && scarb build && cd ..
#   3. ./scripts/deploy.sh
#
# Prerequisites:
#   - sncast v0.57+ (starknet-foundry)
#   - Contracts compiled (scarb build)
#   - .env with STARKNET_ACCOUNT_ADDRESS set
#
# This script:
#   1. Loads .env
#   2. Declares all contract classes
#   3. Deploys contracts in dependency order
#   4. Prints all addresses (paste into .env)
# ============================================================

set -euo pipefail

# Load .env
if [ -f .env ]; then
    set -a; source .env; set +a
    echo "Loaded .env"
else
    echo "ERROR: .env not found. Run: cp .env.example .env"
    exit 1
fi

OWNER="${STARKNET_ACCOUNT_ADDRESS:?Set STARKNET_ACCOUNT_ADDRESS in .env}"
NETWORK="${STARKNET_NETWORK:-sepolia}"
CONTRACTS_DIR="contracts"
TARGET_DIR="$CONTRACTS_DIR/target/dev"

# RPC URL
if [ -n "${STARKNET_RPC_URL:-}" ]; then
    RPC_URL="$STARKNET_RPC_URL"
elif [ "$NETWORK" = "sepolia" ]; then
    RPC_URL="https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_10"
else
    RPC_URL="http://localhost:5050/rpc"
fi

# sncast base args — in v0.57+, --account and --wait are global, --url is subcommand-level
SNCAST_GLOBAL="sncast --wait"
if [ -n "${STARKNET_ACCOUNT_NAME:-}" ]; then
    SNCAST_GLOBAL="sncast --wait --account $STARKNET_ACCOUNT_NAME"
fi
SNCAST_URL="--url $RPC_URL"

echo "=========================================="
echo "  ShieldLend Deployment"
echo "  Network: $NETWORK"
echo "  RPC:     $RPC_URL"
echo "  Owner:   $OWNER"
echo "=========================================="

# Verify build
if [ ! -d "$TARGET_DIR" ]; then
    echo ""
    echo "Building contracts..."
    (cd "$CONTRACTS_DIR" && scarb build)
fi

# sncast must run from the contracts directory to find Scarb.toml
cd "$CONTRACTS_DIR"

# ---- Helper: declare and capture class hash ----
declare_and_get_hash() {
    local name=$1
    echo "  Declaring $name..." >&2
    local output
    output=$($SNCAST_GLOBAL declare \
        --contract-name "$name" \
        $SNCAST_URL 2>&1) || true

    # Extract class hash from "Class Hash:" line specifically
    local hash
    hash=$(echo "$output" | grep -i "class.hash" | grep -oE '0x[0-9a-fA-F]+' | head -1)

    if [ -z "$hash" ]; then
        # May already be declared — try to find class hash in error output
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

# ---- Helper: deploy and capture contract address ----
deploy_contract() {
    local class_hash=$1
    shift
    local calldata="$*"

    local output
    output=$($SNCAST_GLOBAL deploy \
        --class-hash "$class_hash" \
        --constructor-calldata $calldata \
        $SNCAST_URL 2>&1) || true

    # Extract contract address from output
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

echo ""
echo "Step 1: Declaring all contract classes..."
echo "=========================================="

HASH_ORACLE=$(declare_and_get_hash "PragmaAdapter")
HASH_IRM=$(declare_and_get_hash "InterestRateModel")
HASH_SLTOKEN=$(declare_and_get_hash "SlToken")
HASH_DEBTTOKEN=$(declare_and_get_hash "DebtToken")
HASH_POOL=$(declare_and_get_hash "LendingPool")
HASH_FACTORY=$(declare_and_get_hash "MarketFactory")
HASH_FLASH=$(declare_and_get_hash "FlashLoanVault")
HASH_CS=$(declare_and_get_hash "CommitmentStore")
HASH_NR=$(declare_and_get_hash "NullifierRegistry")
HASH_ZK=$(declare_and_get_hash "ZkVerifier")
HASH_SA=$(declare_and_get_hash "ShieldedAccount")
HASH_LIQ=$(declare_and_get_hash "LiquidationEngine")
HASH_AUCTION=$(declare_and_get_hash "DutchAuction")
HASH_TOKENIZER=$(declare_and_get_hash "YieldTokenizer")
HASH_PT=$(declare_and_get_hash "PrincipalToken")
HASH_YT=$(declare_and_get_hash "YieldToken")

echo ""
echo "Step 2: Deploying contracts..."
echo "=========================================="

# 1. Oracle (constructor: owner)
echo "Deploying Oracle..."
ADDR_ORACLE=$(deploy_contract "$HASH_ORACLE" "$OWNER")
echo "  Oracle: $ADDR_ORACLE"

# 2. Interest Rate Model (constructor: base_rate, slope1, slope2, optimal_util)
echo "Deploying InterestRateModel..."
# 2% RAY, 4% RAY, 75% RAY, 80% BPS — each u256 needs low + high felt
ADDR_IRM=$(deploy_contract "$HASH_IRM" \
    20000000000000000000000000 0 \
    40000000000000000000000000 0 \
    750000000000000000000000000 0 \
    8000 0)
echo "  InterestRateModel: $ADDR_IRM"

# 3. MarketFactory (constructor: owner)
echo "Deploying MarketFactory..."
ADDR_FACTORY=$(deploy_contract "$HASH_FACTORY" "$OWNER")
echo "  MarketFactory: $ADDR_FACTORY"

# 4. FlashLoanVault (constructor: owner)
echo "Deploying FlashLoanVault..."
ADDR_FLASH=$(deploy_contract "$HASH_FLASH" "$OWNER")
echo "  FlashLoanVault: $ADDR_FLASH"

# 5. Privacy contracts
echo "Deploying CommitmentStore..."
ADDR_CS=$(deploy_contract "$HASH_CS" "$OWNER")
echo "  CommitmentStore: $ADDR_CS"

echo "Deploying NullifierRegistry..."
ADDR_NR=$(deploy_contract "$HASH_NR" "$OWNER")
echo "  NullifierRegistry: $ADDR_NR"

echo "Deploying ZkVerifier..."
ADDR_ZK=$(deploy_contract "$HASH_ZK" "$OWNER")
echo "  ZkVerifier: $ADDR_ZK"

echo "Deploying ShieldedAccount..."
ADDR_SA=$(deploy_contract "$HASH_SA" "$OWNER")
echo "  ShieldedAccount: $ADDR_SA"

# 6. Liquidation contracts
echo "Deploying LiquidationEngine..."
ADDR_LIQ=$(deploy_contract "$HASH_LIQ" "$OWNER" "$ADDR_ORACLE")
echo "  LiquidationEngine: $ADDR_LIQ"

echo "Deploying DutchAuction..."
ADDR_AUCTION=$(deploy_contract "$HASH_AUCTION" "$OWNER")
echo "  DutchAuction: $ADDR_AUCTION"

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "Paste these into your .env file:"
echo ""
echo "# ---- Deployed Contract Addresses ----"
echo "MARKET_FACTORY_ADDRESS=$ADDR_FACTORY"
echo "FLASH_LOAN_VAULT_ADDRESS=$ADDR_FLASH"
echo "INTEREST_RATE_MODEL_ADDRESS=$ADDR_IRM"
echo "ORACLE_ADDRESS=$ADDR_ORACLE"
echo "COMMITMENT_STORE_ADDRESS=$ADDR_CS"
echo "NULLIFIER_REGISTRY_ADDRESS=$ADDR_NR"
echo "ZK_VERIFIER_ADDRESS=$ADDR_ZK"
echo "SHIELDED_ACCOUNT_ADDRESS=$ADDR_SA"
echo "LIQUIDATION_ENGINE_ADDRESS=$ADDR_LIQ"
echo "AUCTION_ADDRESS=$ADDR_AUCTION"
echo ""
echo "For frontend/.env.local:"
echo ""
echo "NEXT_PUBLIC_MARKET_FACTORY=$ADDR_FACTORY"
echo "NEXT_PUBLIC_FLASH_LOAN_VAULT=$ADDR_FLASH"
echo "NEXT_PUBLIC_ORACLE=$ADDR_ORACLE"
echo "NEXT_PUBLIC_COMMITMENT_STORE=$ADDR_CS"
echo "NEXT_PUBLIC_NULLIFIER_REGISTRY=$ADDR_NR"
echo "NEXT_PUBLIC_ZK_VERIFIER=$ADDR_ZK"
echo "NEXT_PUBLIC_LIQUIDATION_ENGINE=$ADDR_LIQ"
echo "NEXT_PUBLIC_AUCTION=$ADDR_AUCTION"
echo ""
echo "NOTE: LendingPool, SlToken, DebtToken, and YieldTokenizer"
echo "require market-specific deployment. Use scripts/setup_markets.sh"
echo "to create markets with their associated token contracts."
