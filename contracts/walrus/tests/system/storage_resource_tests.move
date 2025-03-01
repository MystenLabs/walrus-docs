// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::storage_resource_tests;

use std::unit_test::assert_eq;
use walrus::{
    epoch_parameters,
    storage_resource::{create_for_test, EInvalidEpoch, EIncompatibleAmount, EIncompatibleEpochs},
    system,
    test_utils
};

#[test]
public fun test_split_epoch() {
    let ctx = &mut tx_context::dummy();
    let storage_amount = 5_000_000;
    let mut storage = create_for_test(0, 10, storage_amount, ctx);
    let new_storage = storage.split_by_epoch(7, ctx);
    assert!(
        storage.start_epoch() == 0 && storage.end_epoch() == 7 &&
        new_storage.start_epoch() == 7 &&
        new_storage.end_epoch() == 10,
        0,
    );
    assert!(storage.size() == storage_amount && new_storage.size() == storage_amount, 0);
    storage.destroy();
    new_storage.destroy();
}

#[test]
public fun test_split_size() {
    let ctx = &mut tx_context::dummy();
    let mut storage = create_for_test(0, 10, 5_000_000, ctx);
    let new_storage = storage.split_by_size(1_000_000, ctx);
    assert!(
        storage.start_epoch() == 0 && storage.end_epoch() == 10 &&
        new_storage.start_epoch() == 0 &&
        new_storage.end_epoch() == 10,
        0,
    );
    assert!(storage.size() == 1_000_000 && new_storage.size() == 4_000_000, 0);
    storage.destroy();
    new_storage.destroy();
}

#[test, expected_failure(abort_code = EInvalidEpoch)]
public fun test_split_epoch_invalid_end() {
    let ctx = &mut tx_context::dummy();
    let mut storage = create_for_test(0, 10, 5_000_000, ctx);
    let _new_storage = storage.split_by_epoch(11, ctx);
    abort
}

#[test, expected_failure(abort_code = EInvalidEpoch)]
public fun test_split_epoch_invalid_start() {
    let ctx = &mut tx_context::dummy();
    let mut storage = create_for_test(1, 10, 5_000_000, ctx);
    let _new_storage = storage.split_by_epoch(0, ctx);
    abort
}

#[test]
public fun test_fuse_size() {
    let ctx = &mut tx_context::dummy();
    let mut first = create_for_test(0, 10, 1_000_000, ctx);
    let second = create_for_test(0, 10, 2_000_000, ctx);
    first.fuse(second);
    assert!(first.start_epoch() == 0 && first.end_epoch() == 10, 0);
    assert!(first.size() == 3_000_000, 0);
    first.destroy();
}

#[test]
public fun test_fuse_epochs() {
    let ctx = &mut tx_context::dummy();
    let mut first = create_for_test(0, 5, 1_000_000, ctx);
    let second = create_for_test(5, 10, 1_000_000, ctx);
    // list the `earlier` resource first
    first.fuse(second);
    assert!(first.start_epoch() == 0 && first.end_epoch() == 10, 0);
    assert!(first.size() == 1_000_000, 0);

    let mut second = create_for_test(10, 15, 1_000_000, ctx);
    // list the `latter` resource first
    second.fuse(first);
    assert!(second.start_epoch() == 0 && second.end_epoch() == 15, 0);
    assert!(second.size() == 1_000_000, 0);
    second.destroy();
}

#[test, expected_failure(abort_code = EIncompatibleAmount)]
public fun test_fuse_incompatible_size() {
    let ctx = &mut tx_context::dummy();
    let mut first = create_for_test(0, 5, 1_000_000, ctx);
    let second = create_for_test(5, 10, 2_000_000, ctx);
    first.fuse(second);
    abort
}

#[test, expected_failure(abort_code = EIncompatibleEpochs)]
public fun test_fuse_incompatible_epochs() {
    let ctx = &mut tx_context::dummy();
    let mut first = create_for_test(0, 6, 1_000_000, ctx);
    let second = create_for_test(5, 10, 1_000_000, ctx);
    first.fuse(second);
    abort
}

#[test]
fun storage_capacity_at_epochs() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let mut payment = test_utils::mint_frost(10_000_000_000, ctx);

    // initial state, no storage reserved
    assert_eq!(system.used_capacity_size(), 0);
    assert_eq!(system.total_capacity_size(), 1_000_000_000); // default value in tests

    // half of the available space for current and next epoch
    let storage = system.reserve_space(500_000_000, 2, &mut payment, ctx);

    assert_eq!(storage.end_epoch(), 2);
    assert_eq!(storage.size(), 500_000_000);
    assert_eq!(system.used_capacity_size(), 500_000_000);
    assert_eq!(system.inner().used_capacity_size_at_future_epoch(1), 500_000_000);
    assert_eq!(system.inner().used_capacity_size_at_future_epoch(2), 0);
    storage.destroy();

    // reserve more space for the current epoch
    let storage = system.reserve_space(500_000_000, 1, &mut payment, ctx);

    assert_eq!(storage.end_epoch(), 1);
    assert_eq!(storage.size(), 500_000_000);
    assert_eq!(system.used_capacity_size(), 1_000_000_000);
    assert_eq!(system.inner().used_capacity_size_at_future_epoch(1), 500_000_000); // E1
    assert_eq!(system.inner().used_capacity_size_at_future_epoch(2), 0);
    storage.destroy();

    // next epoch: 1
    let cmt = test_utils::new_bls_committee_for_testing(1);
    let (_, balances) = system
        .advance_epoch(cmt, &epoch_parameters::new(10_000_000_000, 5, 1))
        .into_keys_values();

    balances.do!(|b| _ = b.destroy_for_testing());

    // check that the capacity is updated
    assert_eq!(system.used_capacity_size(), 500_000_000);
    assert_eq!(system.total_capacity_size(), 10_000_000_000);
    assert_eq!(system.inner().used_capacity_size_at_future_epoch(1), 0);

    // next epoch: 2
    let cmt = test_utils::new_bls_committee_for_testing(2);
    let (_, balances) = system
        .advance_epoch(cmt, &epoch_parameters::new(10_000_000_000, 5, 1))
        .into_keys_values();

    balances.do!(|b| _ = b.destroy_for_testing());

    assert_eq!(system.used_capacity_size(), 0);
    assert_eq!(system.total_capacity_size(), 10_000_000_000);

    payment.burn_for_testing();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = walrus::system_state_inner::EStorageExceeded)]
fun exceed_storage_capacity() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let mut payment = test_utils::mint_frost(10_000_000_000, ctx);

    // initial state, no storage reserved
    assert_eq!(system.used_capacity_size(), 0);
    assert_eq!(system.total_capacity_size(), 1_000_000_000);

    // half of the available space for current and next epoch
    let _storage = system.reserve_space(1_000_000_001, 2, &mut payment, ctx);
    abort
}

#[test, expected_failure(abort_code = walrus::system_state_inner::EInvalidResourceSize)]
fun test_reserve_space_zero_size() {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let mut payment = test_utils::mint_frost(10_000_000_000, ctx);

    // half of the available space for current and next epoch
    let _storage = system.reserve_space(0, 2, &mut payment, ctx);
    abort
}
