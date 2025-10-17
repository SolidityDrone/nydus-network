pub mod indexed_merkle_tree;


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
