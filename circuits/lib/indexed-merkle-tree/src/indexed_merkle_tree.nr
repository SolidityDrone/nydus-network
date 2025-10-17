use dep::poseidon::poseidon2::Poseidon2;

global MAX_DEPTH: u32 = 32;

pub struct Leaf {
    pub key: u64,
    pub next_idx: u32,
    pub next_key: u64,
    pub value: Field
}

pub struct Proof {
    pub leaf_idx: u32,
    pub leaf: Leaf,
    pub root: Field,
    pub siblings: [Field; MAX_DEPTH]
}

pub struct InsertionResult {
    pub og_leaf_idx: u32,
    pub og_leaf_key: u64,
    pub og_leaf_next_idx: u32,
    pub og_leaf_next_key: u64,
    pub og_leaf_value: Field,
    pub new_leaf_idx: u32,
    pub new_leaf_key: u64,
    pub new_leaf_value: Field,
    pub root_before: Field,
    pub root_after: Field,
    pub siblings_before: [Field; MAX_DEPTH],
    pub siblings_after_og: [Field; MAX_DEPTH],
    pub siblings_after_new: [Field; MAX_DEPTH]
}

pub fn empty_root() -> Field {
    let zero_leaf = Leaf { key: 0, next_idx: 0, next_key: 0, value: 0 };
    Poseidon2::hash([0, 0, 0, 0], 4)
}

fn hash_leaf(leaf: Leaf) -> Field {
    Poseidon2::hash([
        leaf.key as Field,
        leaf.next_idx as Field,
        leaf.next_key as Field,
        leaf.value
    ], 4)
}

fn hash_children(left: Field, right: Field) -> Field {
    Poseidon2::hash([left, right], 2)
}

pub fn compute_root(leaves: [Leaf; MAX_DEPTH], num_leaves: u32) -> Field {
    let mut hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    let empty = empty_root();
    
    // Hash all leaves
    for i in 0..MAX_DEPTH {
        if i < num_leaves {
            hashes[i] = hash_leaf(leaves[i]);
        } else {
            hashes[i] = empty;
        }
    }
    
    // Build tree bottom-up with fixed loop bounds
    let mut current_hashes = hashes;
    
    // Level 0: 32 -> 16
    let mut next_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..16 {
        next_hashes[i] = hash_children(current_hashes[i * 2], current_hashes[i * 2 + 1]);
    }
    current_hashes = next_hashes;
    
    // Level 1: 16 -> 8
    let mut next_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..8 {
        next_hashes[i] = hash_children(current_hashes[i * 2], current_hashes[i * 2 + 1]);
    }
    current_hashes = next_hashes;
    
    // Level 2: 8 -> 4
    let mut next_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..4 {
        next_hashes[i] = hash_children(current_hashes[i * 2], current_hashes[i * 2 + 1]);
    }
    current_hashes = next_hashes;
    
    // Level 3: 4 -> 2
    let mut next_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..2 {
        next_hashes[i] = hash_children(current_hashes[i * 2], current_hashes[i * 2 + 1]);
    }
    current_hashes = next_hashes;
    
    // Level 4: 2 -> 1
    let mut next_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    next_hashes[0] = hash_children(current_hashes[0], current_hashes[1]);
    
    next_hashes[0]
}

pub fn generate_proof(leaves: [Leaf; MAX_DEPTH], num_leaves: u32, leaf_idx: u32) -> Proof {
    let leaf = leaves[leaf_idx];
    let root = compute_root(leaves, num_leaves);
    let mut siblings: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    let mut hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    let empty = empty_root();
    
    for i in 0..MAX_DEPTH {
        if i < num_leaves {
            hashes[i] = hash_leaf(leaves[i]);
        } else {
            hashes[i] = empty;
        }
    }
    
    let mut idx = leaf_idx;
    
    // Level 0: 32 -> 16
    let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
    siblings[0] = hashes[sibling_idx];
    let mut new_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..16 {
        new_hashes[i] = hash_children(hashes[i * 2], hashes[i * 2 + 1]);
    }
    hashes = new_hashes;
    idx = idx / 2;
    
    // Level 1: 16 -> 8
    let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
    siblings[1] = hashes[sibling_idx];
    let mut new_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..8 {
        new_hashes[i] = hash_children(hashes[i * 2], hashes[i * 2 + 1]);
    }
    hashes = new_hashes;
    idx = idx / 2;
    
    // Level 2: 8 -> 4
    let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
    siblings[2] = hashes[sibling_idx];
    let mut new_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..4 {
        new_hashes[i] = hash_children(hashes[i * 2], hashes[i * 2 + 1]);
    }
    hashes = new_hashes;
    idx = idx / 2;
    
    // Level 3: 4 -> 2
    let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
    siblings[3] = hashes[sibling_idx];
    let mut new_hashes: [Field; MAX_DEPTH] = [0; MAX_DEPTH];
    for i in 0..2 {
        new_hashes[i] = hash_children(hashes[i * 2], hashes[i * 2 + 1]);
    }
    hashes = new_hashes;
    idx = idx / 2;
    
    // Level 4: 2 -> 1
    let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
    siblings[4] = hashes[sibling_idx];
    
    Proof { leaf_idx: leaf_idx, leaf: leaf, root: root, siblings: siblings }
}

pub fn verify_proof(proof: Proof) -> bool {
    let mut current_hash = hash_leaf(proof.leaf);
    let mut idx = proof.leaf_idx;
    
    for i in 0..5 {
        if idx % 2 == 0 {
            current_hash = hash_children(current_hash, proof.siblings[i]);
        } else {
            current_hash = hash_children(proof.siblings[i], current_hash);
        }
        idx = idx / 2;
    }
    
    current_hash == proof.root
}

pub fn verify_exclusion_proof(excluded_key: u64, proof: Proof) -> bool {
    let is_after_leaf = excluded_key > proof.leaf.key;
    let is_before_next = (proof.leaf.next_idx == 0) | (excluded_key < proof.leaf.next_key);
    is_after_leaf & is_before_next
}

pub fn verify_insertion_proof(insertion_result: InsertionResult) -> bool {
    let og_leaf = Leaf {
        key: insertion_result.og_leaf_key,
        next_idx: insertion_result.og_leaf_next_idx,
        next_key: insertion_result.og_leaf_next_key,
        value: insertion_result.og_leaf_value
    };
    
    let og_proof = Proof {
        leaf_idx: insertion_result.og_leaf_idx,
        leaf: og_leaf,
        root: insertion_result.root_before,
        siblings: insertion_result.siblings_before
    };
    
    let new_leaf = Leaf {
        key: insertion_result.new_leaf_key,
        next_idx: 0,
        next_key: 0,
        value: insertion_result.new_leaf_value
    };
    
    let new_proof = Proof {
        leaf_idx: insertion_result.new_leaf_idx,
        leaf: new_leaf,
        root: insertion_result.root_after,
        siblings: insertion_result.siblings_after_new
    };
    
    verify_proof(og_proof) & verify_proof(new_proof)
}

pub fn insert_item(
    leaves: [Leaf; MAX_DEPTH],
    num_leaves: u32,
    new_key: u64,
    new_value: Field
) -> (InsertionResult, [Leaf; MAX_DEPTH], u32) {
    // Find insertion position to maintain sorted order
    let mut insert_idx = num_leaves; // Default to end
    let mut prev_idx = 0;
    
    // Find the correct position for insertion (without break)
    for i in 0..MAX_DEPTH {
        let i_u32 = i as u32;
        if i_u32 < num_leaves {
            let is_greater = leaves[i].key > new_key;
            let is_less_than_insert = i_u32 < insert_idx;
            if is_greater & is_less_than_insert {
                insert_idx = i_u32;
            }
            if i_u32 < insert_idx {
                prev_idx = i_u32;
            }
        }
    }
    
    let mut new_leaves = leaves;
    let new_leaf_idx = num_leaves;
    
    // Create new leaf
    let new_leaf = Leaf {
        key: new_key,
        next_idx: 0,
        next_key: 0,
        value: new_value
    };
    
    // Insert at the end for now (simplified approach)
    new_leaves[new_leaf_idx] = new_leaf;
    
    // Update previous leaf's next pointers if needed
    if prev_idx < num_leaves {
        new_leaves[prev_idx] = Leaf {
            key: leaves[prev_idx].key,
            next_idx: new_leaf_idx,
            next_key: new_key,
            value: leaves[prev_idx].value
        };
    }
    
    let new_count = num_leaves + 1;
    
    // Generate proofs
    let og_proof = generate_proof(leaves, num_leaves, prev_idx);
    let new_proof = generate_proof(new_leaves, new_count, new_leaf_idx);
    let updated_prev_proof = generate_proof(new_leaves, new_count, prev_idx);
    
    let result = InsertionResult {
        og_leaf_idx: og_proof.leaf_idx,
        og_leaf_key: og_proof.leaf.key,
        og_leaf_next_idx: og_proof.leaf.next_idx,
        og_leaf_next_key: og_proof.leaf.next_key,
        og_leaf_value: og_proof.leaf.value,
        new_leaf_idx: new_proof.leaf_idx,
        new_leaf_key: new_proof.leaf.key,
        new_leaf_value: new_proof.leaf.value,
        root_before: og_proof.root,
        root_after: new_proof.root,
        siblings_before: og_proof.siblings,
        siblings_after_og: updated_prev_proof.siblings,
        siblings_after_new: new_proof.siblings
    };
    
    (result, new_leaves, new_count)
}