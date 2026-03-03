// DebtToken — Non-transferable debt tracking token
// Minted on borrow, burned on repay. Transfers are disabled.
// Only the LendingPool can mint/burn.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IDebtToken<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn pool(self: @TContractState) -> ContractAddress;
    fn set_pool(ref self: TContractState, new_pool: ContractAddress);
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn total_supply(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod DebtToken {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20ImmutableConfig of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 18;
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Block all transfers between non-zero addresses
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            // Allow mint (from == 0) and burn (recipient == 0)
            assert(
                from.is_zero() || recipient.is_zero(),
                'SL: debt not transferable',
            );
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {}
    }

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
    impl DebtTokenImpl of super::IDebtToken<ContractState> {
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
            self.assert_only_pool();
            self.pool_address.write(new_pool);
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_pool(self: @ContractState) {
            assert(get_caller_address() == self.pool_address.read(), 'SL: only pool');
        }
    }
}
