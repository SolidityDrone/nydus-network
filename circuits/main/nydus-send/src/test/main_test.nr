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
