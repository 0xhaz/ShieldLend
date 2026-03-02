// Commitment Store — Merkle tree of Pedersen commitments
// Stores shielded deposit and borrow notes
// Based on Tornado Cash / Semaphore Merkle tree pattern adapted for Cairo

use core::pedersen::pedersen;
use shieldlend::utils::constants::MERKLE_TREE_DEPTH;
use shieldlend::utils::errors::Errors;

#[starknet::interface]
trait ICommitmentStore<TContractState> {
    /// Insert a new commitment into the Merkle tree
    fn insert(ref self: TContractState, commitment: felt252) -> u256; // returns leaf index

    /// Get the current Merkle root
    fn get_root(self: @TContractState) -> felt252;

    /// Check if a root was valid at any point (for historical proofs)
    fn is_known_root(self: @TContractState, root: felt252) -> bool;

    /// Get the next available leaf index
    fn get_next_index(self: @TContractState) -> u256;

    /// Get total number of commitments
    fn get_commitment_count(self: @TContractState) -> u256;
}

#[starknet::contract]
mod CommitmentStore {
    use core::pedersen::pedersen;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::Errors;

    const TREE_DEPTH: u32 = 20;
    const MAX_LEAVES: u256 = 1_048_576; // 2^20

    #[storage]
    struct Storage {
        // Merkle tree nodes: level => index => hash
        tree: Map<(u32, u256), felt252>,
        // Current root
        current_root: felt252,
        // Historical roots (for proof validation)
        root_history: Map<felt252, bool>,
        // Next leaf index
        next_index: u256,
        // Zero values per level (precomputed)
        zeros: Map<u32, felt252>,
        // Access control
        authorized_pool: starknet::ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        authorized_pool: starknet::ContractAddress,
    ) {
        self.authorized_pool.write(authorized_pool);
        self.next_index.write(0);

        // Precompute zero values for each level
        // zeros[0] = 0 (empty leaf)
        // zeros[i] = H(zeros[i-1], zeros[i-1])
        let mut current_zero: felt252 = 0;
        let mut i: u32 = 0;
        loop {
            if i > TREE_DEPTH {
                break;
            }
            self.zeros.write(i, current_zero);
            if i < TREE_DEPTH {
                current_zero = pedersen(current_zero, current_zero);
            }
            i += 1;
        };

        // Set initial root
        self.current_root.write(current_zero);
        self.root_history.write(current_zero, true);
    }

    #[abi(embed_v0)]
    impl CommitmentStoreImpl of super::ICommitmentStore<ContractState> {

        fn insert(ref self: ContractState, commitment: felt252) -> u256 {
            let index = self.next_index.read();
            assert(index < MAX_LEAVES, 'SL: tree is full');

            // Insert leaf
            self.tree.write((0, index), commitment);

            // Update path to root
            let mut current_hash = commitment;
            let mut current_index = index;
            let mut level: u32 = 0;

            loop {
                if level >= TREE_DEPTH {
                    break;
                }

                let (left, right) = if current_index % 2 == 0 {
                    // We're the left child
                    let right = self.get_node(level, current_index + 1);
                    (current_hash, right)
                } else {
                    // We're the right child
                    let left = self.get_node(level, current_index - 1);
                    (left, current_hash)
                };

                current_hash = pedersen(left, right);
                current_index = current_index / 2;
                level += 1;

                self.tree.write((level, current_index), current_hash);
            };

            // Update root
            self.current_root.write(current_hash);
            self.root_history.write(current_hash, true);

            // Increment index
            self.next_index.write(index + 1);

            index
        }

        fn get_root(self: @ContractState) -> felt252 {
            self.current_root.read()
        }

        fn is_known_root(self: @ContractState, root: felt252) -> bool {
            self.root_history.read(root)
        }

        fn get_next_index(self: @ContractState) -> u256 {
            self.next_index.read()
        }

        fn get_commitment_count(self: @ContractState) -> u256 {
            self.next_index.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_node(self: @ContractState, level: u32, index: u256) -> felt252 {
            let stored = self.tree.read((level, index));
            if stored == 0 {
                self.zeros.read(level)
            } else {
                stored
            }
        }
    }
}
