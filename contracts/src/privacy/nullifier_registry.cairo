// Nullifier Registry — prevents double-spending of shielded notes
// Each shielded action (withdraw, borrow) consumes a nullifier
// Once used, the same note cannot be spent again

use shieldlend::utils::errors::Errors;

#[starknet::interface]
trait INullifierRegistry<TContractState> {
    /// Check if a nullifier has been used
    fn is_spent(self: @TContractState, nullifier: felt252) -> bool;

    /// Mark a nullifier as spent (only callable by authorized pools)
    fn spend(ref self: TContractState, nullifier: felt252);

    /// Batch check nullifiers
    fn are_spent(self: @TContractState, nullifiers: Array<felt252>) -> Array<bool>;
}

#[starknet::contract]
mod NullifierRegistry {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::Errors;

    #[storage]
    struct Storage {
        spent_nullifiers: Map<felt252, bool>,
        authorized_pools: Map<ContractAddress, bool>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NullifierSpent: NullifierSpent,
        PoolAuthorized: PoolAuthorized,
    }

    #[derive(Drop, starknet::Event)]
    struct NullifierSpent {
        #[key]
        nullifier: felt252,
        pool: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PoolAuthorized {
        #[key]
        pool: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl NullifierRegistryImpl of super::INullifierRegistry<ContractState> {

        fn is_spent(self: @ContractState, nullifier: felt252) -> bool {
            self.spent_nullifiers.read(nullifier)
        }

        fn spend(ref self: ContractState, nullifier: felt252) {
            // Only authorized lending pools can spend nullifiers
            let caller = get_caller_address();
            assert(self.authorized_pools.read(caller), Errors::NOT_AUTHORIZED);
            assert(!self.spent_nullifiers.read(nullifier), Errors::NULLIFIER_ALREADY_USED);

            self.spent_nullifiers.write(nullifier, true);

            self.emit(NullifierSpent { nullifier, pool: caller });
        }

        fn are_spent(self: @ContractState, nullifiers: Array<felt252>) -> Array<bool> {
            let mut results = ArrayTrait::new();
            let mut i: u32 = 0;
            loop {
                if i >= nullifiers.len() {
                    break;
                }
                results.append(self.spent_nullifiers.read(*nullifiers.at(i)));
                i += 1;
            };
            results
        }
    }

    // Admin functions
    #[external(v0)]
    fn authorize_pool(ref self: ContractState, pool: ContractAddress) {
        assert(get_caller_address() == self.owner.read(), Errors::NOT_AUTHORIZED);
        self.authorized_pools.write(pool, true);
        self.emit(PoolAuthorized { pool });
    }
}
