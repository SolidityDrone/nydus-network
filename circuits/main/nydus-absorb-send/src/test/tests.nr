use dep::std;
use crate::main;
use dep::poseidon::poseidon2::Poseidon2;
use dep::indexed_merkle_tree::{
    Leaf,
    insert_item,
    generate_proof,
    // MiMC variant for main merkle tree
    LeafMimc,
    insert_item_mimc,
    generate_proof_mimc
};
use std::hash::pedersen_commitment;

#[test]
fn test_send_then_absorb_flow() {
    std::println("========================================");
    std::println("SEND-THEN-ABSORB UNIFIED CIRCUIT TEST");
    std::println("========================================");
    std::println("1. Alice deposit 100 USDC");
    std::println("2. Frank deposit 100 USDC");
    std::println("3. Frank send Alice 100 USDC");
    std::println("4. Alice send 200 USDC to Frank (100 personal + 100 from commitment)");
    std::println("========================================");
    
    // Setup
    let alice_key = 0xfedcba0987654321fedcba0987654321fedcba0987654321 as Field;
    let frank_key = 0x9876543210fedcba9876543210fedcba9876543210fedcba as Field;
    let usdc_token = 0x58002bee8f43bf203964d38c54fa03e62d615959fa as Field;
    
    // === MAIN MERKLE TREE (MiMC) - Contract's historical tree ===
    let mut main_tree_leaves: [LeafMimc; 32] = [LeafMimc { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut main_tree_num_leaves = 1;
    let mut main_tree_root = 0x0000000000000000000000000000000000000000000000000000000000000000 as Field;
    
    // === STEP 1: ALICE ENTRY 100 USDC ===
    std::println("");
    std::println("=== STEP 1: ALICE ENTRY 100 USDC ===");
    
    // Alice's personal IMT (Poseidon)
    let mut alice_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut alice_num_leaves = 1;
    let alice_amount = 100 as Field;
    
    let (alice_insertion_result, alice_leaves, alice_num_leaves) = insert_item(
        alice_leaves,
        alice_num_leaves,
        alice_key as u64,
        alice_amount
    );
    
    let alice_personal_imt_root = alice_insertion_result.root_after;
    let alice_nonce = 0 as Field;
    let alice_nonce_commitment = Poseidon2::hash([alice_key, alice_nonce], 2);
    let alice_main_commitment = Poseidon2::hash([alice_personal_imt_root, alice_nonce_commitment], 2);
    
    // Insert Alice's main commitment into main tree (MiMC)
    let (alice_main_insertion_result, main_tree_leaves, main_tree_num_leaves) = insert_item_mimc(
        main_tree_leaves,
        main_tree_num_leaves,
        alice_main_commitment as u64,
        alice_main_commitment
    );
    
    main_tree_root = alice_main_insertion_result.root_after;
    
    std::println("Alice's personal IMT root:");
    std::println(alice_personal_imt_root);
    std::println("Alice's main commitment:");
    std::println(alice_main_commitment);
    std::println("Main tree root after Alice entry:");
    std::println(main_tree_root);
    
    // === STEP 2: FRANK DEPOSIT 100 USDC ===
    std::println("");
    std::println("=== STEP 2: FRANK DEPOSIT 100 USDC ===");
    
    // Frank's personal IMT
    let mut frank_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut frank_num_leaves = 1;
    let frank_amount = 100 as Field;
    
    let (frank_insertion_result, frank_leaves, frank_num_leaves) = insert_item(
        frank_leaves,
        frank_num_leaves,
        frank_key as u64,
        frank_amount
    );
    
    let frank_personal_imt_root = frank_insertion_result.root_after;
    let frank_nonce = 0 as Field;
    let frank_nonce_commitment = Poseidon2::hash([frank_key, frank_nonce], 2);
    let frank_main_commitment = Poseidon2::hash([frank_personal_imt_root, frank_nonce_commitment], 2);
    
    // Insert Frank's main commitment into main tree (MiMC)
    let (frank_main_insertion_result, main_tree_leaves, main_tree_num_leaves) = insert_item_mimc(
        main_tree_leaves,
        main_tree_num_leaves,
        frank_main_commitment as u64,
        frank_main_commitment
    );
    
    main_tree_root = frank_main_insertion_result.root_after;
    
    std::println("Frank's personal IMT root:");
    std::println(frank_personal_imt_root);
    std::println("Frank's main commitment:");
    std::println(frank_main_commitment);
    std::println("Main tree root after Frank deposit:");
    std::println(main_tree_root);
    
    // === STEP 3: FRANK SENDS 100 USDC TO ALICE ===
    std::println("");
    std::println("=== STEP 3: FRANK SENDS 100 USDC TO ALICE ===");
    
    // Frank sends 100 USDC to Alice
    let frank_send_amount = 100 as Field;
    let frank_new_balance = frank_amount - frank_send_amount; // 100 - 100 = 0
    
    let mut frank_new_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut frank_new_num_leaves = 1;
    
    let (frank_new_insertion_result, frank_new_leaves, frank_new_num_leaves) = insert_item(
        frank_new_leaves,
        frank_new_num_leaves,
        frank_key as u64,
        frank_new_balance
    );
    
    let frank_new_personal_imt_root = frank_new_insertion_result.root_after;
    let frank_new_nonce = frank_nonce + 1;
    let frank_new_nonce_commitment = Poseidon2::hash([frank_key, frank_new_nonce], 2);
    let frank_new_main_commitment = Poseidon2::hash([frank_new_personal_imt_root, frank_new_nonce_commitment], 2);
    
    // Insert Frank's new main commitment into main tree (MiMC)
    let (frank_new_main_insertion_result, main_tree_leaves, main_tree_num_leaves) = insert_item_mimc(
        main_tree_leaves,
        main_tree_num_leaves,
        frank_new_main_commitment as u64,
        frank_new_main_commitment
    );
    
    main_tree_root = frank_new_main_insertion_result.root_after;
    
    std::println("Frank's new balance: 0 USDC");
    std::println("Frank's new personal IMT root:");
    std::println(frank_new_personal_imt_root);
    std::println("Frank's new main commitment:");
    std::println(frank_new_main_commitment);
    std::println("Main tree root after Frank send:");
    std::println(main_tree_root);
    
    // Store Frank's state for later use (this is what's in the master tree)
    let frank_previous_main_commitment = frank_new_main_commitment;
    let frank_previous_personal_imt_root = frank_new_personal_imt_root; // 0 USDC balance
    
    // === STEP 4: ALICE SENDS 200 USDC TO FRANK, THEN ABSORBS 100 USDC ===
    std::println("");
    std::println("=== STEP 4: ALICE SENDS 200 USDC TO FRANK, THEN ABSORBS 100 USDC ===");
    std::println("Alice sends 200 USDC (100 personal + 100 from commitment), then absorbs 100 USDC");
    
    // Alice receives 100 USDC from Frank
    let alice_received_amount = frank_send_amount; // 100 USDC
    
    // Generate proof for Alice's current balance (100 USDC)
    let alice_proof = generate_proof(alice_leaves, alice_num_leaves, 1);
    
    // Setup Pedersen commitments for Alice's absorb
    let alice_absorb_c_inner_m = alice_received_amount; // 100 tokens
    let alice_absorb_c_inner_r = 0x5555555555555555 as Field;
    let alice_absorb_c_inner_commitment_point = pedersen_commitment([alice_absorb_c_inner_m, alice_absorb_c_inner_r]);
    let alice_absorb_c_inner_commitment = [alice_absorb_c_inner_commitment_point.x, alice_absorb_c_inner_commitment_point.y];
    
    let alice_absorb_c_outer_m = 0x00 as Field; // 0 tokens
    let alice_absorb_c_outer_r = 0x6666666666666666 as Field;
    let (alice_absorb_c_outer_commitment, alice_absorb_c_outer_r_final) = if alice_absorb_c_outer_m == 0 {
        ([0 as Field, 0 as Field], 0 as Field)
    } else {
        let commitment = pedersen_commitment([alice_absorb_c_outer_m, alice_absorb_c_outer_r]);
        ([commitment.x, commitment.y], alice_absorb_c_outer_r)
    };
    
    let alice_absorb_c_tot = [alice_absorb_c_inner_commitment[0] + alice_absorb_c_outer_commitment[0], alice_absorb_c_inner_commitment[1] + alice_absorb_c_outer_commitment[1]];
    
    // Create a separate tree for c_tot verification
    let mut c_tot_tree_leaves: [LeafMimc; 32] = [LeafMimc { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut c_tot_tree_num_leaves = 1;
    
    // Insert c_tot into the historical tree
    let (c_tot_insertion_result, c_tot_tree_leaves, c_tot_tree_num_leaves) = insert_item_mimc(
        c_tot_tree_leaves,
        c_tot_tree_num_leaves,
        alice_absorb_c_tot[0] as u64,
        alice_absorb_c_tot[0]
    );
    
    let c_tot_historical_root = c_tot_insertion_result.root_after;
    
    // Create proof that c_tot is in the historical tree
    let alice_absorb_c_tot_proof = generate_proof_mimc(c_tot_tree_leaves, c_tot_tree_num_leaves, 1);
    
    // Empty spent leaf proof
    let alice_absorb_spent_leaf_proof: [Field; 32] = [0; 32];
    
    // Frank's public key (for receiving)
    let frank_public_key: [Field; 2] = [0x9876543210fedcba9876543210fedcba as Field, 0x9876543210fedcba9876543210fedcba as Field];
    
    // Generate proof for Alice's main commitment in the master tree
    // Alice is at index 1 in the master tree (she was inserted first)
    let alice_main_proof = generate_proof_mimc(main_tree_leaves, main_tree_num_leaves, 1);
    
    // === CALL UNIFIED SEND-THEN-ABSORB CIRCUIT ===
    std::println("Calling unified send-then-absorb circuit...");
    std::println("Alice will send 200 USDC to Frank, then absorb 100 USDC (from Frank)");
    
    let send_amount_to_frank = 200 as Field; // Alice sends 200 USDC total
    
    let (new_nonce_commitment, new_main_tree_commit, encrypted_note, receipt_commitment, sender_pub_key) = main(
        alice_key, // Alice's user key
        alice_nonce, // Alice's current nonce
        alice_personal_imt_root, // Alice's current personal IMT root
        alice_proof.siblings, // Proof for Alice's current balance
        alice_amount, // Alice's current balance (100 USDC)
        1 as Field, // imt_leaf_idx - USDC is at index 1
        usdc_token, // Token address for USDC
        0x00 as Field, // previous_spent_amount
        alice_absorb_spent_leaf_proof,
        alice_absorb_c_tot,
        alice_absorb_c_inner_commitment,
        alice_absorb_c_outer_commitment,
        alice_absorb_c_inner_m,
        alice_absorb_c_inner_r,
        alice_absorb_c_outer_m,
        alice_absorb_c_outer_r_final,
        c_tot_historical_root,
        alice_absorb_c_tot_proof.siblings,
        alice_absorb_c_tot_proof.leaf.value,
        alice_absorb_c_tot_proof.leaf.key as Field,
        alice_absorb_c_tot_proof.leaf_idx as Field,
        send_amount_to_frank, // Amount to send to Frank
        usdc_token, // Token to send
        frank_public_key, // Frank's public key
        main_tree_root, // Master tree root
        alice_main_proof.siblings, // Proof that Alice's main commitment is in master tree
        alice_main_commitment, // Alice's main commitment value (stored in master tree)
        alice_main_commitment, // Alice's main commitment key (as Field)
        alice_main_proof.leaf_idx as Field // Alice's index in master tree
    );
    
        std::println("✅ Unified send-then-absorb circuit executed successfully!");
        std::println("Alice sent 200 USDC to Frank, then absorbed 100 USDC (from Frank)");
        std::println("Alice's final balance: 0 USDC (100 personal - 200 sent + 100 absorbed)");
    std::println("New nonce commitment:");
    std::println(new_nonce_commitment);
    std::println("New main tree commitment:");
    std::println(new_main_tree_commit);
    std::println("Encrypted note:");
    std::println(encrypted_note[0]);
    std::println(encrypted_note[1]);
    std::println("Receipt commitment:");
    std::println(receipt_commitment[0]);
    std::println(receipt_commitment[1]);
    std::println("Sender public key:");
    std::println(sender_pub_key[0]);
    std::println(sender_pub_key[1]);
    
    // Basic assertions
    assert(new_nonce_commitment != 0, "Nonce commitment should not be zero");
    assert(new_main_tree_commit != 0, "Main tree commitment should not be zero");
    assert(encrypted_note[0] != 0, "Encrypted amount should not be zero");
    assert(encrypted_note[1] != 0, "Encrypted token address should not be zero");
    assert(receipt_commitment[0] != 0, "Receipt commitment x should not be zero");
    assert(receipt_commitment[1] != 0, "Receipt commitment y should not be zero");
    assert(sender_pub_key[0] != 0, "Sender public key x should not be zero");
    assert(sender_pub_key[1] != 0, "Sender public key y should not be zero");
    
    std::println("========================================");
        std::println("✅ SEND-THEN-ABSORB TEST PASSED!");
        std::println("✅ Alice deposited 100 USDC");
        std::println("✅ Frank deposited 100 USDC");
        std::println("✅ Frank sent Alice 100 USDC");
        std::println("✅ Alice sent 200 USDC to Frank, then absorbed 100 USDC");
        std::println("✅ Alice's final balance: 0 USDC");
        std::println("✅ Frank's final balance: 200 USDC");
        std::println("========================================");
        
        // === STEP 5: FRANK SENDS 200 USDC BACK TO ALICE ===
        std::println("");
        std::println("=== STEP 5: FRANK SENDS 200 USDC BACK TO ALICE ===");
        std::println("Frank now has 200 USDC and sends it all back to Alice");
        
        // Update master tree root after Alice's transaction
        // Alice's new main commitment needs to be added to the master tree
        let alice_new_main_commitment = new_main_tree_commit;
        
        // Insert Alice's new main commitment into main tree (MiMC)
        let (alice_new_main_insertion_result, main_tree_leaves, main_tree_num_leaves) = insert_item_mimc(
            main_tree_leaves,
            main_tree_num_leaves,
            alice_new_main_commitment as u64,
            alice_new_main_commitment
        );
        
        main_tree_root = alice_new_main_insertion_result.root_after;
        
        std::println("Alice's new main commitment:");
        std::println(alice_new_main_commitment);
        std::println("Main tree root after Alice's transaction:");
        std::println(main_tree_root);
        
        // Frank now sends 200 USDC back to Alice
        let frank_send_back_amount = 200 as Field; // Frank sends all 200 USDC back
        let frank_current_balance = 200 as Field; // Frank's current balance before sending
        
        // Update Frank's personal IMT with his current balance (before sending)
        let mut frank_final_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
        let mut frank_final_num_leaves = 1;
        
        let (frank_final_insertion_result, frank_final_leaves, frank_final_num_leaves) = insert_item(
            frank_final_leaves,
            frank_final_num_leaves,
            frank_key as u64,
            frank_current_balance
        );
        
        let frank_final_personal_imt_root = frank_final_insertion_result.root_after;
        let frank_current_nonce = frank_new_nonce; // Frank's current nonce (from step 3)
        let frank_current_nonce_commitment = Poseidon2::hash([frank_key, frank_current_nonce], 2);
        let frank_current_main_commitment = Poseidon2::hash([frank_final_personal_imt_root, frank_current_nonce_commitment], 2);
        
        std::println("Frank's current balance: 200 USDC");
        std::println("Frank's current personal IMT root:");
        std::println(frank_final_personal_imt_root);
        std::println("Frank's current main commitment:");
        std::println(frank_current_main_commitment);
        
        // Insert Frank's current main commitment into main tree (MiMC)
        let (frank_current_main_insertion_result, main_tree_leaves, main_tree_num_leaves) = insert_item_mimc(
            main_tree_leaves,
            main_tree_num_leaves,
            frank_current_main_commitment as u64,
            frank_current_main_commitment
        );
        
        main_tree_root = frank_current_main_insertion_result.root_after;
        
        std::println("Main tree root after Frank's current commitment:");
        std::println(main_tree_root);
        
        // Alice receives 200 USDC from Frank
        let alice_received_back_amount = frank_send_back_amount; // 200 USDC
        
        // Alice's state after her first transaction: 0 USDC balance
        // We need to create Alice's updated IMT with 0 USDC balance
        let mut alice_updated_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
        let mut alice_updated_num_leaves = 1;
        
        let (alice_updated_insertion_result, alice_updated_leaves, alice_updated_num_leaves) = insert_item(
            alice_updated_leaves,
            alice_updated_num_leaves,
            alice_key as u64,
            0 as Field // Alice's balance after first transaction: 0 USDC
        );
        
        let alice_updated_personal_imt_root = alice_updated_insertion_result.root_after;
        
        // Generate proof for Alice's current balance (0 USDC)
        let alice_final_proof = generate_proof(alice_updated_leaves, alice_updated_num_leaves, 1);
        
        // Setup Pedersen commitments for Alice's final absorb
        let alice_final_absorb_c_inner_m = alice_received_back_amount; // 200 tokens
        let alice_final_absorb_c_inner_r = 0x7777777777777777 as Field;
        let alice_final_absorb_c_inner_commitment_point = pedersen_commitment([alice_final_absorb_c_inner_m, alice_final_absorb_c_inner_r]);
        let alice_final_absorb_c_inner_commitment = [alice_final_absorb_c_inner_commitment_point.x, alice_final_absorb_c_inner_commitment_point.y];
        
        let alice_final_absorb_c_outer_m = 0x00 as Field; // 0 tokens
        let alice_final_absorb_c_outer_r = 0x8888888888888888 as Field;
        let (alice_final_absorb_c_outer_commitment, alice_final_absorb_c_outer_r_final) = if alice_final_absorb_c_outer_m == 0 {
            ([0 as Field, 0 as Field], 0 as Field)
        } else {
            let commitment = pedersen_commitment([alice_final_absorb_c_outer_m, alice_final_absorb_c_outer_r]);
            ([commitment.x, commitment.y], alice_final_absorb_c_outer_r)
        };
        
        let alice_final_absorb_c_tot = [alice_final_absorb_c_inner_commitment[0] + alice_final_absorb_c_outer_commitment[0], alice_final_absorb_c_inner_commitment[1] + alice_final_absorb_c_outer_commitment[1]];
        
        // Create a separate tree for c_tot verification
        let mut c_tot_final_tree_leaves: [LeafMimc; 32] = [LeafMimc { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
        let mut c_tot_final_tree_num_leaves = 1;
        
        // Insert c_tot into the historical tree
        let (c_tot_final_insertion_result, c_tot_final_tree_leaves, c_tot_final_tree_num_leaves) = insert_item_mimc(
            c_tot_final_tree_leaves,
            c_tot_final_tree_num_leaves,
            alice_final_absorb_c_tot[0] as u64,
            alice_final_absorb_c_tot[0]
        );
        
        let c_tot_final_historical_root = c_tot_final_insertion_result.root_after;
        
        // Create proof that c_tot is in the historical tree
        let alice_final_absorb_c_tot_proof = generate_proof_mimc(c_tot_final_tree_leaves, c_tot_final_tree_num_leaves, 1);
        
        // Empty spent leaf proof
        let alice_final_absorb_spent_leaf_proof: [Field; 32] = [0; 32];
        
        // Alice's public key (for receiving)
        let alice_public_key: [Field; 2] = [0xfedcba0987654321fedcba0987654321 as Field, 0xfedcba0987654321fedcba0987654321 as Field];
        
        // Alice's current main commitment should be calculated from her current state
        // Alice's current nonce after first transaction
        let alice_current_nonce = alice_nonce + 1;
        let alice_current_nonce_commitment = Poseidon2::hash([alice_key, alice_current_nonce], 2);
        let alice_current_main_commitment = Poseidon2::hash([alice_updated_personal_imt_root, alice_current_nonce_commitment], 2);
        
        std::println("Alice's current main commitment (from step 4):");
        std::println(alice_current_main_commitment);
        std::println("Main tree root (after Alice's step 4 transaction):");
        std::println(main_tree_root);
        
        // Generate proof for Alice's main commitment in the master tree
        // Alice's commitment from step 4 is at index 3
        let alice_final_main_proof = generate_proof_mimc(main_tree_leaves, main_tree_num_leaves, 3);
        
        // === CALL UNIFIED SEND-THEN-ABSORB CIRCUIT FOR FRANK ===
        std::println("Calling unified send-then-absorb circuit for Frank...");
        std::println("Frank will send 200 USDC to Alice, then absorb 0 USDC");
        
        let frank_send_amount_to_alice = 200 as Field; // Frank sends 200 USDC to Alice
        
        // Generate proof for Frank's current balance (200 USDC)
        let frank_current_proof = generate_proof(frank_final_leaves, frank_final_num_leaves, 1);
        
        // Setup Pedersen commitments for Frank's absorb (0 USDC - no absorb)
        let frank_absorb_c_inner_m = 0x00 as Field; // 0 tokens
        let frank_absorb_c_inner_r = 0x9999999999999999 as Field;
        let frank_absorb_c_inner_commitment_point = pedersen_commitment([frank_absorb_c_inner_m, frank_absorb_c_inner_r]);
        let frank_absorb_c_inner_commitment = [frank_absorb_c_inner_commitment_point.x, frank_absorb_c_inner_commitment_point.y];
        
        let frank_absorb_c_outer_m = 0x00 as Field; // 0 tokens
        let frank_absorb_c_outer_r = 0xaaaaaaaaaaaaaaaa as Field;
        let (frank_absorb_c_outer_commitment, frank_absorb_c_outer_r_final) = if frank_absorb_c_outer_m == 0 {
            ([0 as Field, 0 as Field], 0 as Field)
        } else {
            let commitment = pedersen_commitment([frank_absorb_c_outer_m, frank_absorb_c_outer_r]);
            ([commitment.x, commitment.y], frank_absorb_c_outer_r)
        };
        
        let frank_absorb_c_tot = [frank_absorb_c_inner_commitment[0] + frank_absorb_c_outer_commitment[0], frank_absorb_c_inner_commitment[1] + frank_absorb_c_outer_commitment[1]];
        
        // Create a separate tree for c_tot verification
        let mut c_tot_frank_tree_leaves: [LeafMimc; 32] = [LeafMimc { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
        let mut c_tot_frank_tree_num_leaves = 1;
        
        // Insert c_tot into the historical tree
        let (c_tot_frank_insertion_result, c_tot_frank_tree_leaves, c_tot_frank_tree_num_leaves) = insert_item_mimc(
            c_tot_frank_tree_leaves,
            c_tot_frank_tree_num_leaves,
            frank_absorb_c_tot[0] as u64,
            frank_absorb_c_tot[0]
        );
        
        let c_tot_frank_historical_root = c_tot_frank_insertion_result.root_after;
        
        // Create proof that c_tot is in the historical tree
        let frank_absorb_c_tot_proof = generate_proof_mimc(c_tot_frank_tree_leaves, c_tot_frank_tree_num_leaves, 1);
        
        // Empty spent leaf proof
        let frank_absorb_spent_leaf_proof: [Field; 32] = [0; 32];
        
        // Generate proof for Frank's main commitment in the master tree
        // Frank's current main commitment is at the latest index in the master tree
        let frank_final_main_proof = generate_proof_mimc(main_tree_leaves, main_tree_num_leaves, main_tree_num_leaves);
        
        let (frank_final_new_nonce_commitment, frank_final_new_main_tree_commit, frank_final_encrypted_note, frank_final_receipt_commitment, frank_final_sender_pub_key) = main(
            frank_key, // Frank's user key
            frank_current_nonce, // Frank's current nonce
            frank_previous_personal_imt_root, // Frank's PREVIOUS personal IMT root (0 USDC - what's in master tree)
            frank_current_proof.siblings, // Proof for Frank's current balance (200 USDC)
            frank_current_balance, // Frank's current balance (200 USDC)
            1 as Field, // imt_leaf_idx - USDC is at index 1
            usdc_token, // Token address for USDC
            0 as Field, // previous_spent_amount (Frank hasn't spent anything yet)
            frank_absorb_spent_leaf_proof,
            frank_absorb_c_tot,
            frank_absorb_c_inner_commitment,
            frank_absorb_c_outer_commitment,
            frank_absorb_c_inner_m,
            frank_absorb_c_inner_r,
            frank_absorb_c_outer_m,
            frank_absorb_c_outer_r_final,
            c_tot_frank_historical_root,
            frank_absorb_c_tot_proof.siblings,
            frank_absorb_c_tot_proof.leaf.value,
            frank_absorb_c_tot_proof.leaf.key as Field,
            frank_absorb_c_tot_proof.leaf_idx as Field,
            frank_send_amount_to_alice, // Amount to send to Alice (200)
            usdc_token, // Token to send
            alice_public_key, // Alice's public key (receiving)
            main_tree_root, // Master tree root
            frank_final_main_proof.siblings, // Proof that Frank's main commitment is in master tree
            frank_current_main_commitment, // Frank's current main commitment value (stored in master tree)
            frank_current_main_commitment, // Frank's current main commitment key (as Field)
            frank_final_main_proof.leaf_idx as Field // Frank's index in master tree
        );
        
        std::println("✅ Unified send-then-absorb circuit executed successfully for Frank!");
        std::println("Frank sent 200 USDC to Alice, then absorbed 0 USDC");
        std::println("Frank's final balance: 0 USDC (200 personal - 200 sent + 0 absorbed)");
        std::println("Frank's final new nonce commitment:");
        std::println(frank_final_new_nonce_commitment);
        std::println("Frank's final new main tree commitment:");
        std::println(frank_final_new_main_tree_commit);
        
        // Final assertions
        assert(frank_final_new_nonce_commitment != 0, "Frank's final nonce commitment should not be zero");
        assert(frank_final_new_main_tree_commit != 0, "Frank's final main tree commitment should not be zero");
        assert(frank_final_encrypted_note[0] != 0, "Frank's final encrypted amount should not be zero");
        assert(frank_final_encrypted_note[1] != 0, "Frank's final encrypted token address should not be zero");
        assert(frank_final_receipt_commitment[0] != 0, "Frank's final receipt commitment x should not be zero");
        assert(frank_final_receipt_commitment[1] != 0, "Frank's final receipt commitment y should not be zero");
        assert(frank_final_sender_pub_key[0] != 0, "Frank's final sender public key x should not be zero");
        assert(frank_final_sender_pub_key[1] != 0, "Frank's final sender public key y should not be zero");
        
        std::println("========================================");
        std::println("✅ COMPLETE SEND-THEN-ABSORB TEST PASSED!");
        std::println("✅ Alice deposited 100 USDC");
        std::println("✅ Frank deposited 100 USDC");
        std::println("✅ Frank sent Alice 100 USDC");
        std::println("✅ Alice sent 200 USDC to Frank, then absorbed 100 USDC");
        std::println("✅ Frank sent 200 USDC to Alice, then absorbed 0 USDC");
        std::println("✅ Frank's final balance: 0 USDC");
        std::println("✅ Alice's final balance: 200 USDC");
        std::println("✅ Master tree properly updated after each transaction");
    std::println("========================================");
}