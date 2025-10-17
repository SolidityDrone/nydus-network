use dep::std;

use std::embedded_curve_ops::{EmbeddedCurvePoint, EmbeddedCurveScalar, fixed_base_scalar_mul, multi_scalar_mul};
use dep::poseidon::poseidon2::Poseidon2;
use dep::poseidon_ctr_encryption::{poseidon_ctr_encrypt};
use dep::ec::tecurve::affine::{Curve, Point};
use dep::ec::consts::te::{baby_jubjub};
use dep::indexed_merkle_tree::{
    Leaf,
    insert_item,
    empty_root
};


mod test;

fn main(
    user_key: Field,
    token_address: pub Field,
    amount: pub Field,
) -> pub (Field, Field, [Field; 4]) {
  
    let nonce_commitment = 
        Poseidon2::hash([user_key, 0 as Field], 2);
    
    let personal_imt_root = 
        create_initial_personal_indexed_tree(user_key, token_address, amount);

    let main_indexed_tree_commitment = 
        Poseidon2::hash([personal_imt_root, nonce_commitment], 2);
    
    let user_key_hash = Poseidon2::hash([user_key], 1);
    // === POSEIDON CTR MODE ENCRYPTION ===

    let view_string = 0x76696577696e675f6b6579 as Field;
    let view_key = Poseidon2::hash([view_string, user_key_hash], 2);
    
    // Encrypt amount, token_address, and personal IMT root
    // We encrypt 3 fields: amount, token_address, personal_imt_root 
    let encrypted_amount = poseidon_ctr_encrypt(amount, view_key, 0);
    let encrypted_token_address = poseidon_ctr_encrypt(token_address, view_key, 1);
    let encrypted_personal_imt_root = poseidon_ctr_encrypt(personal_imt_root, view_key, 2);
    
    let encrypted_event = [encrypted_amount, encrypted_token_address, encrypted_personal_imt_root, 0];
    
    (        
        main_indexed_tree_commitment,                      
        nonce_commitment,
        encrypted_event                  
    )
}



fn bjj_pub_key(priv_key: Field) -> Point {
    // Create Baby Jubjub curve using std library
    let bjj = baby_jubjub();
    
    // Get the base point (generator) from the curve
    let base_pt = bjj.base8;

    // Generate public key: public_key = private_key * base_point
    bjj.curve.mul(priv_key, base_pt)
}

fn create_initial_personal_indexed_tree(
    user_key: Field,
    token_address: Field,
    amount: Field
) -> Field {
    // === INDEXED MERKLE TREE FOR PERSONAL BALANCES ===
    // Create a new indexed merkle tree to track user's token balances
    // Key: token_address, Value: amount
    
    // Initialize with empty tree (zero item for exclusion proofs)
    let mut leaves: [Leaf; 32] = [Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 }; 32];
    let mut num_leaves = 1; // Start with the zero item
    
    // Insert the initial balance entry
    // Key = token_address, Value = amount
    let (insertion_result, new_leaves, new_num_leaves) = insert_item(
        leaves,
        num_leaves,
        token_address as u64,
        amount
    );
    
    // Return the new root after insertion
    insertion_result.root_after
}





