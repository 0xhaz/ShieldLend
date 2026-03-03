// DutchAuction — Decreasing price auction for liquidated collateral
// Price starts high and decreases over time until a buyer is found.

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct AuctionInfo {
    pub auction_id: u256,
    pub seller: ContractAddress,
    pub collateral_token: ContractAddress,
    pub loan_token: ContractAddress,
    pub collateral_amount: u256,
    pub start_price: u256,
    pub end_price: u256,
    pub start_time: u64,
    pub duration: u64,
    pub is_active: bool,
}

#[starknet::interface]
pub trait IDutchAuction<TContractState> {
    fn create_auction(
        ref self: TContractState,
        collateral_token: ContractAddress,
        loan_token: ContractAddress,
        collateral_amount: u256,
        start_price: u256,
        end_price: u256,
        duration: u64,
    ) -> u256;
    fn buy(ref self: TContractState, auction_id: u256) -> u256;
    fn get_current_price(self: @TContractState, auction_id: u256) -> u256;
    fn get_auction(self: @TContractState, auction_id: u256) -> AuctionInfo;
    fn get_auction_count(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod DutchAuction {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use openzeppelin::interfaces::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use super::AuctionInfo;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        auction_count: u256,
        auction_sellers: Map<u256, ContractAddress>,
        auction_col_tokens: Map<u256, ContractAddress>,
        auction_loan_tokens: Map<u256, ContractAddress>,
        auction_col_amounts: Map<u256, u256>,
        auction_start_prices: Map<u256, u256>,
        auction_end_prices: Map<u256, u256>,
        auction_start_times: Map<u256, u64>,
        auction_durations: Map<u256, u64>,
        auction_active: Map<u256, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AuctionCreated: AuctionCreated,
        AuctionSettled: AuctionSettled,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionCreated {
        #[key]
        auction_id: u256,
        collateral_amount: u256,
        start_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AuctionSettled {
        #[key]
        auction_id: u256,
        buyer: ContractAddress,
        price_paid: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.auction_count.write(0);
    }

    #[abi(embed_v0)]
    impl DutchAuctionImpl of super::IDutchAuction<ContractState> {
        fn create_auction(
            ref self: ContractState,
            collateral_token: ContractAddress,
            loan_token: ContractAddress,
            collateral_amount: u256,
            start_price: u256,
            end_price: u256,
            duration: u64,
        ) -> u256 {
            assert(collateral_amount > 0, 'SL: amount is zero');
            assert(start_price > end_price, 'SL: invalid price range');
            assert(duration > 0, 'SL: invalid duration');

            let caller = get_caller_address();
            let this = get_contract_address();

            // Transfer collateral to auction contract
            let col_erc20 = ERC20ABIDispatcher { contract_address: collateral_token };
            col_erc20.transfer_from(caller, this, collateral_amount);

            let auction_id = self.auction_count.read() + 1;
            self.auction_count.write(auction_id);

            self.auction_sellers.write(auction_id, caller);
            self.auction_col_tokens.write(auction_id, collateral_token);
            self.auction_loan_tokens.write(auction_id, loan_token);
            self.auction_col_amounts.write(auction_id, collateral_amount);
            self.auction_start_prices.write(auction_id, start_price);
            self.auction_end_prices.write(auction_id, end_price);
            self.auction_start_times.write(auction_id, get_block_timestamp());
            self.auction_durations.write(auction_id, duration);
            self.auction_active.write(auction_id, true);

            self.emit(AuctionCreated { auction_id, collateral_amount, start_price });
            auction_id
        }

        fn buy(ref self: ContractState, auction_id: u256) -> u256 {
            assert(self.auction_active.read(auction_id), 'SL: auction not active');

            let price = self.get_current_price(auction_id);
            let col_amount = self.auction_col_amounts.read(auction_id);
            let loan_token = self.auction_loan_tokens.read(auction_id);
            let col_token = self.auction_col_tokens.read(auction_id);
            let seller = self.auction_sellers.read(auction_id);
            let caller = get_caller_address();

            // total_cost = price * col_amount / WAD (price is WAD-scaled per unit)
            let total_cost = price * col_amount / 1_000_000_000_000_000_000;

            // Buyer pays in loan tokens
            let loan_erc20 = ERC20ABIDispatcher { contract_address: loan_token };
            loan_erc20.transfer_from(caller, seller, total_cost);

            // Buyer receives collateral
            let col_erc20 = ERC20ABIDispatcher { contract_address: col_token };
            col_erc20.transfer(caller, col_amount);

            self.auction_active.write(auction_id, false);

            self.emit(AuctionSettled { auction_id, buyer: caller, price_paid: total_cost });
            total_cost
        }

        fn get_current_price(self: @ContractState, auction_id: u256) -> u256 {
            let start_price = self.auction_start_prices.read(auction_id);
            let end_price = self.auction_end_prices.read(auction_id);
            let start_time = self.auction_start_times.read(auction_id);
            let duration = self.auction_durations.read(auction_id);

            let now = get_block_timestamp();
            let elapsed = if now > start_time { now - start_time } else { 0 };

            if elapsed >= duration {
                return end_price;
            }

            // Linear decay: price = start - (start - end) * elapsed / duration
            let price_range = start_price - end_price;
            let elapsed_u256: u256 = elapsed.into();
            let duration_u256: u256 = duration.into();
            let decay = price_range * elapsed_u256 / duration_u256;

            start_price - decay
        }

        fn get_auction(self: @ContractState, auction_id: u256) -> AuctionInfo {
            AuctionInfo {
                auction_id,
                seller: self.auction_sellers.read(auction_id),
                collateral_token: self.auction_col_tokens.read(auction_id),
                loan_token: self.auction_loan_tokens.read(auction_id),
                collateral_amount: self.auction_col_amounts.read(auction_id),
                start_price: self.auction_start_prices.read(auction_id),
                end_price: self.auction_end_prices.read(auction_id),
                start_time: self.auction_start_times.read(auction_id),
                duration: self.auction_durations.read(auction_id),
                is_active: self.auction_active.read(auction_id),
            }
        }

        fn get_auction_count(self: @ContractState) -> u256 {
            self.auction_count.read()
        }
    }
}
