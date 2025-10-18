use dep::std;
use std::embedded_curve_ops::{EmbeddedCurvePoint, EmbeddedCurveScalar, multi_scalar_mul};
use dep::poseidon::poseidon2::Poseidon2;
use dep::poseidon_ctr_encryption::{poseidon_ctr_encrypt};
use dep::ec::tecurve::affine::{Point};
use dep::ec::consts::te::{baby_jubjub};
use dep::indexed_merkle_tree::{
    Leaf,
    Proof,
    insert_item,
    verify_proof
};
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

// Removed unused function

global TWO_POW_128: Field = 0x100000000000000000000000000000000;


fn from_field(scalar: Field) -> EmbeddedCurveScalar {
    // Safety: xlo and xhi decomposition is checked below
    let (xlo, xhi) =   compute_decomposition(scalar) ;
    // Check that the decomposition is correct
    assert_eq(scalar, xlo + TWO_POW_128 * xhi);
    EmbeddedCurveScalar { lo: xlo, hi: xhi }
}


fn main(
    user_key: Field,
    token_address: Field,
    amount: Field,
    current_amount: Field,
    previous_nonce: Field, 
    previous_personal_imt_root: Field,
    imt_leaf_proof: [Field; 32], 
    receiver_public_key: [Field; 2],
    
    
    master_tree_root: pub Field,                    // Master tree root from contract
    personal_imt_root_proof: [Field; 32],      // Proof that personal_imt_root is a leaf in master tree
    personal_imt_root_leaf_value:  Field,       // The actual value of personal_imt_root leaf
    personal_imt_root_leaf_key:  Field,          // The key for the personal_imt_root leaf in master tree
    personal_imt_root_leaf_idx:  Field,          // The index of the personal_imt_root leaf in master tree
) -> pub (Field, Field, [Field; 2], [Field; 2], [Field; 2]) {
    // === TWO-LEVEL TREE VERIFICATION ===
    // 1. Verify that personal_imt_root is a valid leaf in the master tree
    // 2. Verify the user's balance in their personal IMT
    // 3. Perform the send operation
    
    // NEW: Verify that personal_imt_root is a valid leaf in the master tree
    // 1. Create the personal_imt_root leaf for verification
    let personal_imt_root_leaf = Leaf {
        key: personal_imt_root_leaf_key as u64,
        next_idx: 0,
        next_key: 0,
        value: personal_imt_root_leaf_value
    };
    
    // 2. Verify that personal_imt_root_leaf_value matches the personal_imt_root
    assert(personal_imt_root_leaf_value == previous_personal_imt_root, "Personal IMT root leaf value doesn't match provided personal_imt_root");
    
    // 3. Verify the personal_imt_root proof against the master tree root
    // Use the provided leaf index from the proof generation
    let personal_imt_root_proof = Proof {
        leaf_idx: personal_imt_root_leaf_idx as u32, // Use the provided leaf index
        leaf: personal_imt_root_leaf,
        root: master_tree_root,
        siblings: personal_imt_root_proof
    };
    
    // 4. Verify the personal_imt_root proof is valid
    let personal_imt_root_proof_valid = verify_proof(personal_imt_root_proof);
    assert(personal_imt_root_proof_valid, "Personal IMT root proof verification failed");
    
    // 5. The master_tree_root is now verified to be a valid root from the contract
    // This proves that personal_imt_root was a valid leaf in the master tree
    
    assert((current_amount as u64) >= (amount as u64));
    let nonce = previous_nonce + 1 as Field;
    let previous_nonce_commitment = 
        Poseidon2::hash([user_key, previous_nonce as Field], 2);
  
    let new_nonce_commitment = 
        Poseidon2::hash([user_key, previous_nonce_commitment + 1 as Field], 2);
    
    // === PERSONAL IMT VERIFICATION ===
    // Now verify the user's balance in their personal IMT (second level verification)
    
    // Calculate new balance after spending
    let new_balance = (current_amount as u64 - amount as u64) as Field;
    
    // Create a proof from the provided siblings to verify the current balance
    // The proof contains the actual leaf structure from the tree
    let current_leaf = Leaf {
        key: token_address as u64,
        next_idx: 0, 
        next_key: 0, 
        value: current_amount
    };
    
    let current_proof = Proof {
        leaf_idx: 1, // The leaf is at index 1 (after the zero item)
        leaf: current_leaf,
        root: previous_personal_imt_root,
        siblings: imt_leaf_proof
    };
    
    // Verify that the current balance proof is valid
    assert(verify_proof(current_proof), "Current balance proof should be valid");
    
    // Update the leaf with the new balance
    let updated_leaf = Leaf {
        key: token_address as u64,
        next_idx: 0,
        next_key: 0,
        value: new_balance
    };
    
    // Removed unused variable
    
    // For now, we'll compute the new root by creating a simple tree with the updated balance
    // In a real implementation, you would update the existing tree structure
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1;
    
    let (insertion_result, _, _) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        new_balance
    );
    
    // Create new personal indexed merkle tree root hash
    let new_personal_imt_root = insertion_result.root_after;
    
    // Create new main tree commitment
    let new_main_tree_commit = Poseidon2::hash([new_personal_imt_root, new_nonce_commitment], 2);

    // Perform Diffie-Hellman key exchange
    let (sender_pub_key, shared_key) = perform_dh_key_exchange(user_key + nonce as Field, receiver_public_key);


    // === POSEIDON CTR MODE ENCRYPTION ===
    // Encrypt each field separately using Poseidon in CTR mode
    
    // Create shared key hash for encryption
    let shared_key_hash = Poseidon2::hash([shared_key], 1);
    
    // Encrypt only amount and token_address (2 fields)
    let encrypted_amount = poseidon_ctr_encrypt(amount, shared_key_hash, 0);
    let encrypted_token_address = poseidon_ctr_encrypt(token_address, shared_key_hash, 1);
    let encrypted_note = [encrypted_amount, encrypted_token_address];
    
    // For encrypted_event, use view key approach (like in nydus-entry) to encrypt only 2 fields
    let user_key_hash = Poseidon2::hash([user_key], 1);
    let view_string = 0x76696577696e675f6b6579 as Field;
    let view_key = Poseidon2::hash([view_string, user_key_hash], 2);
    
    // Encrypt only amount and token_address using view key
    let encrypted_amount = poseidon_ctr_encrypt(amount, view_key, 0);
    let encrypted_token_address = poseidon_ctr_encrypt(token_address, view_key, 1);
    
    // === PEDERSEN COMMITMENT FOR RECEIPT ===
    // Create token-specific Pedersen commitment: C = m*G_token + r*H_token
    // Where m = amount, r = shared_key_hash (blinding factor)
    let receipt_commitment = pedersen_commitment_token(amount, shared_key_hash, token_address);

    (   
        new_nonce_commitment,
        new_main_tree_commit,
        encrypted_note,
        [receipt_commitment.x, receipt_commitment.y],        
        sender_pub_key
    )
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
