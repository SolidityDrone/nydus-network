use crate::main;
use dep::poseidon::poseidon2::Poseidon2;
use dep::indexed_merkle_tree::{
    Leaf,
    insert_item,
    generate_proof,
    verify_proof,
    // MiMC variant for historical root
    LeafMimc,
    insert_item_mimc,
    generate_proof_mimc
};
use std::hash::pedersen_commitment;

#[test]
fn test_simple_prover_toml_generation() {
    // Simple test to generate Prover.toml for nydus-absorb using indexed merkle tree
    // This is a minimal version that should work
    
    let user_key = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef as Field;
    let previous_nonce = 0x00 as Field;
    let token_address = 0x58002bee8f43bf203964d38c54fa03e62d615959fa as Field;
    let current_balance = 0x32 as Field; // 50 tokens
    
    // Create indexed merkle tree
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    // Insert current balance
    let (insertion_result, new_leaves, new_num_leaves) = insert_item(
        leaves,
        num_leaves,
        user_key as u64,
        current_balance
    );
    
    let previous_personal_imt_root = insertion_result.root_after;
    
    // Generate proof for current balance using the updated tree
    let proof = generate_proof(new_leaves, new_num_leaves, 1);
    let imt_leaf_proof = proof.siblings;
    
    // Setup commitments using extended Pedersen with token address domain separation
    // Based on test_homomorphism.nr: C = m*G + r*H + token_address*G
    let c_inner_m = 0x19 as Field; // 25 tokens (inner balance - what we want to prove)
    let c_inner_r = 0xabcdef1234567890 as Field; // Inner blinding factor
    let c_inner_commitment = pedersen_commitment([c_inner_m, c_inner_r]);
    
    let c_outer_m = 0x0a as Field; // 10 tokens (outer balance - rest of commitments)
    let c_outer_r = 0x1234567890abcdef as Field; // Outer blinding factor
    let c_outer_commitment = pedersen_commitment([c_outer_m, c_outer_r]);
    
    // Total commitment: c_inner + c_outer
    let c_tot = [c_inner_commitment.x + c_outer_commitment.x, c_inner_commitment.y + c_outer_commitment.y];
    
    // === SIMULATE HISTORICAL ROOT AND C_TOT PROOF ===
    // Create a master tree using MiMC that contains c_tot as a leaf
    let mut master_leaves_mimc: [LeafMimc; 32] = [LeafMimc { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut master_num_leaves_mimc = 1;
    
    // Insert c_tot into master tree using MiMC (simulating historical storage)
    let (master_insertion_result_mimc, master_new_leaves_mimc, master_new_num_leaves_mimc) = insert_item_mimc(
        master_leaves_mimc,
        master_num_leaves_mimc,
        c_tot[0] as u64, // Use c_tot[0] as the key
        c_tot[0] // Use c_tot[0] as the value
    );
    
    let historical_root = master_insertion_result_mimc.root_after;
    
    // Generate proof that c_tot is in the historical tree using MiMC
    let c_tot_proof = generate_proof_mimc(master_new_leaves_mimc, master_new_num_leaves_mimc, 1);
    
    // Empty spent leaf proof for first time
    let spent_leaf_proof: [Field; 32] = [0; 32];
    
    // Run main function
    let (new_nonce_commitment, new_main_tree_commit, new_personal_imt_root) = main(
        user_key,
        previous_nonce,
        previous_personal_imt_root,
        imt_leaf_proof,
        current_balance,
        1 as Field, // imt_leaf_idx - first leaf is at index 1
        token_address,
        0x00 as Field, // previous_spent_amount
        spent_leaf_proof,
        c_tot,
        [c_inner_commitment.x, c_inner_commitment.y],
        [c_outer_commitment.x, c_outer_commitment.y],
        c_inner_m,
        c_inner_r,
        c_outer_m,
        c_outer_r,
        // Historical root verification arguments
        historical_root,
        c_tot_proof.siblings,
        c_tot_proof.leaf.value,
        c_tot_proof.leaf.key as Field,
        c_tot_proof.leaf_idx as Field
    );
    
    // Print Prover.toml format
    std::println("========================================");
    std::println("COPY THIS TO nydus-absorb/Prover.toml");
    std::println("========================================");
    std::println("");
    
    std::print("c_inner_balance = [\"");
    std::print(c_inner_commitment.x);
    std::print("\", \"");
    std::print(c_inner_commitment.y);
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
    
    std::print("c_outer_balance = [\"");
    std::print(c_outer_commitment.x);
    std::print("\", \"");
    std::print(c_outer_commitment.y);
    std::println("\"]");
    std::println("");
    
    std::print("c_outer_m = \"");
    std::print(c_outer_m);
    std::println("\"");
    std::println("");
    
    std::print("c_outer_r = \"");
    std::print(c_outer_r);
    std::println("\"");
    std::println("");
    
    std::print("c_tot = [\"");
    std::print(c_tot[0]);
    std::print("\", \"");
    std::print(c_tot[1]);
    std::println("\"]");
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
    
    std::print("user_key = \"");
    std::print(user_key);
    std::println("\"");
    std::println("");
    
    std::print("token_address = \"");
    std::print(token_address);
    std::println("\"");
    std::println("");
    
    std::print("previous_spent_amount = \"");
    std::print(0x00 as Field);
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
    
    std::print("current_balance = \"");
    std::print(current_balance);
    std::println("\"");
    std::println("");
    
    std::println("========================================");
    std::println("EXPECTED OUTPUTS:");
    std::println("========================================");
    std::print("new_nonce_commitment = \"");
    std::print(new_nonce_commitment);
    std::println("\"");
    std::println("");
    
    std::print("new_main_tree_commit = \"");
    std::print(new_main_tree_commit);
    std::println("\"");
    std::println("");
    
    std::print("new_personal_imt_root = \"");
    std::print(new_personal_imt_root);
    std::println("\"");
    std::println("");
    
    std::println("========================================");
    std::println("✅ Simple Prover.toml generated successfully!");
    std::print("New balance: ");
    std::print(current_balance + c_inner_m + c_outer_m);
    std::println(" tokens (50 + 25 + 10 = 85)");
    std::println("========================================");
}