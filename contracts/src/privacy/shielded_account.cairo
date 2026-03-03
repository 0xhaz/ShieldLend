// ShieldedAccount — Manages encrypted note storage for privacy
// Each shielded operation creates a Note (commitment + encrypted metadata).
// The actual amounts are only known to the note owner (private key holder).

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ShieldedNote {
    pub commitment: felt252,        // Pedersen(amount, blinding)
    pub encrypted_amount: felt252,  // ElGamal ciphertext (simplified for MVP)
    pub note_type: u8,              // 0 = deposit, 1 = borrow
    pub pool: ContractAddress,      // Which lending pool this note belongs to
    pub leaf_index: u256,           // Index in the Merkle tree
}

#[starknet::interface]
pub trait IShieldedAccount<TContractState> {
    fn store_note(
        ref self: TContractState,
        commitment: felt252,
        encrypted_amount: felt252,
        note_type: u8,
        pool: ContractAddress,
        leaf_index: u256,
    );
    fn get_note(self: @TContractState, commitment: felt252) -> ShieldedNote;
    fn get_user_note_count(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_note(self: @TContractState, user: ContractAddress, index: u256) -> felt252;
}

#[starknet::contract]
pub mod ShieldedAccount {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::ShieldedNote;

    #[storage]
    struct Storage {
        // commitment => ShieldedNote
        notes: Map<felt252, ShieldedNote>,
        // user => note count
        user_note_counts: Map<ContractAddress, u256>,
        // (user, index) => commitment
        user_notes: Map<(ContractAddress, u256), felt252>,
        // Authorized pools that can store notes
        authorized_pools: Map<ContractAddress, bool>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NoteStored: NoteStored,
    }

    #[derive(Drop, starknet::Event)]
    struct NoteStored {
        #[key]
        commitment: felt252,
        note_type: u8,
        pool: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl ShieldedAccountImpl of super::IShieldedAccount<ContractState> {
        fn store_note(
            ref self: ContractState,
            commitment: felt252,
            encrypted_amount: felt252,
            note_type: u8,
            pool: ContractAddress,
            leaf_index: u256,
        ) {
            let caller = get_caller_address();
            assert(
                self.authorized_pools.read(caller) || caller == self.owner.read(),
                'SL: not authorized',
            );

            let note = ShieldedNote {
                commitment,
                encrypted_amount,
                note_type,
                pool,
                leaf_index,
            };
            self.notes.write(commitment, note);

            // Track note under the caller (pool) for indexing
            let count = self.user_note_counts.read(caller);
            self.user_notes.write((caller, count), commitment);
            self.user_note_counts.write(caller, count + 1);

            self.emit(NoteStored { commitment, note_type, pool });
        }

        fn get_note(self: @ContractState, commitment: felt252) -> ShieldedNote {
            self.notes.read(commitment)
        }

        fn get_user_note_count(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_note_counts.read(user)
        }

        fn get_user_note(self: @ContractState, user: ContractAddress, index: u256) -> felt252 {
            self.user_notes.read((user, index))
        }
    }

    #[external(v0)]
    fn authorize_pool(ref self: ContractState, pool: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
        self.authorized_pools.write(pool, true);
    }
}
