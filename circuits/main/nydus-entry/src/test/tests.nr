use crate::main;
use dep::poseidon::poseidon2::Poseidon2;
use dep::poseidon_ctr_encryption::{poseidon_ctr_decrypt};
use dep::indexed_merkle_tree::{
    Leaf,
    insert_item,
    empty_root,
    generate_proof,
    verify_proof,
    verify_exclusion_proof
};

// For master tree simulation, we'll use the same indexed_merkle_tree library
// This simulates the concept of a two-level tree structure

#[test]
fn test_main_function() {
    // === INPUT VALUES FROM PROVER.TOML ===
    
    // Token address and amount
    let token_address: Field = 0x00000000000000000000000058002bee8f43bf203964d38c54fa03e62d615959fa;
    let amount: Field = 0x64;
    
    // User key (hash of user's fixed signature)
    let user_key: Field = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    
    // === RUN MAIN FUNCTION ===
    let (main_indexed_tree_commitment, nonce_commitment, encrypted_fields) = main(
        user_key,
        token_address,
        amount
    );
        
    assert(main_indexed_tree_commitment != 0);
    assert(nonce_commitment != 0);
    assert(encrypted_fields[0] != 0); // encrypted amount
    assert(encrypted_fields[1] != 0); // encrypted token_address
    assert(encrypted_fields[2] != 0); // encrypted personal_indexed_tree_root
    assert(encrypted_fields[3] == 0); // unused field (should be 0)
    
    // === TEST DECRYPTION ===
    // Recreate the same view key used for encryption
    let user_key_hash = Poseidon2::hash([user_key], 1);
    let view_string = 0x76696577696e675f6b6579 as Field;
    let view_key = Poseidon2::hash([view_string, user_key_hash], 2);
    
    // Decrypt the encrypted fields using the same counters
    let decrypted_amount = poseidon_ctr_decrypt(encrypted_fields[0], view_key, 0);
    let decrypted_token_address = poseidon_ctr_decrypt(encrypted_fields[1], view_key, 1);
    let decrypted_personal_indexed_tree_root = poseidon_ctr_decrypt(encrypted_fields[2], view_key, 2);
    
    // Verify that decryption works correctly
    assert(decrypted_amount == amount, "Decrypted amount should match original amount");
    assert(decrypted_token_address == token_address, "Decrypted token_address should match original token_address");
    
    std::println("=== MAIN FUNCTION OUTPUTS ===");
    std::println("main_indexed_tree_commitment:");
    std::println(main_indexed_tree_commitment);
    std::println("nonce_commitment:");
    std::println(nonce_commitment);
    
    std::println("=== DECRYPTION TEST ===");
    std::println("Original amount:");
    std::println(amount);
    std::println("Decrypted amount:");
    std::println(decrypted_amount);
    std::println("Original token_address:");
    std::println(token_address);
    std::println("Decrypted token_address:");
    std::println(decrypted_token_address);
    
    std::println("=== TEST PASSED ===");
    std::println("All outputs are non-zero and decryption works correctly!");
}

#[test]
fn test_basic_indexed_merkle_tree() {
    std::println("========================================");
    std::println("TEST: Basic Indexed Merkle Tree");
    std::println("========================================");
    
    // === BASIC SETUP ===
    let token_address: Field = 0x1234;  // Token address
    let amount: Field = 0x64;  // 100 tokens
    
    std::println("=== BASIC SETUP ===");
    std::println("token_address:");
    std::println(token_address);
    std::println("amount:");
    std::println(amount);
    std::println("");
    
    // === TEST EMPTY ROOT ===
    let empty_root_value = empty_root();
    std::println("=== EMPTY ROOT TEST ===");
    std::println("empty_root:");
    std::println(empty_root_value);
    assert(empty_root_value != 0, "Empty root should not be zero");
    std::println("✅ Empty root test passed!");
    std::println("");
    
    // === TEST BASIC INSERTION ===
    std::println("=== BASIC INSERTION TEST ===");
    std::println("Testing basic insertion into indexed merkle tree...");
    
    // Initialize with empty tree
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1; // Start with the zero item
    
    // Try to insert one item
    let (insertion_result, new_leaves, new_num_leaves) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        amount
    );
    
    std::println("Insertion completed:");
    std::println("root_before:");
    std::println(insertion_result.root_before);
    std::println("root_after:");
    std::println(insertion_result.root_after);
    std::println("new_num_leaves:");
    std::println(new_num_leaves);
    
    // Basic assertions
    assert(insertion_result.root_after != 0, "Root after insertion should not be zero");
    assert(new_num_leaves == 2, "Should have 2 leaves after insertion");
    
    std::println("✅ Basic insertion test passed!");
    std::println("");
    
    std::println("========================================");
    std::println("✅ BASIC INDEXED MERKLE TREE TEST PASSED!");
    std::println("- Empty root generation works ✓");
    std::println("- Basic insertion works ✓");
    std::println("- Root computation works ✓");
    std::println("========================================");
}

#[test]
fn test_proof_generation_and_verification() {
    std::println("========================================");
    std::println("TEST: Proof Generation and Verification");
    std::println("========================================");
    
    // === SETUP TEST DATA ===
    let token_address: Field = 0x1234;  // Token address
    let amount: Field = 0x64;  // 100 tokens
    
    std::println("=== SETUP ===");
    std::println("token_address:");
    std::println(token_address);
    std::println("amount:");
    std::println(amount);
    std::println("");
    
    // === CREATE INDEXED MERKLE TREE ===
    std::println("=== CREATING INDEXED MERKLE TREE ===");
    
    // Initialize with empty tree
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1; // Start with the zero item
    
    // Insert first item
    let (insertion_result1, new_leaves1, new_num_leaves1) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        amount
    );
    
    std::println("First insertion completed:");
    std::println("root_before:");
    std::println(insertion_result1.root_before);
    std::println("root_after:");
    std::println(insertion_result1.root_after);
    std::println("new_num_leaves:");
    std::println(new_num_leaves1);
    
    // === TEST PROOF GENERATION ===
    std::println("=== TESTING PROOF GENERATION ===");
    
    // Generate proof for the inserted item (index 1)
    let proof = generate_proof(new_leaves1, new_num_leaves1, 1);
    
    std::println("Proof generated:");
    std::println("leaf_idx:");
    std::println(proof.leaf_idx);
    std::println("leaf.key:");
    std::println(proof.leaf.key);
    std::println("leaf.value:");
    std::println(proof.leaf.value);
    std::println("root:");
    std::println(proof.root);
    std::println("siblings[0]:");
    std::println(proof.siblings[0]);
    std::println("siblings[1]:");
    std::println(proof.siblings[1]);
    
    // === TEST PROOF VERIFICATION ===
    std::println("=== TESTING PROOF VERIFICATION ===");
    
    // Verify the proof
    let is_valid = verify_proof(proof);
    std::println("Proof verification result:");
    std::println(is_valid);
    
    // Assert that the proof is valid
    assert(is_valid, "Generated proof should be valid");
    
    std::println("✅ Proof verification passed!");
    std::println("");
    
    // === TEST MULTIPLE INSERTIONS ===
    std::println("=== TESTING MULTIPLE INSERTIONS ===");
    
    let token2_address: Field = 0x5678;  // Different token
    let amount2: Field = 0x32;  // 50 tokens
    
    // Insert second item
    let (insertion_result2, new_leaves2, new_num_leaves2) = insert_item(
        new_leaves1,
        new_num_leaves1,
        token2_address as u64,
        amount2
    );
    
    std::println("Second insertion completed:");
    std::println("root_before:");
    std::println(insertion_result2.root_before);
    std::println("root_after:");
    std::println(insertion_result2.root_after);
    std::println("new_num_leaves:");
    std::println(new_num_leaves2);
    
    // Generate proof for the second item (index 2)
    let proof2 = generate_proof(new_leaves2, new_num_leaves2, 2);
    
    // Verify the second proof
    let is_valid2 = verify_proof(proof2);
    std::println("Second proof verification result:");
    std::println(is_valid2);
    
    // Assert that the second proof is also valid
    assert(is_valid2, "Second generated proof should be valid");
    
    std::println("✅ Second proof verification passed!");
    std::println("");
    
    // === TEST ROOT CONSISTENCY ===
    std::println("=== TESTING ROOT CONSISTENCY ===");
    
    // Verify that the proof root matches the insertion result root
    assert(proof.root == insertion_result1.root_after, "Proof root should match insertion result root");
    assert(proof2.root == insertion_result2.root_after, "Second proof root should match second insertion result root");
    
    std::println("✅ Root consistency verified!");
    std::println("");
    
    std::println("========================================");
    std::println("✅ PROOF GENERATION AND VERIFICATION TEST PASSED!");
    std::println("- Proof generation works ✓");
    std::println("- Proof verification works ✓");
    std::println("- Multiple insertions work ✓");
    std::println("- Root consistency maintained ✓");
    std::println("========================================");
}

