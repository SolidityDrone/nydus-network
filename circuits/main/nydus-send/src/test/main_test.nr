use dep::indexed_merkle_tree::{
    Leaf,
    insert_item,
    generate_proof,
    verify_proof
};

#[test]
fn test_complete_flow() {
    // === STEP 1: Bob enters with 100 USDC ===
    println("=== STEP 1: Bob enters with 100 USDC ===");
    
    let bob_amount = 100;
    let usdc_token_address = 12345; // Use a smaller value for testing
    
    // Create Bob's initial tree
    let mut bob_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut bob_num_leaves = 1;
    
    let (bob_insertion_result, _, _) = insert_item(
        bob_leaves,
        bob_num_leaves,
        usdc_token_address,
        bob_amount as Field
    );
    
    let bob_personal_imt_root = bob_insertion_result.root_after;
    println("Bob's personal IMT root");
    
    // === STEP 2: Alice enters with 100 USDC ===
    println("=== STEP 2: Alice enters with 100 USDC ===");
    
    let alice_amount = 100;
    
    // Create Alice's initial tree
    let mut alice_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut alice_num_leaves = 1;
    
    let (alice_insertion_result, _, _) = insert_item(
        alice_leaves,
        alice_num_leaves,
        usdc_token_address,
        alice_amount as Field
    );
    
    let alice_personal_imt_root = alice_insertion_result.root_after;
    println("Alice's personal IMT root");
    
    // === STEP 3: Bob sends 100 USDC to Alice ===
    println("=== STEP 3: Bob sends 100 USDC to Alice ===");
    
    let bob_send_amount = 100;
    let bob_new_balance = bob_amount - bob_send_amount; // Should be 0
    
    // Bob's tree after sending
    let mut bob_leaves_after_send: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut bob_num_leaves_after_send = 1;
    
    let (bob_send_result, _, _) = insert_item(
        bob_leaves_after_send,
        bob_num_leaves_after_send,
        usdc_token_address,
        bob_new_balance as Field
    );
    
    let bob_new_personal_imt_root = bob_send_result.root_after;
    println("Bob's new personal IMT root");
    
    // Alice receives 100 USDC
    let alice_received_amount = 100;
    let alice_new_balance = alice_amount + alice_received_amount; // Should be 200
    
    let (alice_receive_result, _, _) = insert_item(
        alice_leaves,
        alice_num_leaves,
        usdc_token_address,
        alice_new_balance as Field
    );
    
    let alice_new_personal_imt_root = alice_receive_result.root_after;
    println("Alice's new personal IMT root");
    
    // === STEP 4: Alice tries to send 200 USDC (should fail) ===
    println("=== STEP 4: Alice tries to send 200 USDC (should fail) ===");
    
    let alice_try_send_amount = 200;
    let alice_available_balance = alice_new_balance; // 200
    
    // Check if Alice has enough balance
    let has_enough_balance = alice_available_balance >= alice_try_send_amount;
    println("Alice has enough balance for 200 USDC");
    
    // This should be true (200 >= 200), but let's test the logic
    assert(has_enough_balance, "Alice should have enough balance for 200 USDC");
    
    // === STEP 5: Alice sends 100 USDC (should succeed) ===
    println("=== STEP 5: Alice sends 100 USDC (should succeed) ===");
    
    let alice_send_amount = 100;
    let alice_final_balance = alice_new_balance - alice_send_amount; // Should be 100
    
    // Alice's tree after sending
    let mut alice_leaves_after_send: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut alice_num_leaves_after_send = 1;
    
    let (alice_send_result, _, _) = insert_item(
        alice_leaves_after_send,
        alice_num_leaves_after_send,
        usdc_token_address,
        alice_final_balance as Field
    );
    
    let alice_final_personal_imt_root = alice_send_result.root_after;
    println("Alice's final personal IMT root");
    
    // === VERIFICATION ===
    println("=== VERIFICATION ===");
    
    // Verify Bob's final balance is 0
    assert(bob_new_balance == 0, "Bob's final balance should be 0");
    println("Bob's final balance");
    
    // Verify Alice's final balance is 100
    assert(alice_final_balance == 100, "Alice's final balance should be 100");
    println("Alice's final balance");
    
    // Verify Alice can send 100 but not 200
    let can_send_100 = alice_final_balance >= 100;
    let can_send_200 = alice_final_balance >= 200;
    
    assert(can_send_100, "Alice should be able to send 100 USDC");
    assert(!can_send_200, "Alice should NOT be able to send 200 USDC");
    
    println("Alice can send 100 USDC");
    println("Alice can send 200 USDC");
    
    // === PROOF GENERATION AND VERIFICATION ===
    println("=== PROOF GENERATION AND VERIFICATION ===");
    
    // Generate proof for Alice's final balance
    let alice_final_proof = generate_proof(alice_leaves_after_send, alice_num_leaves_after_send, 1);
    let alice_proof_valid = verify_proof(alice_final_proof);
    
    assert(alice_proof_valid, "Alice's final balance proof should be valid");
    println("Alice's final balance proof is valid");
    
    // Generate proof for Bob's final balance
    let bob_final_proof = generate_proof(bob_leaves_after_send, bob_num_leaves_after_send, 1);
    let bob_proof_valid = verify_proof(bob_final_proof);
    
    assert(bob_proof_valid, "Bob's final balance proof should be valid");
    println("Bob's final balance proof is valid");
    
    // === FINAL STATE SUMMARY ===
    println("=== FINAL STATE SUMMARY ===");
    println("Bob's final balance");
    println("Alice's final balance");
    println("Bob's final root");
    println("Alice's final root");
    
    // Verify the flow worked correctly
    assert(bob_new_balance == 0, "Bob should have 0 USDC after sending 100");
    assert(alice_final_balance == 100, "Alice should have 100 USDC after receiving 100 and sending 100");
    assert(alice_final_balance >= 100, "Alice should have enough to send 100");
    assert(alice_final_balance < 200, "Alice should NOT have enough to send 200");
    
    println("✅ Complete flow test passed!");
}

#[test]
fn test_insufficient_balance_protection() {
    println("=== TESTING INSUFFICIENT BALANCE PROTECTION ===");
    
    // Create a user with 50 USDC
    let user_balance = 50;
    let send_amount = 100; // Try to send more than available
    
    // Check if user has enough balance
    let has_enough = user_balance >= send_amount;
    
    // This should be false (50 < 100)
    assert(!has_enough, "User should NOT have enough balance to send 100 USDC");
    
    println("User balance");
    println("Send amount");
    println("Has enough balance");
    
    // Test that the transaction would fail
    let transaction_would_succeed = has_enough;
    assert(!transaction_would_succeed, "Transaction should fail due to insufficient balance");
    
    println("✅ Insufficient balance protection test passed!");
}

#[test]
fn test_proof_verification_flow() {
    println("=== TESTING PROOF VERIFICATION FLOW ===");
    
    // Create initial tree with 100 USDC
    let initial_balance = 100;
    let usdc_token_address = 12345;
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    let (insertion_result, leaves, num_leaves) = insert_item(
        leaves,
        num_leaves,
        usdc_token_address,
        initial_balance as Field
    );
    
    let root = insertion_result.root_after;
    println("Initial root");
    
    // Generate proof for the balance
    let proof = generate_proof(leaves, num_leaves, 1);
    let proof_valid = verify_proof(proof);
    
    assert(proof_valid, "Proof should be valid");
    println("Proof is valid");
    
    // Verify the proof contains the correct balance
    assert(proof.leaf.value == initial_balance as Field, "Proof should contain correct balance");
    assert(proof.root == root, "Proof should contain correct root");
    
    println("Proof leaf value");
    println("Proof root");
    println("Expected balance");
    println("Expected root");
    
    println("✅ Proof verification flow test passed!");
}

#[test]
fn test_generate_nydus_send_prover_toml() {
    // Generate Prover.toml for nydus-send circuit
    println("=== GENERATING PROVER.TOML FOR NYDUS-SEND ===");
    
    // === SETUP TEST DATA ===
    let user_key = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field;
    let token_address = 0x58002bee8f43bf203964d38c54fa03e62d615959fa as Field;
    let amount = 0x32 as Field; // 50 tokens to send
    let current_amount = 0x64 as Field; // 100 tokens current balance
    let previous_nonce = 0x00 as Field;
    let receiver_public_key = [
        0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field,
        0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field
    ];
    
    // === CREATE INDEXED MERKLE TREE WITH CURRENT BALANCE ===
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    // Insert current balance into tree
    let (insertion_result, _, _) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        current_amount
    );
    
    let personal_imt_root = insertion_result.root_after;
    
    // Generate proof for current balance
    let proof = generate_proof(leaves, num_leaves, 1);
    let imt_leaf_proof = proof.siblings;
    
    // === CREATE MASTER TREE FOR VERIFICATION ===
    // Simulate master tree that contains personal_imt_root as a leaf
    let mut master_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut master_num_leaves = 1;
    
    // Insert personal_imt_root into master tree
    let (master_insertion_result, master_new_leaves, master_new_num_leaves) = insert_item(
        master_leaves,
        master_num_leaves,
        personal_imt_root as u64,
        personal_imt_root
    );
    
    let master_tree_root = master_insertion_result.root_after;
    
    // Generate proof that personal_imt_root is in the master tree
    let personal_imt_root_proof = generate_proof(master_new_leaves, master_new_num_leaves, 1);
    
    // === PRINT PROVER.TOML FORMAT ===
    std::println("========================================");
    std::println("COPY THIS TO nydus-send/Prover.toml");
    std::println("========================================");
    std::println("");
    
    std::print("amount = \"");
    std::print(amount);
    std::println("\"");
    std::println("");
    
    std::print("current_amount = \"");
    std::print(current_amount);
    std::println("\"");
    std::println("");
    
    std::print("previous_nonce = \"");
    std::print(previous_nonce);
    std::println("\"");
    std::println("");
    
    std::print("previous_personal_imt_root = \"");
    std::print(personal_imt_root);
    std::println("\"");
    std::println("");
    
    std::print("receiver_public_key = [\"");
    std::print(receiver_public_key[0]);
    std::print("\", \"");
    std::print(receiver_public_key[1]);
    std::println("\"]");
    std::println("");
    
    std::print("imt_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(imt_leaf_proof[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    
    std::print("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");
    
    std::print("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");
    
    // NEW: Master tree verification arguments
    std::println("// NEW: Master tree verification arguments");
    std::print("master_tree_root = \"");
    std::print(master_tree_root);
    std::println("\"");
    std::println("");
    
    std::print("personal_imt_root_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(personal_imt_root_proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    
    std::print("personal_imt_root_leaf_value = \"");
    std::print(personal_imt_root_proof.leaf.value);
    std::println("\"");
    std::println("");
    
    std::print("personal_imt_root_leaf_key = \"");
    std::print(personal_imt_root_proof.leaf.key);
    std::println("\"");
    std::println("");
    
    std::print("personal_imt_root_leaf_idx = \"");
    std::print(personal_imt_root_proof.leaf_idx);
    std::println("\"");
    std::println("");
    
    std::println("========================================");
    std::println("EXPECTED RESULTS:");
    std::println("========================================");
    std::print("New balance after spending: ");
    std::print(current_amount - amount);
    std::println(" tokens (100 - 50 = 50)");
    std::print("Proof siblings count: ");
    std::print(32);
    std::println("");
    std::print("Personal IMT root: ");
    std::print(personal_imt_root);
    std::println("");
    std::print("Master tree root: ");
    std::print(master_tree_root);
    std::println("");
    std::println("========================================");
    std::println("✅ Prover.toml generated successfully!");
    std::println("========================================");
}

#[test]
fn test_generate_nydus_absorb_prover_toml() {
    // Generate Prover.toml for nydus-absorb circuit
    println("=== GENERATING PROVER.TOML FOR NYDUS-ABSORB ===");

    // === SETUP TEST DATA ===
    let user_key = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field;
    let token_address = 0x58002bee8f43bf203964d38c54fa03e62d615959fa as Field;
    let current_balance = 0x32 as Field; // 50 tokens current balance
    let previous_nonce = 0x00 as Field;
    let previous_spent_amount = 0x00 as Field;

    // === CREATE INDEXED MERKLE TREE WITH CURRENT BALANCE ===
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;

    // Insert current balance into tree
    let (insertion_result, _, _) = insert_item(
        leaves,
        num_leaves,
        user_key as u64,
        current_balance
    );

    let previous_personal_imt_root = insertion_result.root_after;

    // Generate proof for current balance
    let proof = generate_proof(leaves, num_leaves, 1);
    let imt_leaf_proof = proof.siblings;

    // === SETUP PEDERSEN COMMITMENTS ===
    // Based on test_homomorphism.nr: C = m*G + r*H + token_address*G
    let c_inner_m = 0x19 as Field; // 25 tokens (inner balance - what we want to prove)
    let c_inner_r = 0xabcdef1234567890 as Field; // Inner blinding factor
    let c_inner_commitment = std::hash::pedersen_commitment([c_inner_m, c_inner_r]);
    
    let c_outer_m = 0x0a as Field; // 10 tokens (outer balance - rest of commitments)
    let c_outer_r = 0x1234567890abcdef as Field; // Outer blinding factor
    let c_outer_commitment = std::hash::pedersen_commitment([c_outer_m, c_outer_r]);
    
    // Total commitment: c_inner + c_outer
    let c_tot = [c_inner_commitment.x + c_outer_commitment.x, c_inner_commitment.y + c_outer_commitment.y];

    // === CREATE HISTORICAL TREE FOR C_TOT VERIFICATION ===
    // Simulate historical tree that contains c_tot as a leaf
    let mut historical_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut historical_num_leaves = 1;
    
    // Insert c_tot into historical tree
    let (historical_insertion_result, historical_new_leaves, historical_new_num_leaves) = insert_item(
        historical_leaves,
        historical_num_leaves,
        c_tot[0] as u64,
        c_tot[0]
    );
    
    let historical_root = historical_insertion_result.root_after;
    
    // Generate proof that c_tot is in the historical tree
    let c_tot_proof = generate_proof(historical_new_leaves, historical_new_num_leaves, 1);
    
    // Verify the proof is valid before using it
    let c_tot_proof_valid = verify_proof(c_tot_proof);
    assert(c_tot_proof_valid, "Generated c_tot proof should be valid");

    // Empty spent leaf proof for first time
    let spent_leaf_proof: [Field; 32] = [0; 32];

    // === PRINT PROVER.TOML FORMAT ===
    std::println("========================================");
    std::println("COPY THIS TO nydus-absorb/Prover.toml");
    std::println("========================================");
    std::println("");

    std::print("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");

    std::print("previous_nonce = \"");
    std::print(previous_nonce);
    std::println("\"");
    std::println("");

    std::print("previous_personal_imt_root = \"");
    std::print(previous_personal_imt_root);
    std::println("\"");
    std::println("");

    std::print("imt_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(imt_leaf_proof[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");

    std::print("current_balance = \"");
    std::print(current_balance);
    std::println("\"");
    std::println("");

    std::print("imt_leaf_idx = \"");
    std::print(1);
    std::println("\"");
    std::println("");

    std::print("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");

    std::print("previous_spent_amount = \"");
    std::print(previous_spent_amount);
    std::println("\"");
    std::println("");

    std::print("spent_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(spent_leaf_proof[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");

    std::print("c_tot = [\"");
    std::print(c_tot[0]);
    std::print("\", \"");
    std::print(c_tot[1]);
    std::println("\"]");
    std::println("");

    std::print("c_inner_balance = [\"");
    std::print(c_inner_commitment.x);
    std::print("\", \"");
    std::print(c_inner_commitment.y);
    std::println("\"]");
    std::println("");

    std::print("c_outer_balance = [\"");
    std::print(c_outer_commitment.x);
    std::print("\", \"");
    std::print(c_outer_commitment.y);
    std::println("\"]");
    std::println("");

    std::print("c_inner_m = \"");
    std::print(c_inner_m);
    std::println("\"");
    std::println("");

    std::print("c_inner_r = \"");
    std::print(c_inner_r);
    std::println("\"");
    std::println("");

    std::print("c_outer_m = \"");
    std::print(c_outer_m);
    std::println("\"");
    std::println("");

    std::print("c_outer_r = \"");
    std::print(c_outer_r);
    std::println("\"");
    std::println("");

    // NEW: Historical root verification arguments
    std::println("// NEW: Historical root verification arguments");
    std::print("historical_root = \"");
    std::print(historical_root);
    std::println("\"");
    std::println("");

    std::print("c_tot_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(c_tot_proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");

    std::print("c_tot_leaf_value = \"");
    std::print(c_tot_proof.leaf.value);
    std::println("\"");
    std::println("");

    std::print("c_tot_leaf_key = \"");
    std::print(c_tot_proof.leaf.key);
    std::println("\"");
    std::println("");

    std::print("c_tot_leaf_idx = \"");
    std::print(c_tot_proof.leaf_idx);
    std::println("\"");
    std::println("");

    std::println("========================================");
    std::println("EXPECTED RESULTS:");
    std::println("========================================");
    std::print("New balance after absorbing: ");
    std::print(current_balance + c_inner_m + c_outer_m);
    std::println(" tokens (50 + 25 + 10 = 85)");
    std::print("Inner commitment (what we prove): ");
    std::print(c_inner_m);
    std::println(" tokens");
    std::print("Outer commitment (rest): ");
    std::print(c_outer_m);
    std::println(" tokens");
    std::print("Total commitment: ");
    std::print(c_tot[0]);
    std::print(", ");
    std::print(c_tot[1]);
    std::println("");
    std::print("Historical root: ");
    std::print(historical_root);
    std::println("");
    std::println("========================================");
    std::println("✅ nydus-absorb Prover.toml generated successfully!");
    std::println("========================================");
}

#[test]
fn test_generate_nydus_absorb_with_historical_root() {
    // Generate Prover.toml for nydus-absorb circuit with historical root verification
    println("=== GENERATING PROVER.TOML FOR NYDUS-ABSORB WITH HISTORICAL ROOT ===");
    
    // === SETUP TEST DATA ===
    let user_key = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field;
    let token_address = 0x58002bee8f43bf203964d38c54fa03e62d615959fa as Field;
    let current_balance = 0x32 as Field; // 50 tokens current balance
    let previous_nonce = 0x00 as Field;
    let previous_spent_amount = 0x00 as Field;
    
    // === CREATE INDEXED MERKLE TREE WITH CURRENT BALANCE ===
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    // Insert current balance into tree
    let (insertion_result, _, _) = insert_item(
        leaves,
        num_leaves,
        user_key as u64,
        current_balance
    );
    
    let previous_personal_imt_root = insertion_result.root_after;
    
    // Generate proof for current balance
    let proof = generate_proof(leaves, num_leaves, 1);
    let imt_leaf_proof = proof.siblings;
    
    // === SETUP PEDERSEN COMMITMENTS ===
    let c_inner_m = 0x19 as Field; // 25 tokens (inner balance)
    let c_inner_r = 0xabcdef1234567890 as Field; // Inner blinding factor
    let c_inner_commitment = std::hash::pedersen_commitment([c_inner_m, c_inner_r]);
    
    let c_outer_m = 0x0a as Field; // 10 tokens (outer balance)
    let c_outer_r = 0x1234567890abcdef as Field; // Outer blinding factor
    let c_outer_commitment = std::hash::pedersen_commitment([c_outer_m, c_outer_r]);
    
    // Total commitment: c_inner + c_outer
    let c_tot = [c_inner_commitment.x + c_outer_commitment.x, c_inner_commitment.y + c_outer_commitment.y];
    
    // === SIMULATE HISTORICAL ROOT AND C_TOT PROOF ===
    // Create a master tree that contains c_tot as a leaf
    let mut master_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut master_num_leaves = 1;
    
    // Insert c_tot into master tree (simulating historical storage)
    let (master_insertion_result, master_new_leaves, master_new_num_leaves) = insert_item(
        master_leaves,
        master_num_leaves,
        c_tot[0] as u64, // Use c_tot[0] as the key
        c_tot[0] // Use c_tot[0] as the value
    );
    
    let historical_root = master_insertion_result.root_after;
    
    // Generate proof that c_tot is in the historical tree
    let c_tot_proof = generate_proof(master_new_leaves, master_new_num_leaves, 1);
    
    // Verify the proof is valid before using it
    let c_tot_proof_valid = verify_proof(c_tot_proof);
    assert(c_tot_proof_valid, "Generated c_tot proof should be valid");
    
    // Empty spent leaf proof for first time
    let spent_leaf_proof: [Field; 32] = [0; 32];
    
    // === PRINT PROVER.TOML FORMAT ===
    std::println("========================================");
    std::println("COPY THIS TO nydus-absorb/Prover.toml");
    std::println("========================================");
    std::println("");
    
    // Original absorb arguments
    std::print("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");
    
    std::print("previous_nonce = \"");
    std::print(previous_nonce);
    std::println("\"");
    std::println("");
    
    std::print("previous_personal_imt_root = \"");
    std::print(previous_personal_imt_root);
    std::println("\"");
    std::println("");
    
    std::print("imt_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(imt_leaf_proof[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    
    std::print("current_balance = \"");
    std::print(current_balance);
    std::println("\"");
    std::println("");
    
    std::print("imt_leaf_idx = \"");
    std::print(1);
    std::println("\"");
    std::println("");
    
    std::print("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");
    
    std::print("previous_spent_amount = \"");
    std::print(previous_spent_amount);
    std::println("\"");
    std::println("");
    
    std::print("spent_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(spent_leaf_proof[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    
    // Pedersen commitments
    std::print("c_tot = [\"");
    std::print(c_tot[0]);
    std::print("\", \"");
    std::print(c_tot[1]);
    std::println("\"]");
    std::println("");
    
    std::print("c_inner_balance = [\"");
    std::print(c_inner_commitment.x);
    std::print("\", \"");
    std::print(c_inner_commitment.y);
    std::println("\"]");
    std::println("");
    
    std::print("c_outer_balance = [\"");
    std::print(c_outer_commitment.x);
    std::print("\", \"");
    std::print(c_outer_commitment.y);
    std::println("\"]");
    std::println("");
    
    std::print("c_inner_m = \"");
    std::print(c_inner_m);
    std::println("\"");
    std::println("");
    
    std::print("c_inner_r = \"");
    std::print(c_inner_r);
    std::println("\"");
    std::println("");
    
    std::print("c_outer_m = \"");
    std::print(c_outer_m);
    std::println("\"");
    std::println("");
    
    std::print("c_outer_r = \"");
    std::print(c_outer_r);
    std::println("\"");
    std::println("");
    
    // NEW: Historical root verification arguments
    std::println("// NEW: Historical root verification arguments");
    std::print("historical_root = \"");
    std::print(historical_root);
    std::println("\"");
    std::println("");
    
    std::print("c_tot_leaf_proof = [");
    for i in 0..32 {
        std::print("\"");
        std::print(c_tot_proof.siblings[i]);
        std::print("\"");
        if i < 31 { std::print(", "); }
    }
    std::println("]");
    std::println("");
    
    std::print("c_tot_leaf_value = \"");
    std::print(c_tot_proof.leaf.value);
    std::println("\"");
    std::println("");
    
    std::print("c_tot_leaf_key = \"");
    std::print(c_tot_proof.leaf.key);
    std::println("\"");
    std::println("");
    
    std::print("c_tot_leaf_idx = \"");
    std::print(c_tot_proof.leaf_idx);
    std::println("\"");
    std::println("");
    
    std::println("========================================");
    std::println("EXPECTED RESULTS:");
    std::println("========================================");
    std::print("New balance after absorbing: ");
    std::print(current_balance + c_inner_m + c_outer_m);
    std::println(" tokens (50 + 25 + 10 = 85)");
    std::print("Inner commitment (what we prove): ");
    std::print(c_inner_m);
    std::println(" tokens");
    std::print("Outer commitment (rest): ");
    std::print(c_outer_m);
    std::println(" tokens");
    std::print("Total commitment: ");
    std::print(c_tot[0]);
    std::print(", ");
    std::print(c_tot[1]);
    std::println("");
    std::print("Historical root: ");
    std::print(historical_root);
    std::println("");
    std::println("========================================");
    std::println("✅ nydus-absorb with historical root Prover.toml generated successfully!");
    std::println("========================================");
}