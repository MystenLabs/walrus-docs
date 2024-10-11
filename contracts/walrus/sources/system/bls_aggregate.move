// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::bls_aggregate;

use sui::bls12381::{Self, bls12381_min_pk_verify, G1};
use sui::group_ops::{Self, Element};
use sui::vec_map::{Self, VecMap};
use walrus::messages::{Self, CertifiedMessage};

// Error codes
const ETotalMemberOrder: u64 = 0;
const ESigVerification: u64 = 1;
const ENotEnoughStake: u64 = 2;
const EIncorrectCommittee: u64 = 3;

public struct BlsCommitteeMember has store, copy, drop {
    public_key: Element<G1>,
    weight: u16,
    node_id: ID,
}

/// This represents a BLS signing committee for a given epoch.
public struct BlsCommittee has store, copy, drop {
    /// A vector of committee members
    members: vector<BlsCommitteeMember>,
    /// The total number of shards held by the committee
    n_shards: u16,
    /// The epoch in which the committee is active.
    epoch: u32,
}

/// Constructor for committee.
public(package) fun new_bls_committee(
    epoch: u32,
    members: vector<BlsCommitteeMember>,
): BlsCommittee {
    // Compute the total number of shards
    let mut n_shards = 0;
    members.do_ref!(|member| {
        let weight = member.weight;
        assert!(weight > 0, EIncorrectCommittee);
        n_shards = n_shards + weight;
    });

    BlsCommittee { members, n_shards, epoch }
}

/// Constructor for committee member.
public(package) fun new_bls_committee_member(
    public_key: Element<G1>,
    weight: u16,
    node_id: ID,
): BlsCommitteeMember {
    BlsCommitteeMember {
        public_key,
        weight,
        node_id,
    }
}

// === Accessors for BlsCommitteeMember ===

/// Get the node id of the committee member.
public(package) fun node_id(self: &BlsCommitteeMember): sui::object::ID {
    self.node_id
}

// === Accessors for BlsCommittee ===

/// Get the epoch of the committee.
public(package) fun epoch(self: &BlsCommittee): u32 {
    self.epoch
}

/// Returns the number of shards held by the committee.
public(package) fun n_shards(self: &BlsCommittee): u16 {
    self.n_shards
}

/// Returns the member at given index
public(package) fun get_idx(self: &BlsCommittee, idx: u64): &BlsCommitteeMember {
    self.members.borrow(idx)
}

/// Checks if the committee contains a given node.
public(package) fun contains(self: &BlsCommittee, node_id: &ID): bool {
    self.find_index(node_id).is_some()
}

/// Returns the member weight if it is part of the committee or 0 otherwise
public(package) fun get_member_weight(self: &BlsCommittee, node_id: &ID): u16 {
    self.find_index(node_id).and!(|idx| {
        let member = &self.members[idx];
        option::some(member.weight)
    }).get_with_default(0)
}

/// Finds the index of the member by node_id
public(package) fun find_index(self: &BlsCommittee, node_id: &ID): std::option::Option<u64> {
    self.members.find_index!(|member| &member.node_id == node_id)
}

/// Returns the members of the committee with their weights.
public(package) fun to_vec_map(self: &BlsCommittee): VecMap<ID, u16> {
    let mut result = vec_map::empty();
    self.members.do_ref!(|member| {
        result.insert(member.node_id, member.weight)
    });
    result
}

/// Verifies that a message is signed by a quorum of the members of a committee.
///
/// The signers are listed as indices into the `members` vector of the committee
/// in increasing
/// order and with no repetitions. The total weight of the signers (i.e. total
/// number of shards)
/// is returned, but if a quorum is not reached the function aborts with an
/// error.
public(package) fun verify_quorum_in_epoch(
    self: &BlsCommittee,
    signature: vector<u8>,
    signers: vector<u16>,
    message: vector<u8>,
): CertifiedMessage {
    let stake_support = self.verify_certificate(
        &signature,
        &signers,
        &message,
    );

    messages::new_certified_message(message, self.epoch, stake_support)
}

/// Returns true if the weight is more than the aggregate weight of quorum members of a committee.
public(package) fun verify_quorum(self: &BlsCommittee, weight: u16): bool {
    3 * (weight as u64) >= 2 * (self.n_shards as u64) + 1
}

/// Verify an aggregate BLS signature is a certificate in the epoch, and return
/// the type of
/// certificate and the bytes certified. The `signers` vector is an increasing
/// list of indexes
/// into the `members` vector of the committee. If there is a certificate, the
/// function
/// returns the total stake. Otherwise, it aborts.
public(package) fun verify_certificate(
    self: &BlsCommittee,
    signature: &vector<u8>,
    signers: &vector<u16>,
    message: &vector<u8>,
): u16 {
    // Use the signers flags to construct the key and the weights.

    // Lower bound for the next `member_index` to ensure they are monotonically
    // increasing
    let mut min_next_member_index = 0;
    let mut aggregate_key = bls12381::g1_identity();
    let mut aggregate_weight = 0;

    signers.do_ref!(|member_index| {
        let member_index = *member_index as u64;
        assert!(member_index >= min_next_member_index, ETotalMemberOrder);
        min_next_member_index = member_index + 1;

        // Bounds check happens here
        let member = &self.members[member_index];
        let key = &member.public_key;
        let weight = member.weight;

        aggregate_key = bls12381::g1_add(&aggregate_key, key);
        aggregate_weight = aggregate_weight + weight;
    });

    // The expression below is the solution to the inequality:
    // n_shards = 3 f + 1
    // stake >= 2f + 1
    assert!(verify_quorum(self, aggregate_weight), ENotEnoughStake);

    // Verify the signature
    let pub_key_bytes = group_ops::bytes(&aggregate_key);
    assert!(
        bls12381_min_pk_verify(
            signature,
            pub_key_bytes,
            message,
        ),
        ESigVerification,
    );

    (aggregate_weight as u16)
}

#[test_only]
/// Increments the committee epoch by one.
public fun increment_epoch_for_testing(self: &mut BlsCommittee) {
    self.epoch = self.epoch + 1;
}
