// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::bls_aggregate;

use sui::{
    bls12381::{Self, bls12381_min_pk_verify, G1, UncompressedG1},
    group_ops::{Self, Element},
    vec_map::{Self, VecMap}
};
use walrus::messages::{Self, CertifiedMessage};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The signers bitmap is invalid.
const EInvalidBitmap: u64 = 0;
/// The signature is invalid.
const ESigVerification: u64 = 1;
/// The certificate does not have enough stake support.
const ENotEnoughStake: u64 = 2;
/// The committee has members with a zero weight.
const EIncorrectCommittee: u64 = 3;

public struct BlsCommitteeMember has copy, drop, store {
    public_key: Element<UncompressedG1>,
    weight: u16,
    node_id: ID,
}

/// This represents a BLS signing committee for a given epoch.
public struct BlsCommittee has copy, drop, store {
    /// A vector of committee members
    members: vector<BlsCommitteeMember>,
    /// The total number of shards held by the committee
    n_shards: u16,
    /// The epoch in which the committee is active.
    epoch: u32,
    /// The aggregation of public keys for all members of the committee
    total_aggregated_key: Element<G1>,
}

/// The type of weight verification to perform.
public enum RequiredWeight {
    /// Verify that the signers form a quorum.
    Quorum,
    /// Verify that the signers include at least one correct node.
    OneCorrectNode,
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

    // Compute the total aggregated key, e.g. the sum of all public keys in the committee.
    let total_aggregated_key = bls12381::uncompressed_g1_to_g1(
        &bls12381::uncompressed_g1_sum(
            &members.map!(|member| member.public_key),
        ),
    );

    BlsCommittee { members, n_shards, epoch, total_aggregated_key }
}

/// Constructor for committee member.
public(package) fun new_bls_committee_member(
    public_key: Element<UncompressedG1>,
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
public(package) fun node_id(self: &BlsCommitteeMember): ID {
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

/// Returns the number of members in the committee.
public(package) fun n_members(self: &BlsCommittee): u64 {
    self.members.length()
}

/// Returns the member at given index
public(package) fun get_idx(self: &BlsCommittee, idx: u64): &BlsCommitteeMember {
    &self.members[idx]
}

/// Checks if the committee contains a given node.
public(package) fun contains(self: &BlsCommittee, node_id: &ID): bool {
    self.find_index(node_id).is_some()
}

/// Returns the member weight if it is part of the committee or 0 otherwise
public(package) fun get_member_weight(self: &BlsCommittee, node_id: &ID): u16 {
    self.find_index(node_id).map!(|idx| self.members[idx].weight).destroy_or!(0)
}

/// Finds the index of the member by node_id
public(package) fun find_index(self: &BlsCommittee, node_id: &ID): Option<u64> {
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
/// The signers are given as a bitmap for the indices into the `members` vector of
/// the committee.
///
/// If the signers form a quorum and the signature is valid, the function returns
/// a new `CertifiedMessage` with the message, the epoch, and the total stake of
/// the signers. Otherwise, it aborts with an error.
public(package) fun verify_quorum_in_epoch(
    self: &BlsCommittee,
    signature: vector<u8>,
    signers_bitmap: vector<u8>,
    message: vector<u8>,
): CertifiedMessage {
    let stake_support = self.verify_certificate_and_weight(
        &signature,
        &signers_bitmap,
        &message,
        RequiredWeight::Quorum,
    );

    messages::new_certified_message(message, self.epoch, stake_support)
}

/// Returns true if the weight is more than the aggregate weight of quorum members of a committee.
public(package) fun is_quorum(self: &BlsCommittee, weight: u16): bool {
    3 * (weight as u64) >= 2 * (self.n_shards as u64) + 1
}

/// Verifies that a message is signed by at least one correct node of a committee.
///
/// The signers are given as a bitmap for the indices into the `members` vector of
/// the committee.
/// If the signers include at least one correct node and the signature is valid,
/// the function returns a new `CertifiedMessage` with the message, the epoch,
/// and the total stake of the signers. Otherwise, it aborts with an error.
public(package) fun verify_one_correct_node_in_epoch(
    self: &BlsCommittee,
    signature: vector<u8>,
    signers_bitmap: vector<u8>,
    message: vector<u8>,
): CertifiedMessage {
    let stake_support = self.verify_certificate_and_weight(
        &signature,
        &signers_bitmap,
        &message,
        RequiredWeight::OneCorrectNode,
    );

    messages::new_certified_message(message, self.epoch, stake_support)
}

/// Returns true if the weight is enough to ensure that at least one honest node contributed.
public(package) fun includes_one_correct_node(self: &BlsCommittee, weight: u16): bool {
    3 * (weight as u64) >= self.n_shards as u64 + 1
}

/// Verify an aggregate BLS signature is a certificate in the epoch, and return
/// the total stake of the signers.
/// The `signers_bitmap` is a bitmap of the indices of the signers in the committee.
/// The `weight_verification_type` is the type of weight verification to perform,
/// either check that the signers forms a quorum or includes at least one correct node.
/// If there is a certificate, the function returns the total stake. Otherwise, it aborts.
fun verify_certificate_and_weight(
    self: &BlsCommittee,
    signature: &vector<u8>,
    signers_bitmap: &vector<u8>,
    message: &vector<u8>,
    required_weight: RequiredWeight,
): u16 {
    // Use the signers_bitmap to construct the key and the weights.

    let mut non_signer_aggregate_weight = 0;
    let mut non_signer_public_keys: vector<Element<UncompressedG1>> = vector::empty();
    let mut offset: u64 = 0;
    let n_members = self.n_members();
    let max_bitmap_len_bytes = n_members.divide_and_round_up(8);

    // The signers bitmap must not be longer than necessary to hold all members.
    // It may be shorter, in which case the excluded members are treated as non-signers.
    assert!(signers_bitmap.length() <= max_bitmap_len_bytes, EInvalidBitmap);

    // Iterate over the signers bitmap and check if each member is a signer.
    max_bitmap_len_bytes.do!(|i| {
        // Get the current byte or 0 if we've reached the end of the bitmap.
        let byte = if (i < signers_bitmap.length()) {
            signers_bitmap[i]
        } else {
            0
        };

        (8u8).do!(|i| {
            let index = offset + (i as u64);
            let is_signer = (byte >> i) & 1 == 1;

            // If the index is out of bounds, the bit must be 0 to ensure
            // uniqueness of the signers_bitmap.
            if (index >= n_members) {
                assert!(!is_signer, EInvalidBitmap);
                return
            };

            // There will be fewer non-signers than signers, so we handle
            // non-signers here.
            if (!is_signer) {
                let member = self.members[index];
                non_signer_aggregate_weight = non_signer_aggregate_weight + member.weight;
                non_signer_public_keys.push_back(member.public_key);
            };
        });
        offset = offset + 8;
    });

    // Compute the aggregate weight as the difference between the total number of shards
    // and the total weight of the non-signers.
    let aggregate_weight = self.n_shards - non_signer_aggregate_weight;

    // Check if the aggregate weight is enough to satisfy the required weight.
    match (required_weight) {
        RequiredWeight::Quorum => assert!(self.is_quorum(aggregate_weight), ENotEnoughStake),
        RequiredWeight::OneCorrectNode => assert!(
            self.includes_one_correct_node(aggregate_weight),
            ENotEnoughStake,
        ),
    };

    // Compute the aggregate public key as the difference between the total
    // aggregated key and the sum of the non-signer public keys.
    let aggregate_key = bls12381::g1_sub(
        &self.total_aggregated_key,
        &bls12381::uncompressed_g1_to_g1(
            &bls12381::uncompressed_g1_sum(&non_signer_public_keys),
        ),
    );

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

#[test_only]
public fun verify_certificate(
    self: &BlsCommittee,
    signature: &vector<u8>,
    signers_bitmap: &vector<u8>,
    message: &vector<u8>,
): u16 {
    self.verify_certificate_and_weight(signature, signers_bitmap, message, RequiredWeight::Quorum)
}
