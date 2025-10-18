use dep::std;
use std::embedded_curve_ops::{EmbeddedCurvePoint, EmbeddedCurveScalar, multi_scalar_mul};
use dep::poseidon::poseidon2::Poseidon2;
use dep::poseidon_ctr_encryption::{poseidon_ctr_encrypt};
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
    verify_proof_mimc
};
use std::hash::pedersen_commitment;
mod test;

// === EXTENDED PEDERSEN COMMITMENT WITH DOMAIN SEPARATION ===
// Uses m*G + r*H + domain for token-specific domain separation

fn pedersen_commitment_token(m: Field, r: Field, token_address: Field) -> EmbeddedCurvePoint {
    // Get generators using derive_generators
    let generators: [EmbeddedCurvePoint; 3] = std::hash::derive_generators("DEFAULT_DOMAIN_SEPARATOR".as_bytes(), 0);
    let G = generators[0];  // First generator
    let H = generators[1];  // Second generator
    let D = generators[2];  // Third generator
    // Create scalars for multi_scalar_mul
    let mut scalars = [EmbeddedCurveScalar { lo: 0, hi: 0 }; 3];
    scalars[0] = from_field(m);
    scalars[1] = from_field(r);
    scalars[2] = from_field(token_address);
    
    // Create points for multi_scalar_mul: [G, H, G]
    let mut points = [EmbeddedCurvePoint::point_at_infinity(); 3];
    points[0] = G;
    points[1] = H;
    points[2] = D;  
    
    // Compute commitment: m*G + r*H + token_address*D
    multi_scalar_mul(points, scalars)
}

fn compute_decomposition(x: Field) -> (Field, Field) {
    // Here's we're taking advantage of truncating 128 bit limbs from the input field
    // and then subtracting them from the input such the field division is equivalent to integer division.
    let low = (x as u128) as Field;
    let high = (x - low) / TWO_POW_128;

    (low, high)
}

global TWO_POW_128: Field = 0x100000000000000000000000000000000;

fn from_field(scalar: Field) -> EmbeddedCurveScalar {
    // Safety: xlo and xhi decomposition is checked below
    let (xlo, xhi) =   compute_decomposition(scalar) ;
    // Check that the decomposition is correct
    assert_eq(scalar, xlo + TWO_POW_128 * xhi);
    EmbeddedCurveScalar { lo: xlo, hi: xhi }
}

fn perform_dh_key_exchange(sender_private_key: Field, receiver_public_key: [Field; 2]) -> ([Field; 2], Field) {
    // === DIFFIE-HELLMAN KEY EXCHANGE ===
    // Create Baby Jubjub curve for DH
    let bjj = baby_jubjub();
    let generator = bjj.base8;
    
    // Generate sender's public key: sender_pub_key = sender_private_key * generator
    let sender_public_key = bjj.curve.mul(sender_private_key, generator);
    
    // Reconstruct receiver's public key from the input
    let receiver_pub_key = Point::new(receiver_public_key[0], receiver_public_key[1]);
    
    // Compute shared secret: shared_secret = sender_private_key * receiver_public_key
    let shared_secret = bjj.curve.mul(sender_private_key, receiver_pub_key);
    
    // Hash the shared secret to get a final shared key
    let shared_key = Poseidon2::hash([shared_secret.x, shared_secret.y], 2);
    ([sender_public_key.x, sender_public_key.y], shared_key)
}

fn main(
    // === ABSORB PARAMETERS ===
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
    
    // Historical root verification arguments
    historical_root: Field,                   // Historical root from contract
    c_tot_leaf_proof: [Field; 32],          // Proof that c_tot is a leaf in historical tree
    c_tot_leaf_value: Field,                 // The actual value of c_tot leaf (should match c_tot commitment)
    c_tot_leaf_key: Field,                   // The key for the c_tot leaf in historical tree
    c_tot_leaf_idx: Field,                   // The index of the c_tot leaf in historical tree
    
    // === SEND PARAMETERS ===
    send_amount: pub Field,
    send_token_address: pub Field,
    receiver_public_key: pub [Field; 2],
    master_tree_root: pub Field,                    // Master tree root from contract
    personal_imt_root_proof: pub [Field; 32],      // Proof that personal_imt_root is a leaf in master tree
    personal_imt_root_leaf_value: pub Field,       // The actual value of personal_imt_root leaf
    personal_imt_root_leaf_key: pub Field,          // The key for the personal_imt_root leaf in master tree
    personal_imt_root_leaf_idx: pub Field,          // The index of the personal_imt_root leaf in master tree
) -> pub (Field, Field, [Field; 2], [Field; 2], [Field; 2]) {
    // === NYDUS-SEND-ABSORB UNIFIED CIRCUIT ===
    // This circuit performs send then absorb operations in sequence
    // 
    // FLOW:
    // 1. SEND: Send funds (allowing temporary negative balance)
    // 2. ABSORB: Absorb new funds to get final positive balance
    
    // === STEP 1: SEND OPERATION ===
    
    // 1.1. Update nonce
    let nonce = previous_nonce + 1 as Field;
    let new_nonce_commitment = Poseidon2::hash([user_key, nonce], 2);
    let previous_nonce_commitment = Poseidon2::hash([user_key, previous_nonce], 2);

    // 1.2. Verify the current balance exists in the IMT
    let current_leaf = Leaf {
        key: user_key as u64,
        next_idx: 0,
        next_key: 0,
        value: current_balance
    };
    
    let provided_proof = Proof {
        leaf_idx: imt_leaf_idx as u32,
        leaf: current_leaf,
        root: previous_personal_imt_root,
        siblings: imt_leaf_proof
    };
    
    let proof_valid = verify_proof(provided_proof);
    assert(proof_valid, "Provided proof is invalid");
    
    // 1.3. Verify that personal_imt_root is a valid leaf in the master tree
    let main_commitment_proof_mimc = ProofMimc {
        leaf_idx: personal_imt_root_leaf_idx as u32,
        leaf: LeafMimc {
            key: personal_imt_root_leaf_key as u64,
            next_idx: 0,
            next_key: 0,
            value: personal_imt_root_leaf_value
        },
        root: master_tree_root,
        siblings: personal_imt_root_proof
    };
    
    let main_commitment_proof_valid = verify_proof_mimc(main_commitment_proof_mimc);
    assert(main_commitment_proof_valid, "Main commitment proof verification failed");
    
    // 1.4. Verify that the main commitment corresponds to the user's current state
    let expected_main_commitment = Poseidon2::hash([previous_personal_imt_root, Poseidon2::hash([user_key, previous_nonce], 2)], 2);
    assert(personal_imt_root_leaf_value == expected_main_commitment, "Main commitment doesn't match user's current state");
    
    // 1.5. Calculate balance after send (allow negative temporarily)
    let balance_after_send = current_balance - send_amount;
    
    // === STEP 2: ABSORB OPERATION ===
    
    // 2.1. Verify that c_tot is a valid leaf in the historical merkle tree (using MiMC)
    let c_tot_leaf_mimc = LeafMimc {
        key: c_tot_leaf_key as u64,
        next_idx: 0,
        next_key: 0,
        value: c_tot_leaf_value
    };
    
    // Verify that c_tot_leaf_value matches the c_tot commitment
    assert(c_tot_leaf_value == c_tot[0], "c_tot leaf value doesn't match c_tot commitment x");
    
    // Verify the c_tot proof against the historical root using MiMC
    let c_tot_proof_mimc = ProofMimc {
        leaf_idx: c_tot_leaf_idx as u32,
        leaf: c_tot_leaf_mimc,
        root: historical_root,
        siblings: c_tot_leaf_proof
    };
    
    let c_tot_proof_valid = verify_proof_mimc(c_tot_proof_mimc);
    assert(c_tot_proof_valid, "c_tot proof verification failed");
    
    // 2.2. Verify Pedersen commitments
    let computed_inner_commitment = pedersen_commitment([c_inner_m, c_inner_r]);
    assert(computed_inner_commitment.x == c_inner_balance[0], "Inner commitment verification failed");
    assert(computed_inner_commitment.y == c_inner_balance[1], "Inner commitment verification failed");
    
    if c_outer_m == 0 {
        assert(c_outer_balance[0] == 0, "Outer commitment should be identity when amount is 0");
        assert(c_outer_balance[1] == 0, "Outer commitment should be identity when amount is 0");
    } else {
        let computed_outer_commitment = pedersen_commitment([c_outer_m, c_outer_r]);
        assert(computed_outer_commitment.x == c_outer_balance[0], "Outer commitment verification failed");
        assert(computed_outer_commitment.y == c_outer_balance[1], "Outer commitment verification failed");
    }
    
    // 2.3. Verify that c_inner + c_outer = c_tot
    if c_outer_m == 0 {
        assert(c_inner_balance[0] == c_tot[0], "Total commitment verification failed (empty outer)");
        assert(c_inner_balance[1] == c_tot[1], "Total commitment verification failed (empty outer)");
    } else {
        let inner_plus_outer_x = c_inner_balance[0] + c_outer_balance[0];
        let inner_plus_outer_y = c_inner_balance[1] + c_outer_balance[1];
        assert(inner_plus_outer_x == c_tot[0], "Total commitment verification failed");
        assert(inner_plus_outer_y == c_tot[1], "Total commitment verification failed");
    }
    
    // 2.4. Calculate final balance after absorb
    let final_balance = balance_after_send + c_inner_m + c_outer_m;
    
    // 2.5. Assert final balance is non-negative
    assert(final_balance as u64 >= 0, "Final balance must be non-negative");
    
    // 2.6. Update the personal IMT with final balance (single update!)
    let mut final_leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut final_num_leaves = 1;
    
    // Single IMT update with final balance
    let (final_insertion_result, _, _) = insert_item(
        final_leaves,
        final_num_leaves,
        send_token_address as u64,
        final_balance
    );
    
    let final_personal_imt_root = final_insertion_result.root_after;
    
    // 2.7. Update spent tracking
    // In send-then-absorb flow: only track what was actually sent, not what was absorbed
    let new_spent_amount = previous_spent_amount + send_amount;
    
    // 2.8. Create new main tree commitment
    let new_main_tree_commit = Poseidon2::hash([final_personal_imt_root, new_nonce_commitment], 2);

    // 2.7. Perform Diffie-Hellman key exchange
    let (sender_pub_key, shared_key) = perform_dh_key_exchange(user_key + nonce as Field, receiver_public_key);

    // 2.8. Encrypt the transaction data
    let shared_key_hash = Poseidon2::hash([shared_key], 1);
    
    let encrypted_amount = poseidon_ctr_encrypt(send_amount, shared_key_hash, 0);
    let encrypted_token_address = poseidon_ctr_encrypt(send_token_address, shared_key_hash, 1);
    let encrypted_note = [encrypted_amount, encrypted_token_address];
    
    // 2.9. Create view key encryption for the event
    let user_key_hash = Poseidon2::hash([user_key], 1);
    let view_string = 0x76696577696e675f6b6579 as Field;
    let view_key = Poseidon2::hash([view_string, user_key_hash], 2);
    
    let encrypted_amount_view = poseidon_ctr_encrypt(send_amount, view_key, 0);
    let encrypted_token_address_view = poseidon_ctr_encrypt(send_token_address, view_key, 1);
    
    // 2.10. Create Pedersen commitment for receipt
    let receipt_commitment = pedersen_commitment_token(send_amount, shared_key_hash, send_token_address);

    (   
        new_nonce_commitment,
        new_main_tree_commit,
        encrypted_note,
        [receipt_commitment.x, receipt_commitment.y],        
        sender_pub_key
    )
}