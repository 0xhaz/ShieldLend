// YieldTokenizer — Splits slTokens into PrincipalToken (PT) + YieldToken (YT)
// PT represents the principal (redeemable at maturity for 1:1 underlying)
// YT represents the yield stream (accrued interest until maturity)
// Inspired by Pendle Finance's yield tokenization model.

use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct TokenizeInfo {
    pub sl_token: ContractAddress,
    pub pt_token: ContractAddress,
    pub yt_token: ContractAddress,
    pub maturity: u64,
    pub total_tokenized: u256,
    pub yield_index_at_tokenize: u256,
}

#[starknet::interface]
pub trait IYieldTokenizer<TContractState> {
    /// Set PT and YT token addresses (owner-only, one-time)
    fn set_tokens(ref self: TContractState, pt_token: ContractAddress, yt_token: ContractAddress);

    /// Split slTokens into PT + YT (equal amounts)
    fn tokenize(ref self: TContractState, sl_amount: u256) -> (u256, u256);

    /// Redeem PT + YT back to slTokens (before or after maturity)
    fn redeem(ref self: TContractState, pt_amount: u256, yt_amount: u256) -> u256;

    /// After maturity: redeem PT only for underlying
    fn redeem_pt(ref self: TContractState, pt_amount: u256) -> u256;

    /// Claim accrued yield from YT holdings
    fn claim_yield(ref self: TContractState) -> u256;

    /// Get info about the tokenizer configuration
    fn get_sl_token(self: @TContractState) -> ContractAddress;
    fn get_pt_token(self: @TContractState) -> ContractAddress;
    fn get_yt_token(self: @TContractState) -> ContractAddress;
    fn get_maturity(self: @TContractState) -> u64;
    fn get_total_tokenized(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod YieldTokenizer {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use shieldlend::yield::principal_token::{IPrincipalTokenDispatcher, IPrincipalTokenDispatcherTrait};
    use shieldlend::yield::yield_token::{IYieldTokenDispatcher, IYieldTokenDispatcherTrait};
    use openzeppelin::interfaces::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        sl_token: ContractAddress,
        pt_token: ContractAddress,
        yt_token: ContractAddress,
        maturity: u64,
        total_tokenized: u256,
        // user => last claimed yield index
        user_yield_index: Map<ContractAddress, u256>,
        // Current yield index (grows as interest accrues)
        yield_index: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Tokenized: Tokenized,
        Redeemed: Redeemed,
        YieldClaimed: YieldClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct Tokenized {
        #[key]
        user: ContractAddress,
        sl_amount: u256,
        pt_minted: u256,
        yt_minted: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Redeemed {
        #[key]
        user: ContractAddress,
        sl_returned: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct YieldClaimed {
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        sl_token: ContractAddress,
        pt_token: ContractAddress,
        yt_token: ContractAddress,
        maturity: u64,
    ) {
        assert(maturity > get_block_timestamp(), 'SL: maturity in past');
        self.owner.write(owner);
        self.sl_token.write(sl_token);
        self.pt_token.write(pt_token);
        self.yt_token.write(yt_token);
        self.maturity.write(maturity);
        self.total_tokenized.write(0);
        self.yield_index.write(1_000_000_000_000_000_000); // 1e18 (WAD)
    }

    #[abi(embed_v0)]
    impl YieldTokenizerImpl of super::IYieldTokenizer<ContractState> {
        fn set_tokens(ref self: ContractState, pt_token: ContractAddress, yt_token: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), 'SL: only owner');
            assert(self.pt_token.read().is_zero(), 'SL: tokens already set');
            self.pt_token.write(pt_token);
            self.yt_token.write(yt_token);
        }

        fn tokenize(ref self: ContractState, sl_amount: u256) -> (u256, u256) {
            assert(sl_amount > 0, 'SL: amount is zero');
            assert(get_block_timestamp() < self.maturity.read(), 'SL: past maturity');

            let caller = get_caller_address();
            let this = get_contract_address();

            // Transfer slTokens from user to tokenizer
            let sl = ERC20ABIDispatcher { contract_address: self.sl_token.read() };
            sl.transfer_from(caller, this, sl_amount);

            // Mint equal amounts of PT and YT
            let pt = IPrincipalTokenDispatcher { contract_address: self.pt_token.read() };
            let yt = IYieldTokenDispatcher { contract_address: self.yt_token.read() };
            pt.mint(caller, sl_amount);
            yt.mint(caller, sl_amount);

            // Track user's yield index
            self.user_yield_index.write(caller, self.yield_index.read());

            self.total_tokenized.write(self.total_tokenized.read() + sl_amount);

            self.emit(Tokenized {
                user: caller, sl_amount, pt_minted: sl_amount, yt_minted: sl_amount,
            });

            (sl_amount, sl_amount)
        }

        fn redeem(ref self: ContractState, pt_amount: u256, yt_amount: u256) -> u256 {
            assert(pt_amount > 0, 'SL: amount is zero');
            assert(pt_amount == yt_amount, 'SL: PT/YT mismatch');

            let caller = get_caller_address();

            // Burn PT and YT
            let pt = IPrincipalTokenDispatcher { contract_address: self.pt_token.read() };
            let yt = IYieldTokenDispatcher { contract_address: self.yt_token.read() };
            pt.burn(caller, pt_amount);
            yt.burn(caller, yt_amount);

            // Return slTokens
            let sl = ERC20ABIDispatcher { contract_address: self.sl_token.read() };
            sl.transfer(caller, pt_amount);

            let total = self.total_tokenized.read();
            if pt_amount >= total {
                self.total_tokenized.write(0);
            } else {
                self.total_tokenized.write(total - pt_amount);
            }

            self.emit(Redeemed { user: caller, sl_returned: pt_amount });
            pt_amount
        }

        fn redeem_pt(ref self: ContractState, pt_amount: u256) -> u256 {
            assert(pt_amount > 0, 'SL: amount is zero');
            assert(get_block_timestamp() >= self.maturity.read(), 'SL: not yet matured');

            let caller = get_caller_address();

            // Burn PT only (after maturity, PT alone is redeemable)
            let pt = IPrincipalTokenDispatcher { contract_address: self.pt_token.read() };
            pt.burn(caller, pt_amount);

            // Return slTokens 1:1
            let sl = ERC20ABIDispatcher { contract_address: self.sl_token.read() };
            sl.transfer(caller, pt_amount);

            let total = self.total_tokenized.read();
            if pt_amount >= total {
                self.total_tokenized.write(0);
            } else {
                self.total_tokenized.write(total - pt_amount);
            }

            self.emit(Redeemed { user: caller, sl_returned: pt_amount });
            pt_amount
        }

        fn claim_yield(ref self: ContractState) -> u256 {
            // MVP: yield claiming is simplified
            // In production: compute yield as difference between current and user's yield index
            // multiplied by their YT balance
            let caller = get_caller_address();
            let current_index = self.yield_index.read();
            let user_index = self.user_yield_index.read(caller);

            if current_index <= user_index || user_index == 0 {
                return 0;
            }

            let yt_erc20 = ERC20ABIDispatcher { contract_address: self.yt_token.read() };
            let yt_balance = yt_erc20.balance_of(caller);

            if yt_balance == 0 {
                return 0;
            }

            // yield = yt_balance * (current_index - user_index) / user_index
            let yield_amount = yt_balance * (current_index - user_index) / user_index;

            // Update user index
            self.user_yield_index.write(caller, current_index);

            if yield_amount > 0 {
                // Transfer yield from tokenizer's slToken balance
                let sl = ERC20ABIDispatcher { contract_address: self.sl_token.read() };
                sl.transfer(caller, yield_amount);

                self.emit(YieldClaimed { user: caller, amount: yield_amount });
            }

            yield_amount
        }

        fn get_sl_token(self: @ContractState) -> ContractAddress {
            self.sl_token.read()
        }

        fn get_pt_token(self: @ContractState) -> ContractAddress {
            self.pt_token.read()
        }

        fn get_yt_token(self: @ContractState) -> ContractAddress {
            self.yt_token.read()
        }

        fn get_maturity(self: @ContractState) -> u64 {
            self.maturity.read()
        }

        fn get_total_tokenized(self: @ContractState) -> u256 {
            self.total_tokenized.read()
        }
    }
}
