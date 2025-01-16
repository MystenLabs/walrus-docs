// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::bls_tests;

use sui::bls12381::{Self, g1_to_uncompressed_g1};
use walrus::{
    bls_aggregate::{Self, BlsCommittee, new_bls_committee},
    messages,
    test_utils::{
        bls_aggregate_sigs,
        bls_min_pk_from_sk,
        bls_min_pk_sign,
        bls_secret_keys_for_testing,
        signers_to_bitmap
    }
};

#[test]
public fun test_check_aggregate() {
    let (committee, agg_sig, signers, message) = create_committee_and_cert(option::none());

    // Verify the aggregate signature
    committee.verify_certificate(
        &agg_sig,
        &signers,
        &message,
    );
}

#[test]
public fun test_check_aggregate_short_bitmap() {
    let (committee, agg_sig, signers, message) = create_committee_and_cert_short_bitmap(
        option::none(),
    );

    // Make sure that the signers bitmap is actually shorter than the maximum bitmap length.
    assert!(signers.length() < committee.n_members().divide_and_round_up(8));

    // Verify the aggregate signature
    committee.verify_certificate(
        &agg_sig,
        &signers,
        &message,
    );
}

#[test, expected_failure(abort_code = bls_aggregate::EInvalidBitmap)]
public fun test_check_aggregate_invalid_bitmap() {
    let (committee, agg_sig, mut signers, message) = create_committee_and_cert(option::none());

    // Add a byte to the signers bitmap to make it invalid.
    signers.push_back(0);

    // Verify the aggregate signature
    committee.verify_certificate(
        &agg_sig,
        &signers,
        &message,
    );
}

#[test, expected_failure(abort_code = bls_aggregate::ESigVerification)]
public fun test_add_members_error() {
    let (committee, agg_sig, signers, message) = create_committee_and_cert(option::none());

    // Add another signer to the set.
    let mut other_signers = vector::empty();
    // Add the 7th signer to the set.
    other_signers.push_back(signers[0] | 64u8);
    other_signers.push_back(signers[1]);

    // Verify the aggregate signature with the new, modified set of signers. Test fails here.
    committee.verify_certificate(
        &agg_sig,
        &other_signers,
        &message,
    );
}

#[test, expected_failure(abort_code = bls_aggregate::ESigVerification)]
public fun test_incorrect_signature_error() {
    let (committee, mut agg_sig, signers, message) = create_committee_and_cert(option::none());

    // Make the signature invalid by swapping the first two bytes.
    agg_sig.swap(0, 1);

    // Verify the aggregate signature with wrong signature. Test fails here.
    committee.verify_certificate(
        &agg_sig,
        &signers,
        &message,
    );
}

#[test, expected_failure(abort_code = bls_aggregate::ENotEnoughStake)]
public fun test_incorrect_stake_error() {
    // Committee has total weight 11 but only signatures from 6.
    let (committee, agg_sig, signers, message) = create_committee_and_cert(
        option::some(vector[1, 1, 1, 1, 1, 1, 1, 1, 1, 2]),
    );

    // Verify the aggregate signature with insufficient weight. Test fails here.
    committee.verify_certificate(
        &agg_sig,
        &signers,
        &message,
    );
}

#[test]
public fun test_cert_basic_correct() {
    let (committee, agg_sig, signers, message) = create_committee_and_cert(option::none());
    let _cert = committee.verify_quorum_in_epoch(agg_sig, signers, message).certify_blob_message();
}

#[test, expected_failure(abort_code = messages::EIncorrectEpoch)]
public fun test_cert_incorrect_epoch() {
    let (mut committee, agg_sig, signers, message) = create_committee_and_cert(option::none());
    committee.increment_epoch_for_testing();
    // Try to verify certificate with wrong epoch. Test fails here.
    let _cert = committee.verify_quorum_in_epoch(agg_sig, signers, message).certify_blob_message();
}

/// Returns a committee, a valid aggregate signature, the signers, and message that was signed.
///
/// The signers are keys 0, 1, 2, 3, 4, 7, 8 and the committee has 10 keys in total.
fun create_committee_and_cert(
    weights: Option<vector<u16>>,
): (BlsCommittee, vector<u8>, vector<u8>, vector<u8>) {
    // Create the aggregate sig for keys 0, 1, 2, 3, 4, 7, 8
    let signers = vector[0, 1, 2, 3, 4, 7, 8];
    create_committee_and_cert_with_signer_indices(weights, signers)
}

/// Returns a committee, a valid aggregate signature, the signers as a short bitmap,
/// and the message that was signed.
///
/// The signers are keys 0, 1, 2, 3, 4, 5, 6 and the committee has 10 keys in total.
fun create_committee_and_cert_short_bitmap(
    weights: Option<vector<u16>>,
): (BlsCommittee, vector<u8>, vector<u8>, vector<u8>) {
    // Create the aggregate sig for keys 0, 1, 2, 3, 4, 5, 6
    let signers = vector[0, 1, 2, 3, 4, 5, 6];
    create_committee_and_cert_with_signer_indices(weights, signers)
}

fun create_committee_and_cert_with_signer_indices(
    weights: Option<vector<u16>>,
    signers: vector<u16>,
): (BlsCommittee, vector<u8>, vector<u8>, vector<u8>) {
    let sks = bls_secret_keys_for_testing();
    let pks = sks.map_ref!(|sk| bls12381::g1_from_bytes(&bls_min_pk_from_sk(sk)));
    let weights = weights.get_with_default(vector[1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);
    let epoch = 5;

    let message = messages::certified_permanent_message_bytes(epoch, 0xABC);

    let mut sigs = vector[];
    signers.do!(|i| sigs.push_back(bls_min_pk_sign(&message, &sks[i as u64])));

    let signers_bitmap = signers_to_bitmap(&signers);

    let agg_sig = bls_aggregate_sigs(&sigs);

    // Make a new committee with equal weight
    let members = pks.zip_map!(
        weights,
        |pk, weight| bls_aggregate::new_bls_committee_member(
            g1_to_uncompressed_g1(&pk),
            weight,
            tx_context::dummy().fresh_object_address().to_id(),
        ),
    );
    let committee = new_bls_committee(
        epoch,
        members,
    );
    (committee, agg_sig, signers_bitmap, message)
}
