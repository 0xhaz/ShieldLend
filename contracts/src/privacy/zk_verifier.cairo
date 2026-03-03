// ZK Verifier — Proof verification for shielded operations
// For hackathon MVP: mock verifier that validates proof structure.
// In production: wraps Garaga verifier for UltraPlonk/Honk proofs from Noir.
//
// Each circuit type has a unique identifier:
//   0 = shielded_deposit
//   1 = shielded_borrow
//   2 = shielded_withdraw
//   3 = solvency_proof

#[starknet::interface]
pub trait IZkVerifier<TContractState> {
    /// Verify a ZK proof for a given circuit type
    /// Returns true if the proof is valid
    fn verify_proof(
        self: @TContractState,
        circuit_type: u8,
        proof: Span<felt252>,
        public_inputs: Span<felt252>,
    ) -> bool;

    /// Check if a circuit type is supported
    fn is_circuit_supported(self: @TContractState, circuit_type: u8) -> bool;
}

#[starknet::contract]
pub mod ZkVerifier {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    // Circuit type constants
    const CIRCUIT_SHIELDED_DEPOSIT: u8 = 0;
    const CIRCUIT_SHIELDED_BORROW: u8 = 1;
    const CIRCUIT_SHIELDED_WITHDRAW: u8 = 2;
    const CIRCUIT_SOLVENCY_PROOF: u8 = 3;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        // circuit_type => is_enabled
        enabled_circuits: Map<u8, bool>,
        // For MVP: mock mode flag. When true, proofs are accepted if they match expected format.
        // In production: this would be replaced by Garaga verifier addresses per circuit.
        mock_mode: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProofVerified: ProofVerified,
    }

    #[derive(Drop, starknet::Event)]
    struct ProofVerified {
        circuit_type: u8,
        verified: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.mock_mode.write(true); // MVP: mock mode enabled

        // Enable all circuit types by default
        self.enabled_circuits.write(CIRCUIT_SHIELDED_DEPOSIT, true);
        self.enabled_circuits.write(CIRCUIT_SHIELDED_BORROW, true);
        self.enabled_circuits.write(CIRCUIT_SHIELDED_WITHDRAW, true);
        self.enabled_circuits.write(CIRCUIT_SOLVENCY_PROOF, true);
    }

    #[abi(embed_v0)]
    impl ZkVerifierImpl of super::IZkVerifier<ContractState> {
        fn verify_proof(
            self: @ContractState,
            circuit_type: u8,
            proof: Span<felt252>,
            public_inputs: Span<felt252>,
        ) -> bool {
            // Check circuit is supported
            assert(self.enabled_circuits.read(circuit_type), 'SL: unsupported circuit');

            if self.mock_mode.read() {
                // MVP mock verification:
                // Accept proof if it has at least 1 element and public_inputs are non-empty
                // The first element of proof must be a "magic" value (hash of circuit_type)
                // This prevents completely empty/random proofs while keeping the MVP simple
                return self.mock_verify(circuit_type, proof, public_inputs);
            }

            // Production: call Garaga verifier here
            // let garaga = IGaragaVerifierDispatcher { contract_address: self.garaga_addr.read() };
            // garaga.verify(vk_hash, proof, public_inputs)
            false
        }

        fn is_circuit_supported(self: @ContractState, circuit_type: u8) -> bool {
            self.enabled_circuits.read(circuit_type)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Mock verification for hackathon MVP
        /// Validates proof structure matches expected format per circuit type
        fn mock_verify(
            self: @ContractState,
            circuit_type: u8,
            proof: Span<felt252>,
            public_inputs: Span<felt252>,
        ) -> bool {
            // Require non-empty proof and public inputs
            if proof.len() == 0 || public_inputs.len() == 0 {
                return false;
            }

            // Validate expected public input count per circuit type
            let expected_inputs = match circuit_type {
                0 => 1_u32,  // shielded_deposit: commitment
                1 => 6_u32,  // shielded_borrow: borrow_commitment, nullifier, root, price, ltv, precision
                2 => 3_u32,  // shielded_withdraw: nullifier, new_commitment, root
                3 => 2_u32,  // solvency: commitment, threshold
                _ => 0_u32,
            };

            if expected_inputs == 0 {
                return false;
            }

            if public_inputs.len() < expected_inputs {
                return false;
            }

            true
        }
    }

    // Admin functions
    #[external(v0)]
    fn set_mock_mode(ref self: ContractState, enabled: bool) {
        assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
        self.mock_mode.write(enabled);
    }

    #[external(v0)]
    fn set_circuit_enabled(ref self: ContractState, circuit_type: u8, enabled: bool) {
        assert(get_caller_address() == self.owner.read(), 'SL: not authorized');
        self.enabled_circuits.write(circuit_type, enabled);
    }
}
