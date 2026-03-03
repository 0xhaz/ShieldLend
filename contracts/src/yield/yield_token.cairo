// YieldToken (YT) — ERC20 representing the yield component of a position
// Holder receives accrued yield (interest) until maturity.
// Only the YieldTokenizer can mint/burn.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IYieldToken<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn tokenizer(self: @TContractState) -> ContractAddress;
    fn maturity(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod YieldToken {
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
        tokenizer_address: ContractAddress,
        maturity_timestamp: u64,
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
        tokenizer: ContractAddress,
        maturity: u64,
    ) {
        self.erc20.initializer(name, symbol);
        self.tokenizer_address.write(tokenizer);
        self.maturity_timestamp.write(maturity);
    }

    #[abi(embed_v0)]
    impl YieldTokenImpl of super::IYieldToken<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.assert_only_tokenizer();
            self.erc20.mint(to, amount);
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.assert_only_tokenizer();
            self.erc20.burn(from, amount);
        }

        fn tokenizer(self: @ContractState) -> ContractAddress {
            self.tokenizer_address.read()
        }

        fn maturity(self: @ContractState) -> u64 {
            self.maturity_timestamp.read()
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_tokenizer(self: @ContractState) {
            assert(
                get_caller_address() == self.tokenizer_address.read(),
                'SL: only tokenizer',
            );
        }
    }
}
