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
// Removed unused import
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
    
) -> pub () {
    
}



// Removed unused function

// Removed unused function



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
