// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::invalid_tests;

use walrus::{epoch_parameters::epoch_params_for_testing, messages, system, test_utils};

const BLOB_ID: u256 = 0xC0FFEE;

#[test]
public fun test_invalid_blob_ok() {
    let epoch = 5;
    // Create a new committee
    let committee = test_utils::new_bls_committee_for_testing(epoch);

    let invalid_blob_message = messages::invalid_message_bytes(epoch, BLOB_ID);
    let signature = test_utils::bls_min_pk_sign(
        &invalid_blob_message,
        &test_utils::bls_sk_for_testing(),
    );

    let certified_message = committee.verify_quorum_in_epoch(
        signature,
        test_utils::signers_to_bitmap(&vector[0]),
        invalid_blob_message,
    );

    // Now check this is a invalid blob message
    let invalid_blob_msg = certified_message.invalid_blob_id_message();
    assert!(invalid_blob_msg.invalid_blob_id() == BLOB_ID);
}

#[test]
public fun test_invalidate_happy() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);

    1u32.range_do_eq!(5, |epoch| {
        let committee = test_utils::new_bls_committee_for_testing(epoch);
        let epoch_balance = system.advance_epoch(committee, &epoch_params_for_testing());
        let (_, values) = epoch_balance.into_keys_values();
        values.do!(|b| { b.destroy_for_testing(); });
    });

    // Create invalid blob message.
    let invalid_blob_message = messages::invalid_message_bytes(system.epoch(), BLOB_ID);
    let signature = test_utils::bls_min_pk_sign(
        &invalid_blob_message,
        &test_utils::bls_sk_for_testing(),
    );

    // Now check this is a invalid blob message
    let blob_id = system.invalidate_blob_id(
        signature,
        test_utils::signers_to_bitmap(&vector[0]),
        invalid_blob_message,
    );

    assert!(blob_id == BLOB_ID);

    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = messages::EIncorrectEpoch)]
public fun test_system_invalid_id_wrong_epoch() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);

    1u32.range_do_eq!(5, |epoch| {
        let committee = test_utils::new_bls_committee_for_testing(epoch);
        let epoch_balance = system.advance_epoch(committee, &epoch_params_for_testing());
        let (_, values) = epoch_balance.into_keys_values();
        values.do!(|b| { b.destroy_for_testing(); });
    });

    // Create invalid blob message for wrong epoch.
    let invalid_blob_message = messages::invalid_message_bytes(system.epoch() - 1, BLOB_ID);
    let signature = test_utils::bls_min_pk_sign(
        &invalid_blob_message,
        &test_utils::bls_sk_for_testing(),
    );

    // Now check this is a invalid blob message. Test fails here.
    let _blob_id = system.invalidate_blob_id(
        signature,
        test_utils::signers_to_bitmap(&vector[0]),
        invalid_blob_message,
    );

    abort
}
