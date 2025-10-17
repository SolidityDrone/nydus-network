pub mod indexed_merkle_tree;
pub mod indexed_merkle_tree_mimc;

// Poseidon2 variant (default)
pub use indexed_merkle_tree::{
    Leaf,
    Proof,
    InsertionResult,
    generate_proof,
    verify_proof,
    verify_exclusion_proof,
    verify_insertion_proof,
    insert_item,
    empty_root
};

// MiMC variant
pub use indexed_merkle_tree_mimc::{
    Leaf as LeafMimc,
    Proof as ProofMimc,
    InsertionResult as InsertionResultMimc,
    generate_proof as generate_proof_mimc,
    verify_proof as verify_proof_mimc,
    verify_exclusion_proof as verify_exclusion_proof_mimc,
    verify_insertion_proof as verify_insertion_proof_mimc,
    insert_item as insert_item_mimc,
    empty_root as empty_root_mimc
};