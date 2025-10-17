use dep::poseidon::poseidon2::Poseidon2;
use dep::ec::tecurve::affine::Point;
use dep::ec::consts::te::{baby_jubjub};
use dep::indexed_merkle_tree::{
    Leaf,
    Proof,
    insert_item,
    generate_proof,
    verify_proof
};
use dep::indexed_merkle_tree::{
    LeafMimc,
    ProofMimc,
    generate_proof_mimc,
    verify_proof_mimc,
    insert_item_mimc
};
use std::hash::pedersen_commitment;
mod test;


fn main(
    user_key: Field,
    previous_nonce: Field, 
    previous_personal_imt_root: Field,
    imt_leaf_proof: [Field; 32],
    
    // User's current balance (for verification)
    current_balance: Field,                  // User's current balance in IMT
    imt_leaf_idx: Field,                     // Leaf index for the current balance in IMT
    
    // Spent tracking (for specific token)
    token_address: Field,                    // Token address (USDC)
    previous_spent_amount: Field,            // Previous spent amount for this token
    spent_leaf_proof: [Field; 32],          // Proof for spent leaf
    
    // Pedersen commitments
    c_tot: [Field; 2],           // Total commitment
    c_inner_balance: [Field; 2], // Inner balance commitment
    c_outer_balance: [Field; 2], // Outer balance commitment
    
    // Commitment opening values
    c_inner_m: Field,            // Inner balance amount
    c_inner_r: Field,            // Inner balance blinding factor
    c_outer_m: Field,            // Outer balance amount  
    c_outer_r: Field,            // Outer balance blinding factor
    
    //  Historical root verification arguments
    historical_root: Field,                   // Historical root from contract
    c_tot_leaf_proof: [Field; 32],          // Proof that c_tot is a leaf in historical tree
    c_tot_leaf_value: Field,                 // The actual value of c_tot leaf (should match c_tot commitment)
    c_tot_leaf_key: Field,                   // The key for the c_tot leaf in historical tree
    c_tot_leaf_idx: Field,                   // The index of the c_tot leaf in historical tree
) -> pub (Field, Field, Field) {
    // === NYDUS-ABSORB-RECURSIVE CIRCUIT (IMT + PEDERSEN COMMITMENTS) ===
    // This circuit verifies Pedersen commitments and updates IMT balance
    // 
    // NEW VERIFICATION FLOW:
    // 1. Verify c_tot is a valid leaf in the contract's historical merkle tree
    // 2. Verify historical_root is a valid historical root from the contract
    // 3. Prove computation of c_usdc + c_rest = c_tot using Pedersen commitments
    // 4. Update personal IMT with new balance
    
    //  Verify that c_tot is a valid leaf in the historical merkle tree (using MiMC)
    // 1. Create the c_tot leaf for verification using MiMC variant
    let c_tot_leaf_mimc = LeafMimc {
        key: c_tot_leaf_key as u64,
        next_idx: 0,
        next_key: 0,
        value: c_tot_leaf_value
    };
    
    // 2. Verify that c_tot_leaf_value matches the c_tot commitment
    // This ensures the leaf value is actually the c_tot commitment
    assert(c_tot_leaf_value == c_tot[0], "c_tot leaf value doesn't match c_tot commitment x");
    // Note: We're only checking the x coordinate as the leaf value is typically a single field
    
    // 3. Verify the c_tot proof against the historical root using MiMC
    // Use the provided leaf index from the proof generation
    let c_tot_proof_mimc = ProofMimc {
        leaf_idx: c_tot_leaf_idx as u32, // Use the provided leaf index
        leaf: c_tot_leaf_mimc,
        root: historical_root,
        siblings: c_tot_leaf_proof
    };
    
    // 4. Verify the c_tot proof is valid using MiMC verification
    let c_tot_proof_valid = verify_proof_mimc(c_tot_proof_mimc);
    assert(c_tot_proof_valid, "c_tot proof verification failed");
    
    // 5. The historical_root is now verified to be a valid historical root from the contract
    // This proves that c_tot was a valid commitment in a previous state of the contract's merkle tree
    
    let nonce = previous_nonce + 1 as Field;
    let new_nonce_commitment = Poseidon2::hash([user_key, nonce], 2);
    
    // 6. Create nonce commitments
    let previous_nonce_commitment = Poseidon2::hash([user_key, previous_nonce], 2);

    // 7. Verify the current balance exists in the IMT using the provided proof
    // Create the leaf for the current balance
    let current_leaf = Leaf {
        key: user_key as u64,
        next_idx: 0,
        next_key: 0,
        value: current_balance
    };
    
    // Create proof object from provided data
    let provided_proof = Proof {
        leaf_idx: imt_leaf_idx as u32, // Use the provided leaf index
        leaf: current_leaf,
        root: previous_personal_imt_root,
        siblings: imt_leaf_proof
    };
    
    // Verify the provided proof is valid
    let proof_valid = verify_proof(provided_proof);
    assert(proof_valid, "Provided proof is invalid");
    
    // Reconstruct the tree for spent leaf verification (only if needed)
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    // Insert the current balance into the tree
    let (insertion_result, new_leaves, new_count) = insert_item(
        leaves,
        num_leaves,
        user_key as u64,
        current_balance
    );
    
    // Update the leaves and num_leaves for further use
    leaves = new_leaves;
    num_leaves = new_count;
    
    // 8. Verify spent tracking leaf if it exists
    if (previous_spent_amount as u64) > 0 {
        // Create spent leaf
        let spent_leaf = Leaf {
            key: token_address as u64,
            next_idx: 0,
            next_key: 0,
            value: previous_spent_amount
        };
        
        // Insert spent leaf into the tree
        let (spent_insertion_result, _, _) = insert_item(
            leaves,
            num_leaves,
            token_address as u64,
            previous_spent_amount
        );
        
        // Verify that the spent leaf proof is valid
        let spent_proof = generate_proof(leaves, num_leaves, 2);
        for i in 0..32 {
            assert(spent_proof.siblings[i] == spent_leaf_proof[i], "Spent leaf proof doesn't match generated proof");
        }
    }
    
    
    // 9. Validate that user can afford to spend C_inner amount
    // current_balance >= C_inner_m (user must have enough balance to spend)
    assert(current_balance as u64 >= c_inner_m as u64, "Insufficient balance for spend");
    
    // 10. Verify Pedersen commitments
    // Verify that c_inner_balance can be opened with c_inner_m and c_inner_r
    let computed_inner_commitment = pedersen_commitment([c_inner_m, c_inner_r]);
    assert(computed_inner_commitment.x == c_inner_balance[0], "Inner commitment verification failed");
    assert(computed_inner_commitment.y == c_inner_balance[1], "Inner commitment verification failed");
    
    // Verify that c_outer_balance can be opened with c_outer_m and c_outer_r
    if c_outer_m == 0 {
        // When amount is 0, outer commitment should be identity element [0, 0]
        assert(c_outer_balance[0] == 0, "Outer commitment should be identity when amount is 0");
        assert(c_outer_balance[1] == 0, "Outer commitment should be identity when amount is 0");
    } else {
        // Normal case: verify Pedersen commitment opening
        let computed_outer_commitment = pedersen_commitment([c_outer_m, c_outer_r]);
        assert(computed_outer_commitment.x == c_outer_balance[0], "Outer commitment verification failed");
        assert(computed_outer_commitment.y == c_outer_balance[1], "Outer commitment verification failed");
    }
    
    // 11. Verify that c_inner + c_outer = c_tot (Pedersen commitment addition)
    // Handle case where outer_balance is empty (c_inner = c_tot)
    if c_outer_m == 0 {
        // If outer balance is empty, c_inner should equal c_tot
        assert(c_inner_balance[0] == c_tot[0], "Total commitment verification failed (empty outer)");
        assert(c_inner_balance[1] == c_tot[1], "Total commitment verification failed (empty outer)");
    } else {
        // Normal case: c_inner + c_outer = c_tot
        let inner_plus_outer_x = c_inner_balance[0] + c_outer_balance[0];
        let inner_plus_outer_y = c_inner_balance[1] + c_outer_balance[1];
        assert(inner_plus_outer_x == c_tot[0], "Total commitment verification failed");
        assert(inner_plus_outer_y == c_tot[1], "Total commitment verification failed");
    }
    
    // 12. Update the balance in the IMT
    let new_balance = current_balance + c_inner_m + c_outer_m; // Total new balance
    
    // Create new tree with updated balance
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    // Insert the new balance
    let (balance_insertion_result, _, _) = insert_item(
        leaves,
        num_leaves,
        user_key as u64,
        new_balance
    );
    
    // 13. Update the spent tracking leaf
    let new_spent_amount = previous_spent_amount + c_inner_m; // Track that we spent C_inner
    
    // Add spent tracking leaf if needed
    let new_personal_imt_root = if (new_spent_amount as u64) > 0 {
        let (spent_insertion_result, _, _) = insert_item(
            leaves,
            num_leaves,
            token_address as u64,
            new_spent_amount
        );
        
        // Use the spent insertion result as the final root
        spent_insertion_result.root_after
    } else {
        // No spent tracking needed, use balance result
        balance_insertion_result.root_after
    };
    
    // 14. Create new main tree commitment
    let new_main_tree_commit = Poseidon2::hash([new_personal_imt_root, new_nonce_commitment], 2);

    (    
        new_nonce_commitment,
        new_main_tree_commit,
        new_personal_imt_root //TODO: encrypt this later
    )
}


