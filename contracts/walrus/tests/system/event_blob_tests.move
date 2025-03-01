// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::event_blob_tests;

use walrus::{
    blob,
    storage_node,
    system::{Self, System},
    system_state_inner,
    test_node::{test_nodes, TestStorageNode}
};

const RED_STUFF_RAPTOR: u8 = 0;

const ROOT_HASH: u256 = 0xABC;
const SIZE: u64 = 5_000_000;

#[test]
public fun test_event_blob_certify_happy_path() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    // Total of 10 nodes all with equal weights
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);
    let blob_id = blob::derive_blob_id(ROOT_HASH, RED_STUFF_RAPTOR, SIZE);
    let mut index = 0;
    while (index < 10) {
        system.certify_event_blob(
            nodes.borrow_mut(index).cap_mut(),
            blob_id,
            ROOT_HASH,
            SIZE,
            RED_STUFF_RAPTOR,
            100,
            0,
            ctx,
        );
        let state = system.inner().event_blob_certification_state();
        if (index < 6) {
            assert!(state.get_latest_certified_checkpoint_sequence_number().is_none());
        } else {
            // 7th node signing the blob triggers blob certification
            assert!(state.get_latest_certified_checkpoint_sequence_number().is_some());
        };
        index = index + 1
    };
    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing()
}

#[test, expected_failure(abort_code = system_state_inner::ERepeatedAttestation)]
public fun test_event_blob_certify_repeated_attestation() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    // Total of 10 nodes
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);
    let blob_id = blob::derive_blob_id(ROOT_HASH, RED_STUFF_RAPTOR, SIZE);

    system.certify_event_blob(
        nodes.borrow_mut(0).cap_mut(),
        blob_id,
        ROOT_HASH,
        SIZE,
        RED_STUFF_RAPTOR,
        100,
        0,
        ctx,
    );

    // Second attestation should fail
    system.certify_event_blob(
        nodes.borrow_mut(0).cap_mut(),
        blob_id,
        ROOT_HASH,
        SIZE,
        RED_STUFF_RAPTOR,
        100,
        0,
        ctx,
    );

    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = system_state_inner::EIncorrectAttestation)]
public fun test_multiple_event_blobs_in_flight() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    // Total of 10 nodes
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);
    let blob1 = blob::derive_blob_id(0xabc, RED_STUFF_RAPTOR, SIZE);
    let blob2 = blob::derive_blob_id(0xdef, RED_STUFF_RAPTOR, SIZE);

    let mut index = 0;
    while (index < 6) {
        system.certify_event_blob(
            nodes.borrow_mut(index).cap_mut(),
            blob1,
            0xabc,
            SIZE,
            RED_STUFF_RAPTOR,
            100,
            0,
            ctx,
        );
        system.certify_event_blob(
            nodes.borrow_mut(index).cap_mut(),
            blob2,
            0xdef,
            SIZE,
            RED_STUFF_RAPTOR,
            200,
            0,
            ctx,
        );
        let state = system.inner().event_blob_certification_state();
        assert!(state.get_latest_certified_checkpoint_sequence_number().is_none());
        index = index + 1
    };
    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing();
}

#[test]
public fun test_event_blob_certify_change_epoch() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    // Total of 10 nodes
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);
    let blob_id = blob::derive_blob_id(ROOT_HASH, RED_STUFF_RAPTOR, SIZE);
    let mut index = 0;
    while (index < 6) {
        system.certify_event_blob(
            nodes.borrow_mut(index).cap_mut(),
            blob_id,
            ROOT_HASH,
            SIZE,
            RED_STUFF_RAPTOR,
            100,
            0,
            ctx,
        );
        let state = system.inner().event_blob_certification_state();
        assert!(state.get_latest_certified_checkpoint_sequence_number().is_none());
        index = index + 1
    };
    // increment epoch
    let mut new_committee = *system.committee();
    new_committee.increment_epoch_for_testing();
    let (_, balances) = system
        .advance_epoch(new_committee, &walrus::epoch_parameters::epoch_params_for_testing())
        .into_keys_values();

    balances.do!(|b| { b.destroy_for_testing(); });
    // 7th node attesting is not going to certify the blob as all other nodes
    // attested
    // the blob in previous epoch
    system.certify_event_blob(
        nodes.borrow_mut(index).cap_mut(),
        blob_id,
        ROOT_HASH,
        SIZE,
        RED_STUFF_RAPTOR,
        100,
        1,
        ctx,
    );
    let state = system.inner().event_blob_certification_state();
    assert!(state.get_latest_certified_checkpoint_sequence_number().is_none());
    index = 0;
    // All nodes sign the blob in current epoch
    while (index < 10) {
        // 7th node already attested
        if (index == 6) {
            index = index + 1;
            continue
        };
        system.certify_event_blob(
            nodes.borrow_mut(index).cap_mut(),
            blob_id,
            ROOT_HASH,
            SIZE,
            RED_STUFF_RAPTOR,
            100,
            1,
            ctx,
        );
        let state = system.inner().event_blob_certification_state();
        if (index < 5) {
            assert!(state.get_latest_certified_checkpoint_sequence_number().is_none());
        } else {
            assert!(state.get_latest_certified_checkpoint_sequence_number().is_some());
        };
        index = index + 1
    };
    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing();
}

#[test]
public fun test_certify_invalid_blob_id() {
    // Setup
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);

    // Create a constant bad blob ID that will be used throughout the test
    let bad_blob_id = blob::derive_blob_id(0xbeef, RED_STUFF_RAPTOR, SIZE);

    // Test multiple rounds of certification
    let mut i: u256 = 0;
    while (i < 30) {
        // First, get 9 nodes to certify a valid blob
        let good_blob_id = blob::derive_blob_id(i, RED_STUFF_RAPTOR, SIZE);
        let good_checkpoint = 100 * (i as u64);

        // Get signatures from first 9 nodes
        let mut index = 0;
        while (index < 9) {
            system.certify_event_blob(
                nodes.borrow_mut(index).cap_mut(),
                good_blob_id,
                i,
                SIZE,
                RED_STUFF_RAPTOR,
                good_checkpoint,
                0,
                ctx,
            );
            index = index + 1
        };

        // Verify the good blob was certified
        let state = system.inner().event_blob_certification_state();
        assert!(
            state.get_latest_certified_checkpoint_sequence_number() ==
            option::some(good_checkpoint
        ),
        );

        // Now try to get the 10th node to certify an invalid blob
        let bad_checkpoint = good_checkpoint + 1;
        system.certify_event_blob(
            nodes.borrow_mut(9).cap_mut(),
            bad_blob_id,
            0xbeef,
            SIZE,
            RED_STUFF_RAPTOR,
            bad_checkpoint,
            0,
            ctx,
        );

        // Verify the bad blob didn't affect the certification state
        let state = system.inner().event_blob_certification_state();
        assert!(
            state.get_latest_certified_checkpoint_sequence_number() ==
            option::some(good_checkpoint),
        );

        i = i + 1
    };
    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing();
}

#[test]
public fun test_block_blob_events() {
    let ctx = &mut tx_context::dummy();
    // Initialize system with 10 nodes
    let mut system = system::new_for_testing_with_multiple_members(ctx);
    assert!(system.committee().to_vec_map().size() == 10);
    let mut nodes = test_nodes();
    set_storage_node_caps(&system, &mut nodes, ctx);

    let mut i: u256 = 0;
    while (i < 30) {
        // Derive a good blob ID and certify it
        let good_blob_id = blob::derive_blob_id(i as u256, RED_STUFF_RAPTOR, SIZE);
        let good_cp = 100 * (i as u64);
        let mut index = 0;
        while (index < 9) {
            system.certify_event_blob(
                nodes.borrow_mut(index).cap_mut(),
                good_blob_id,
                i as u256,
                SIZE,
                RED_STUFF_RAPTOR,
                good_cp,
                0,
                ctx,
            );
            index = index + 1;
        };

        let state = system.inner().event_blob_certification_state();
        assert!(state.get_latest_certified_checkpoint_sequence_number() == option::some(good_cp));

        // Derive a bad blob ID and attempt to certify it
        let hash = 2000 * (i as u256);
        let bad_blob_id = blob::derive_blob_id(hash, RED_STUFF_RAPTOR, SIZE);
        let bad_cp = 100 * (i as u64) + 1;

        // Unique blob ID per call to fill up aggregate_weight_per_blob
        system.certify_event_blob(
            nodes.borrow_mut(9).cap_mut(),
            bad_blob_id,
            hash,
            SIZE,
            RED_STUFF_RAPTOR,
            bad_cp,
            0,
            ctx,
        );

        let state = system.inner().event_blob_certification_state();
        // Ensure no more than one blob is being tracked
        assert!(state.get_num_tracked_blobs() <= 1);
        i = i + 1;
    };
    nodes.destroy!(|node| node.destroy());
    system.destroy_for_testing();
}

// === Helper functions ===

fun set_storage_node_caps(
    system: &System,
    nodes: &mut vector<TestStorageNode>,
    ctx: &mut TxContext,
) {
    let (node_ids, _values) = system.committee().to_vec_map().into_keys_values();
    let mut index = 0;
    node_ids.do!(|node_id| {
        let storage_cap = storage_node::new_cap(node_id, ctx);
        nodes[index].set_storage_node_cap(storage_cap);
        index = index + 1;
    });
}
