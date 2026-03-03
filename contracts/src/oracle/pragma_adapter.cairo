// Pragma Oracle Adapter — Wraps Pragma price feeds for ShieldLend
// For hackathon MVP: admin-settable prices. In production: Pragma dispatcher.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IPragmaAdapter<TContractState> {
    fn get_price(self: @TContractState, asset: ContractAddress) -> u256;
    fn get_price_precision(self: @TContractState) -> u256;
    fn set_price(ref self: TContractState, asset: ContractAddress, price: u256);
}

#[starknet::contract]
pub mod PragmaAdapter {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    pub const PRICE_PRECISION: u256 = 100_000_000; // 1e8

    #[storage]
    struct Storage {
        asset_prices: Map<ContractAddress, u256>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PriceUpdated: PriceUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct PriceUpdated {
        #[key]
        asset: ContractAddress,
        price: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PragmaAdapterImpl of super::IPragmaAdapter<ContractState> {
        fn get_price(self: @ContractState, asset: ContractAddress) -> u256 {
            let price = self.asset_prices.read(asset);
            assert(price > 0, 'SL: price not available');
            price
        }

        fn get_price_precision(self: @ContractState) -> u256 {
            PRICE_PRECISION
        }

        fn set_price(ref self: ContractState, asset: ContractAddress, price: u256) {
            assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
            self.asset_prices.write(asset, price);
            self.emit(PriceUpdated { asset, price });
        }
    }
}
