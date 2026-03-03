// FlashLoanVault — Uncollateralized instant loans repaid within the same transaction
// Supports both transparent and shielded flash loans.
// Fee: 0.09% (9 BPS) of the borrowed amount.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IFlashLoanReceiver<TContractState> {
    /// Called by the vault after transferring the flash loan amount.
    /// Must return the loan + fee to the vault before returning.
    fn on_flash_loan(
        ref self: TContractState,
        initiator: ContractAddress,
        token: ContractAddress,
        amount: u256,
        fee: u256,
        data: Array<felt252>,
    ) -> bool;
}

#[starknet::interface]
pub trait IFlashLoanVault<TContractState> {
    fn flash_loan(
        ref self: TContractState,
        receiver: ContractAddress,
        token: ContractAddress,
        amount: u256,
        data: Array<felt252>,
    );
    fn get_flash_loan_fee_bps(self: @TContractState) -> u256;
    fn get_total_fees_collected(self: @TContractState, token: ContractAddress) -> u256;
}

#[starknet::contract]
pub mod FlashLoanVault {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use openzeppelin::interfaces::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use shieldlend::utils::constants::FLASH_LOAN_FEE_BPS;
    use shieldlend::utils::math::bps_mul;

    use super::{IFlashLoanReceiverDispatcher, IFlashLoanReceiverDispatcherTrait};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        fee_bps: u256,
        // token => total fees collected
        fees_collected: Map<ContractAddress, u256>,
        // Reentrancy guard
        locked: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FlashLoan: FlashLoan,
    }

    #[derive(Drop, starknet::Event)]
    struct FlashLoan {
        #[key]
        receiver: ContractAddress,
        #[key]
        token: ContractAddress,
        amount: u256,
        fee: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.fee_bps.write(FLASH_LOAN_FEE_BPS);
        self.locked.write(false);
    }

    #[abi(embed_v0)]
    impl FlashLoanVaultImpl of super::IFlashLoanVault<ContractState> {
        fn flash_loan(
            ref self: ContractState,
            receiver: ContractAddress,
            token: ContractAddress,
            amount: u256,
            data: Array<felt252>,
        ) {
            // Reentrancy guard
            assert(!self.locked.read(), 'SL: reentrancy');
            self.locked.write(true);

            assert(amount > 0, 'SL: amount is zero');

            let this = get_contract_address();
            let caller = get_caller_address();
            let erc20 = ERC20ABIDispatcher { contract_address: token };

            // Record balance before
            let balance_before = erc20.balance_of(this);
            assert(balance_before >= amount, 'SL: insufficient liquidity');

            // Calculate fee
            let fee = bps_mul(amount, self.fee_bps.read());

            // Transfer loan to receiver
            erc20.transfer(receiver, amount);

            // Callback to receiver
            let receiver_contract = IFlashLoanReceiverDispatcher {
                contract_address: receiver,
            };
            let success = receiver_contract.on_flash_loan(caller, token, amount, fee, data);
            assert(success, 'SL: callback failed');

            // Verify repayment: balance must be >= balance_before + fee
            let balance_after = erc20.balance_of(this);
            assert(balance_after >= balance_before + fee, 'SL: flash loan not repaid');

            // Track fees
            let prev_fees = self.fees_collected.read(token);
            self.fees_collected.write(token, prev_fees + fee);

            // Release lock
            self.locked.write(false);

            self.emit(FlashLoan { receiver, token, amount, fee });
        }

        fn get_flash_loan_fee_bps(self: @ContractState) -> u256 {
            self.fee_bps.read()
        }

        fn get_total_fees_collected(self: @ContractState, token: ContractAddress) -> u256 {
            self.fees_collected.read(token)
        }
    }
}
