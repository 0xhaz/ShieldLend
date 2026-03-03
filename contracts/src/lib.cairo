// ShieldLend — Privacy-Native BTC Lending Protocol
// Module root

pub mod core {
    pub mod market_factory;
    pub mod lending_pool;
    pub mod flash_loan_vault;
    pub mod position_manager;
}

pub mod privacy {
    pub mod commitment_store;
    pub mod nullifier_registry;
    pub mod shielded_account;
    pub mod zk_verifier;
}

pub mod interest {
    pub mod rate_model;
    pub mod rate_accumulator;
}

pub mod liquidation {
    pub mod liquidation_engine;
    pub mod auction;
}

pub mod yield {
    pub mod yield_tokenizer;
    pub mod principal_token;
    pub mod yield_token;
}

pub mod tokens {
    pub mod sl_token;
    pub mod debt_token;
    pub mod mock_erc20;
}

pub mod oracle {
    pub mod pragma_adapter;
}

pub mod utils {
    pub mod math;
    pub mod errors;
    pub mod constants;
}
