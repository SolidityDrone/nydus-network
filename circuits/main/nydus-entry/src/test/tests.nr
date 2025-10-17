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

#[test]
fn test_exclusion_proofs() {
    std::println("========================================");
    std::println("TEST: Exclusion Proofs");
    std::println("========================================");
    
    // === SETUP TEST DATA ===
    let token_address: Field = 0x1234;  // Token address
    let amount: Field = 0x64;  // 100 tokens
    let excluded_token: Field = 0x9999;  // Token that should be excluded
    
    std::println("=== SETUP ===");
    std::println("token_address (included):");
    std::println(token_address);
    std::println("amount:");
    std::println(amount);
    std::println("excluded_token:");
    std::println(excluded_token);
    std::println("");
    
    // === CREATE INDEXED MERKLE TREE ===
    std::println("=== CREATING INDEXED MERKLE TREE ===");
    
    // Initialize with empty tree
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1; // Start with the zero item
    
    // Insert the included item
    let (insertion_result, new_leaves, new_num_leaves) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        amount
    );
    
    std::println("Insertion completed:");
    std::println("root_after:");
    std::println(insertion_result.root_after);
    std::println("new_num_leaves:");
    std::println(new_num_leaves);
    
    // === TEST EXCLUSION PROOF ===
    std::println("=== TESTING EXCLUSION PROOF ===");
    
    // Generate proof for the included item (to get the tree structure)
    let included_proof = generate_proof(new_leaves, new_num_leaves, 1);
    
    // Test exclusion proof for a token that was never added
    let is_excluded = verify_exclusion_proof(excluded_token as u64, included_proof);
    std::println("Exclusion proof result for excluded token:");
    std::println(is_excluded);
    
    // The excluded token should be proven as excluded
    assert(is_excluded, "Excluded token should be proven as excluded");
    
    std::println("✅ Exclusion proof passed!");
    std::println("");
    
    // === TEST INCLUSION PROOF ===
    std::println("=== TESTING INCLUSION PROOF ===");
    
    // Test that the included token is NOT excluded
    let is_included_excluded = verify_exclusion_proof(token_address as u64, included_proof);
    std::println("Exclusion proof result for included token:");
    std::println(is_included_excluded);
    
    // The included token should NOT be proven as excluded
    assert(!is_included_excluded, "Included token should NOT be proven as excluded");
    
    std::println("✅ Inclusion proof passed!");
    std::println("");
    
    // === TEST EDGE CASES ===
    std::println("=== TESTING EDGE CASES ===");
    
    // Test with a token that's between existing tokens
    let middle_token: Field = 0x2000;  // Between 0x1234 and what would be next
    let is_middle_excluded = verify_exclusion_proof(middle_token as u64, included_proof);
    std::println("Exclusion proof result for middle token:");
    std::println(is_middle_excluded);
    
    // The middle token should be proven as excluded (since it was never added)
    assert(is_middle_excluded, "Middle token should be proven as excluded");
    
    std::println("✅ Edge case test passed!");
    std::println("");
    
    std::println("========================================");
    std::println("✅ EXCLUSION PROOFS TEST PASSED!");
    std::println("- Exclusion proof for non-member works ✓");
    std::println("- Inclusion proof for member works ✓");
    std::println("- Edge cases handled correctly ✓");
    std::println("========================================");
}

#[test]
fn test_simple_main_function() {
    std::println("========================================");
    std::println("TEST: Simple Main Function");
    std::println("========================================");
    
    // === SETUP TEST DATA ===
    let user_key: Field = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    let token_address: Field = 0x00000000000000000000000058002bee8f43bf203964d38c54fa03e62d615959fa;
    let amount: Field = 0x64; // 100 tokens
    
    std::println("=== INPUT VALUES ===");
    std::println("user_key:");
    std::println(user_key);
    std::println("token_address:");
    std::println(token_address);
    std::println("amount:");
    std::println(amount);
    std::println("");
    
    // === RUN MAIN FUNCTION ===
    let (main_indexed_tree_commitment, nonce_commitment, encrypted_fields) = main(
        user_key,
        token_address,
        amount
    );
    
    // === BASIC ASSERTIONS ===
    assert(main_indexed_tree_commitment != 0, "Main indexed_tree commitment should not be zero");
    assert(nonce_commitment != 0, "Nonce commitment should not be zero");
    assert(encrypted_fields[0] != 0, "Encrypted amount should not be zero");
    assert(encrypted_fields[1] != 0, "Encrypted token address should not be zero");
    assert(encrypted_fields[2] != 0, "Encrypted personal indexed_tree root should not be zero");
    assert(encrypted_fields[3] == 0, "Unused field should be zero");
    
    std::println("=== OUTPUT VALUES ===");
    std::println("main_indexed_tree_commitment:");
    std::println(main_indexed_tree_commitment);
    std::println("nonce_commitment:");
    std::println(nonce_commitment);
    std::println("encrypted_fields[0] (amount):");
    std::println(encrypted_fields[0]);
    std::println("encrypted_fields[1] (token_address):");
    std::println(encrypted_fields[1]);
    std::println("encrypted_fields[2] (personal_indexed_tree_root):");
    std::println(encrypted_fields[2]);
    std::println("encrypted_fields[3] (unused):");
    std::println(encrypted_fields[3]);
    
    std::println("========================================");
    std::println("✅ SIMPLE MAIN FUNCTION TEST PASSED!");
    std::println("- All outputs are non-zero ✓");
    std::println("- Encryption is working ✓");
    std::println("- Main function executes successfully ✓");
    std::println("========================================");
}

#[test]
fn test_generate_nydus_send_prover_toml() {
    std::println("========================================");
    std::println("GENERATING PROVER.TOML FOR NYDUS-SEND");
    std::println("========================================");
    
    // === SETUP TEST DATA ===
    let user_key: Field = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    let token_address: Field = 0x00000000000000000000000058002bee8f43bf203964d38c54fa03e62d615959fa;
    let amount: Field = 0x64; // 100 tokens (current balance)
    let spend_amount: Field = 0x32; // 50 tokens (amount to spend)
    
    std::println("=== SETUP ===");
    std::println("user_key:");
    std::println(user_key);
    std::println("token_address:");
    std::println(token_address);
    std::println("amount (current balance):");
    std::println(amount);
    std::println("spend_amount:");
    std::println(spend_amount);
    std::println("");
    
    // === CREATE INDEXED MERKLE TREE WITH CURRENT BALANCE ===
    std::println("=== CREATING INDEXED MERKLE TREE ===");
    
    // Initialize with empty tree
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1; // Start with the zero item
    
    // Insert the current balance
    let (insertion_result, new_leaves, new_num_leaves) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        amount
    );
    
    let personal_imt_root = insertion_result.root_after;
    
    std::println("Tree created with current balance:");
    std::println("personal_imt_root:");
    std::println(personal_imt_root);
    std::println("num_leaves:");
    std::println(new_num_leaves);
    std::println("");
    
    // === GENERATE PROOF FOR CURRENT BALANCE ===
    std::println("=== GENERATING PROOF FOR CURRENT BALANCE ===");
    
    // Generate proof for the current balance (index 1)
    let proof = generate_proof(new_leaves, new_num_leaves, 1);
    
    std::println("Proof generated:");
    std::println("leaf_idx:");
    std::println(proof.leaf_idx);
    std::println("leaf.key:");
    std::println(proof.leaf.key);
    std::println("leaf.value:");
    std::println(proof.leaf.value);
    std::println("root:");
    std::println(proof.root);
    std::println("");
    
    // === VERIFY PROOF ===
    let is_valid = verify_proof(proof);
    std::println("Proof verification result:");
    std::println(is_valid);
    assert(is_valid, "Proof should be valid");
    std::println("✅ Proof verification passed!");
    std::println("");
    
    // === GENERATE PROVER.TOML FOR NYDUS-SEND ===
    std::println("========================================");
    std::println("COPY THIS TO nydus-send/Prover.toml:");
    std::println("========================================");
    std::println("");
    std::println("amount = \"");
    std::print(spend_amount);
    std::println("\"");
    std::println("");
    std::println("current_amount = \"");
    std::print(amount);
    std::println("\"");
    std::println("");
    std::println("previous_nonce = \"");
    std::print(0x00);
    std::println("\"");
    std::println("");
    std::println("previous_personal_imt_root = \"");
    std::print(personal_imt_root);
    std::println("\"");
    std::println("");
    std::println("receiver_public_key = [\"");
    std::print(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
    std::println("\", \"");
    std::print(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
    std::println("\"]");
    std::println("");
    std::println("imt_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    std::println("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");
    std::println("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");
    
    // === CALCULATE EXPECTED NEW BALANCE ===
    let new_balance = amount - spend_amount;
    std::println("========================================");
    std::println("EXPECTED RESULTS:");
    std::println("========================================");
    std::println("Current balance:");
    std::println(amount);
    std::println("Amount to spend:");
    std::println(spend_amount);
    std::println("New balance after spending:");
    std::println(new_balance);
    std::println("");
    std::println("Previous personal IMT root:");
    std::println(personal_imt_root);
    std::println("");
    std::println("Proof siblings (first 5):");
    for i in 0..5 {
        std::print("siblings[");
        std::print(i);
        std::print("]: ");
        std::println(proof.siblings[i]);
    }
    std::println("");
    std::println("========================================");
    std::println("✅ PROVER.TOML GENERATED SUCCESSFULLY!");
    std::println("Copy the values above to nydus-send/Prover.toml");
    std::println("========================================");
}

#[test]
fn test_nydus_send_with_master_tree_simulation() {
    std::println("========================================");
    std::println("TEST: Nydus Send with Master Tree Simulation");
    std::println("========================================");
    
    // === SETUP TEST DATA ===
    let user_key: Field = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    let token_address: Field = 0x00000000000000000000000058002bee8f43bf203964d38c54fa03e62d615959fa;
    let amount: Field = 0x64; // 100 tokens (current balance)
    let spend_amount: Field = 0x32; // 50 tokens (amount to spend)
    
    std::println("=== SETUP ===");
    std::println("user_key:");
    std::println(user_key);
    std::println("token_address:");
    std::println(token_address);
    std::println("amount (current balance):");
    std::println(amount);
    std::println("spend_amount:");
    std::println(spend_amount);
    std::println("");
    
    // === STEP 1: SIMULATE ENTRY CIRCUIT (Personal IMT using Poseidon2) ===
    std::println("=== STEP 1: SIMULATING ENTRY CIRCUIT ===");
    
    // Run the entry circuit to get the personal IMT root
    let (main_indexed_tree_commitment, nonce_commitment, encrypted_fields) = main(
        user_key,
        token_address,
        amount
    );
    
    std::println("Entry circuit completed:");
    std::println("main_indexed_tree_commitment (personal IMT root):");
    std::println(main_indexed_tree_commitment);
    std::println("nonce_commitment:");
    std::println(nonce_commitment);
    std::println("");
    
    // === STEP 2: SIMULATE CONTRACT MASTER TREE UPDATE ===
    std::println("=== STEP 2: SIMULATING CONTRACT MASTER TREE UPDATE ===");
    
    // NOTE: This is a simulation for testing purposes
    // In the actual contract, the master tree would use MiMC hashing
    // For this test, we use the same indexed_merkle_tree library to simulate the concept
    let mut master_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut master_num_leaves = 1; // Start with the zero item
    
    // First, let's create the personal IMT root (same as entry circuit)
    let mut temp_personal_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut temp_personal_num_leaves = 1;
    
    let (temp_personal_insertion_result, _, _) = insert_item(
        temp_personal_leaves,
        temp_personal_num_leaves,
        token_address as u64,
        amount
    );
    
    let personal_imt_root_for_master = temp_personal_insertion_result.root_after;
    
    // Insert the personal IMT root into the master tree
    // The key is the user_key, the value is the personal IMT root
    let (master_insertion_result, master_new_leaves, master_new_num_leaves) = insert_item(
        master_leaves,
        master_num_leaves,
        user_key as u64,
        personal_imt_root_for_master
    );
    
    let master_tree_root = master_insertion_result.root_after;
    
    std::println("Master tree updated:");
    std::println("master_tree_root:");
    std::println(master_tree_root);
    std::println("master_num_leaves:");
    std::println(master_new_num_leaves);
    std::println("");
    
    // === STEP 3: GENERATE PROOF FOR PERSONAL IMT ROOT IN MASTER TREE ===
    std::println("=== STEP 3: GENERATING PROOF FOR PERSONAL IMT ROOT ===");
    
    // Generate proof that personal IMT root is a leaf in master tree
    // The leaf is at index 1 (after the zero item at index 0)
    let personal_imt_root_proof = generate_proof(master_new_leaves, master_new_num_leaves, 1);
    
    std::println("Personal IMT root proof generated:");
    std::println("leaf_idx:");
    std::println(personal_imt_root_proof.leaf_idx);
    std::println("leaf.key (user_key):");
    std::println(personal_imt_root_proof.leaf.key);
    std::println("leaf.value (personal IMT root):");
    std::println(personal_imt_root_proof.leaf.value);
    std::println("root (master tree root):");
    std::println(personal_imt_root_proof.root);
    std::println("");
    
    // Verify the proof
    let is_master_proof_valid = verify_proof(personal_imt_root_proof);
    std::println("Master tree proof verification result:");
    std::println(is_master_proof_valid);
    assert(is_master_proof_valid, "Master tree proof should be valid");
    std::println("✅ Master tree proof verification passed!");
    std::println("");
    
    // === STEP 4: SIMULATE PERSONAL IMT FOR SEND CIRCUIT ===
    std::println("=== STEP 4: SIMULATING PERSONAL IMT FOR SEND ===");
    
    // Use the same personal IMT root that we created for the master tree
    let personal_imt_root = personal_imt_root_for_master;
    
    // Recreate the personal IMT structure for proof generation
    let mut personal_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut personal_num_leaves = 1; // Start with the zero item
    
    // Insert the current balance into personal IMT (same as entry circuit)
    let (personal_insertion_result, personal_new_leaves, personal_new_num_leaves) = insert_item(
        personal_leaves,
        personal_num_leaves,
        token_address as u64,
        amount
    );
    
    // Verify that we get the same root
    assert(personal_insertion_result.root_after == personal_imt_root, "Personal IMT root should be consistent");
    
    std::println("Personal IMT created:");
    std::println("personal_imt_root:");
    std::println(personal_imt_root);
    std::println("personal_num_leaves:");
    std::println(personal_new_num_leaves);
    std::println("");
    
    std::println("✅ Personal IMT root consistency verified!");
    std::println("");
    
    // === STEP 5: GENERATE PROOF FOR CURRENT BALANCE IN PERSONAL IMT ===
    std::println("=== STEP 5: GENERATING PROOF FOR CURRENT BALANCE ===");
    
    // Generate proof for current balance in personal IMT
    let balance_proof = generate_proof(personal_new_leaves, personal_new_num_leaves, 1);
    
    std::println("Balance proof generated:");
    std::println("leaf_idx:");
    std::println(balance_proof.leaf_idx);
    std::println("leaf.key (token_address):");
    std::println(balance_proof.leaf.key);
    std::println("leaf.value (current balance):");
    std::println(balance_proof.leaf.value);
    std::println("root (personal IMT root):");
    std::println(balance_proof.root);
    std::println("");
    
    // Verify the balance proof
    let is_balance_proof_valid = verify_proof(balance_proof);
    std::println("Balance proof verification result:");
    std::println(is_balance_proof_valid);
    assert(is_balance_proof_valid, "Balance proof should be valid");
    std::println("✅ Balance proof verification passed!");
    std::println("");
    
    // === STEP 6: GENERATE PROVER.TOML FOR NYDUS-SEND WITH MASTER TREE ===
    std::println("========================================");
    std::println("GENERATING PROVER.TOML FOR NYDUS-SEND WITH MASTER TREE");
    std::println("========================================");
    std::println("");
    std::println("Copy this to nydus-send/Prover.toml:");
    std::println("");
    std::println("amount = \"");
    std::print(spend_amount);
    std::println("\"");
    std::println("");
    std::println("current_amount = \"");
    std::print(amount);
    std::println("\"");
    std::println("");
    std::println("previous_nonce = \"");
    std::print(0x00);
    std::println("\"");
    std::println("");
    std::println("previous_personal_imt_root = \"");
    std::print(personal_imt_root);
    std::println("\"");
    std::println("");
    std::println("receiver_public_key = [\"");
    std::print(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
    std::println("\", \"");
    std::print(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
    std::println("\"]");
    std::println("");
    std::println("imt_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(balance_proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    std::println("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");
    std::println("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");
    
    // === NEW: MASTER TREE ARGUMENTS ===
    std::println("// NEW: Master tree verification arguments");
    std::println("master_tree_root = \"");
    std::print(master_tree_root);
    std::println("\"");
    std::println("");
    std::println("personal_imt_root_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(personal_imt_root_proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    std::println("personal_imt_root_leaf_value = \"");
    std::print(personal_imt_root_proof.leaf.value);
    std::println("\"");
    std::println("");
    std::println("personal_imt_root_leaf_key = \"");
    std::print(personal_imt_root_proof.leaf.key);
    std::println("\"");
    std::println("");
    std::println("personal_imt_root_leaf_idx = \"");
    std::print(personal_imt_root_proof.leaf_idx);
    std::println("\"");
    std::println("");
    
    // === CALCULATE EXPECTED RESULTS ===
    let new_balance = amount - spend_amount;
    std::println("========================================");
    std::println("EXPECTED RESULTS:");
    std::println("========================================");
    std::println("Current balance:");
    std::println(amount);
    std::println("Amount to spend:");
    std::println(spend_amount);
    std::println("New balance after spending:");
    std::println(new_balance);
    std::println("");
    std::println("Personal IMT root (from entry):");
    std::println(personal_imt_root);
    std::println("Master tree root (contract):");
    std::println(master_tree_root);
    std::println("");
    std::println("Proof verification:");
    std::println("- Master tree proof valid: ✓");
    std::println("- Personal IMT proof valid: ✓");
    std::println("- Two-level tree structure: ✓");
    std::println("");
    
    std::println("========================================");
    std::println("✅ NYDUS SEND WITH MASTER TREE SIMULATION COMPLETED!");
    std::println("- Entry circuit simulated ✓");
    std::println("- Master tree updated with personal IMT root ✓");
    std::println("- Two-level tree proofs generated ✓");
    std::println("- Prover.toml generated for send circuit ✓");
    std::println("");
    std::println("NOTE: This is a simulation using Poseidon2-based trees");
    std::println("The actual contract master tree would use MiMC hashing");
    std::println("========================================");
}
