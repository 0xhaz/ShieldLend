// Contract ABIs and interaction helpers
// Minimal typed ABI subsets for frontend interactions

import { CONTRACTS, MARKET_POOLS } from "./constants";

// LendingPool ABI — matches contracts/src/core/lending_pool.cairo
export const LENDING_POOL_ABI = [
  {
    name: "deposit",
    type: "function",
    inputs: [{ name: "amount", type: "core::integer::u256" }],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "external",
  },
  {
    name: "withdraw",
    type: "function",
    inputs: [{ name: "sl_token_amount", type: "core::integer::u256" }],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "external",
  },
  {
    name: "borrow",
    type: "function",
    inputs: [{ name: "amount", type: "core::integer::u256" }],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "repay",
    type: "function",
    inputs: [{ name: "amount", type: "core::integer::u256" }],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "get_market_data",
    type: "function",
    inputs: [],
    outputs: [
      {
        type: "shieldlend::core::lending_pool::MarketData",
      },
    ],
    state_mutability: "view",
  },
  {
    name: "get_collateral_token",
    type: "function",
    inputs: [],
    outputs: [
      { type: "core::starknet::contract_address::ContractAddress" },
    ],
    state_mutability: "view",
  },
  {
    name: "get_loan_token",
    type: "function",
    inputs: [],
    outputs: [
      { type: "core::starknet::contract_address::ContractAddress" },
    ],
    state_mutability: "view",
  },
  {
    name: "get_ltv_bps",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "get_liquidation_threshold_bps",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  // ---- Shielded entrypoints ----
  {
    name: "shielded_deposit",
    type: "function",
    inputs: [
      { name: "amount", type: "core::integer::u256" },
      { name: "commitment", type: "core::felt252" },
      { name: "encrypted_amount", type: "core::felt252" },
      { name: "proof", type: "core::array::Array::<core::felt252>" },
    ],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "shielded_withdraw",
    type: "function",
    inputs: [
      { name: "amount", type: "core::integer::u256" },
      { name: "nullifier", type: "core::felt252" },
      { name: "change_commitment", type: "core::felt252" },
      { name: "merkle_root", type: "core::felt252" },
      { name: "proof", type: "core::array::Array::<core::felt252>" },
    ],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "shielded_borrow",
    type: "function",
    inputs: [
      { name: "amount", type: "core::integer::u256" },
      { name: "borrow_commitment", type: "core::felt252" },
      { name: "collateral_nullifier", type: "core::felt252" },
      { name: "merkle_root", type: "core::felt252" },
      { name: "encrypted_borrow_amount", type: "core::felt252" },
      { name: "proof", type: "core::array::Array::<core::felt252>" },
    ],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "shielded_repay",
    type: "function",
    inputs: [
      { name: "amount", type: "core::integer::u256" },
      { name: "debt_nullifier", type: "core::felt252" },
      { name: "new_debt_commitment", type: "core::felt252" },
      { name: "proof", type: "core::array::Array::<core::felt252>" },
    ],
    outputs: [],
    state_mutability: "external",
  },
] as const;

// CommitmentStore ABI — for reading Merkle root
export const COMMITMENT_STORE_ABI = [
  {
    name: "get_root",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::felt252" }],
    state_mutability: "view",
  },
  {
    name: "get_next_index",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "is_known_root",
    type: "function",
    inputs: [{ name: "root", type: "core::felt252" }],
    outputs: [{ type: "core::bool" }],
    state_mutability: "view",
  },
] as const;

// MarketFactory ABI — matches contracts/src/core/market_factory.cairo
export const MARKET_FACTORY_ABI = [
  {
    name: "get_market_count",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "get_market",
    type: "function",
    inputs: [{ name: "market_id", type: "core::integer::u256" }],
    outputs: [
      {
        type: "shieldlend::core::market_factory::MarketInfo",
      },
    ],
    state_mutability: "view",
  },
] as const;

// Oracle ABI — matches contracts/src/oracle/pragma_adapter.cairo
export const ORACLE_ABI = [
  {
    name: "get_price",
    type: "function",
    inputs: [
      {
        name: "asset",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
] as const;

// ERC20 ABI subset
export const ERC20_ABI = [
  {
    name: "balance_of",
    type: "function",
    inputs: [
      {
        name: "account",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "approve",
    type: "function",
    inputs: [
      {
        name: "spender",
        type: "core::starknet::contract_address::ContractAddress",
      },
      { name: "amount", type: "core::integer::u256" },
    ],
    outputs: [{ type: "core::bool" }],
    state_mutability: "external",
  },
  {
    name: "allowance",
    type: "function",
    inputs: [
      {
        name: "owner",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "spender",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "name",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::byte_array::ByteArray" }],
    state_mutability: "view",
  },
  {
    name: "symbol",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::byte_array::ByteArray" }],
    state_mutability: "view",
  },
] as const;

// MockERC20 faucet ABI
export const MOCK_ERC20_ABI = [
  ...ERC20_ABI,
  {
    name: "mint",
    type: "function",
    inputs: [
      {
        name: "to",
        type: "core::starknet::contract_address::ContractAddress",
      },
      { name: "amount", type: "core::integer::u256" },
    ],
    outputs: [],
    state_mutability: "external",
  },
] as const;

// Helper to get contract addresses
export function getContractAddress(name: keyof typeof CONTRACTS): string {
  return CONTRACTS[name];
}

export function getPoolAddress(marketName: keyof typeof MARKET_POOLS): string {
  return MARKET_POOLS[marketName];
}
