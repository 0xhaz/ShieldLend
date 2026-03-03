// SlToken — Interest-bearing receipt token (like Aave's aToken)
// Minted on deposit, burned on withdraw. Balance scales with supply index.
// Only the LendingPool can mint/burn.

use starknet::ContractAddress;

#[starknet::interface]
pub trait ISlToken<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn pool(self: @TContractState) -> ContractAddress;
    fn set_pool(ref self: TContractState, new_pool: ContractAddress);
}

#[starknet::contract]
pub mod SlToken {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20ImmutableConfig of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 18;
    }

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        pool_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        pool: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.pool_address.write(pool);
    }

    #[abi(embed_v0)]
    impl SlTokenImpl of super::ISlToken<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.assert_only_pool();
            self.erc20.mint(to, amount);
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.assert_only_pool();
            self.erc20.burn(from, amount);
        }

        fn pool(self: @ContractState) -> ContractAddress {
            self.pool_address.read()
        }

        fn set_pool(ref self: ContractState, new_pool: ContractAddress) {
            // Only current pool (initially the deployer) can reassign
            self.assert_only_pool();
            self.pool_address.write(new_pool);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_pool(self: @ContractState) {
            assert(get_caller_address() == self.pool_address.read(), 'SL: only pool');
        }
    }
}
