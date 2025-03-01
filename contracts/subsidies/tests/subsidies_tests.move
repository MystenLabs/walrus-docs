// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module subsidies::subsidies_tests;

use subsidies::subsidies::{Self, Subsidies};
use sui::{coin::Coin, test_scenario as test};
use wal::wal::WAL;
use walrus::{
    blob::{Self, Blob},
    encoding,
    messages,
    storage_resource::Storage,
    system::{Self, System},
    test_utils::mint_frost
};

const RED_STUFF_RAPTOR: u8 = 0;

const ROOT_HASH: u256 = 0xABC;
const SIZE: u64 = 5_000_000;

const N_COINS: u64 = 1_000_000_000;

#[test]
fun test_new() {
    let user = @0xa11ce;
    let mut test = test::begin(user);
    let ctx = test.ctx();

    let package_id = object::new(ctx);
    let package_id_inner = object::uid_to_inner(&package_id);
    let admin_cap = subsidies::new(package_id_inner, ctx);

    test.next_tx(user);
    let subsidies = test.take_shared<Subsidies>();

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == 0);
    assert!(admin_cap.admin_cap_subsidies_id() == object::id(&subsidies));

    admin_cap.destroy_admin_cap();
    subsidies.destroy_subsidies();
    object::delete(package_id);
    test.end();
}

#[test]
fun test_new_with_initial_rates_and_funds_public_fn() {
    let user = @0xa11ce;
    let mut test = test::begin(user);
    let ctx = test.ctx();

    let initial_buyer_subsidy_rate: u16 = 5_00; // 5%
    let initial_storage_node_subsidy_rate: u16 = 10_00; // 10%
    let initial_funds_value = 1_000_000;
    let package_id = object::new(ctx);

    let admin_cap = subsidies::new_with_initial_rates_and_funds(
        package_id.to_inner(),
        initial_buyer_subsidy_rate,
        initial_storage_node_subsidy_rate,
        mint_frost(initial_funds_value, ctx),
        ctx,
    );

    test.next_tx(user);
    let subsidies = test.take_shared<Subsidies>();

    assert!(subsidies.buyer_subsidy_rate() == initial_buyer_subsidy_rate);
    assert!(subsidies.system_subsidy_rate() == initial_storage_node_subsidy_rate);
    assert!(subsidies.subsidy_pool_value() == initial_funds_value);
    assert!(admin_cap.admin_cap_subsidies_id() == object::id(&subsidies));

    admin_cap.destroy_admin_cap();
    subsidies.destroy_subsidies();
    object::delete(package_id);

    test.end();
}

#[test]
fun test_new_subsidy_object(): System {
    let (system, subsidies, admin_cap) = setup_system_and_subsidies_no_funds();

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);

    system
}

#[test]
fun test_new_subsidy_object_with_initial_rates_and_funds() {
    let initial_buyer_subsidy_rate: u16 = 5_00; // 5%
    let initial_storage_node_subsidy_rate: u16 = 10_00; // 10%
    let initial_funds_value = 1_000_000;

    let ctx = &mut tx_context::dummy();
    let (subsidies, admin_cap) = subsidies::new_with_initial_rates_and_funds_for_testing(
        initial_buyer_subsidy_rate,
        initial_storage_node_subsidy_rate,
        mint_frost(initial_funds_value, ctx),
        ctx,
    );

    assert!(subsidies.buyer_subsidy_rate() == initial_buyer_subsidy_rate);
    assert!(subsidies.system_subsidy_rate() == initial_storage_node_subsidy_rate);
    assert!(subsidies.subsidy_pool_value() == initial_funds_value);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
}

#[test]
fun test_add_funds_to_subsidy_pool(): System {
    let (system, mut subsidies, admin_cap) = setup_system_and_subsidies_no_funds();
    let initial_funds_value = 1_000_000;
    let ctx = &mut tx_context::dummy();

    subsidies.add_funds(mint_frost(initial_funds_value, ctx));

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == initial_funds_value);

    subsidies.add_funds(mint_frost(initial_funds_value, ctx));

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == (initial_funds_value + initial_funds_value));

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);

    system
}

#[test]
fun test_set_buyer_subsidy_rate() {
    let ctx = &mut tx_context::dummy();
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == 0);

    let buyer_subsidy_rate: u16 = 5_00; // 5%
    subsidies.set_buyer_subsidy_rate(&admin_cap, buyer_subsidy_rate);

    assert!(subsidies.buyer_subsidy_rate() == buyer_subsidy_rate);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
}

#[test]
fun test_set_system_subsidy_rate() {
    let ctx = &mut tx_context::dummy();
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == 0);
    assert!(subsidies.subsidy_pool_value() == 0);

    let storage_node_subsidy_rate: u16 = 10_00; // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, storage_node_subsidy_rate);

    assert!(subsidies.buyer_subsidy_rate() == 0);
    assert!(subsidies.system_subsidy_rate() == storage_node_subsidy_rate);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
}

#[test, expected_failure(abort_code = subsidies::EInvalidSubsidyRate)]
fun test_set_buyer_subsidy_rate_invalid() {
    let ctx = &mut tx_context::dummy();
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);

    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_001);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
}

#[test, expected_failure(abort_code = subsidies::EInvalidSubsidyRate)]
fun test_set_system_subsidy_rate_invalid() {
    let ctx = &mut tx_context::dummy();
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);

    subsidies.set_system_subsidy_rate(&admin_cap, 10_001);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
}

#[test]
fun test_extend_blob_no_funds_no_subsidies(): (System, Coin<WAL>, Blob) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let mut payment = mint_frost(1000, ctx);

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());
    // Set certify
    blob.certify_with_certified_msg_for_testing(system.epoch(), certify_message);
    // Assert certified
    assert!(blob.certified_epoch().is_some());
    let initial_blob_storage_end = blob.storage().end_epoch();

    subsidies.extend_blob(&mut system, &mut blob, 3, &mut payment, ctx);

    assert!(payment.value() == 625);
    // No subsidies applied, the pool should remain at 0
    assert!(subsidies.subsidy_pool_value() == 0);
    // Blob storage end should increase by 3 epochs
    assert!(blob.storage().end_epoch() == initial_blob_storage_end + 3);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, blob)
}

#[test]
fun test_extend_blob_no_funds_buyer_subsidies(): (System, Coin<WAL>, Blob) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    let mut payment = mint_frost(1000, ctx);

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());
    // Set certify
    blob.certify_with_certified_msg_for_testing(system.epoch(), certify_message);
    // Assert certified
    assert!(blob.certified_epoch().is_some());
    let initial_blob_storage_end = blob.storage().end_epoch();

    subsidies.extend_blob(&mut system, &mut blob, 3, &mut payment, ctx);

    assert!(payment.value() == 625);
    assert!(subsidies.subsidy_pool_value() == 0);
    assert!(blob.storage().end_epoch() == initial_blob_storage_end + 3);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, blob)
}

#[test]
fun test_extend_blob_no_funds_storage_node_subsidies(): (System, Coin<WAL>, Blob) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%
    let mut payment = mint_frost(1000, ctx);

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());
    // Set certify
    blob.certify_with_certified_msg_for_testing(system.epoch(), certify_message);
    // Assert certified
    assert!(blob.certified_epoch().is_some());
    let initial_blob_storage_end = blob.storage().end_epoch();

    subsidies.extend_blob(&mut system, &mut blob, 3, &mut payment, ctx);

    assert!(payment.value() == 625);
    assert!(subsidies.subsidy_pool_value() == 0);
    assert!(blob.storage().end_epoch() == initial_blob_storage_end + 3);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, blob)
}

#[test]
fun test_extend_blob_funds_with_subsidies(): (System, Coin<WAL>, Blob) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 1_000_000;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);
    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());
    // Set certify
    blob.certify_with_certified_msg_for_testing(system.epoch(), certify_message);
    // Assert certified
    assert!(blob.certified_epoch().is_some());
    let initial_blob_storage_end = blob.storage().end_epoch();

    subsidies.extend_blob(&mut system, &mut blob, 3, &mut payment, ctx);

    assert!(blob.storage().end_epoch() == initial_blob_storage_end + 3);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);

    (system, payment, blob)
}

#[test]
fun test_reserve_space_no_funds_no_subsidies(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 925);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_reserve_space_no_funds_buyer_subsidies(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 925);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_reserve_space_no_funds_storage_node_subsidies(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 925);
    assert!(subsidies.subsidy_pool_value() == 0);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_reserve_space_funds_with_subsidies(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 1_000_000;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 932);
    assert!(subsidies.subsidy_pool_value() == 999_986);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_reserve_space_funds_with_subsidies_full_pool_consumption(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 100;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 932);
    assert!(subsidies.subsidy_pool_value() == 86);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_reserve_space_insufficient_funds_with_subsidies(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 100;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 932);
    assert!(subsidies.subsidy_pool_value() == 86);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

// === Helper functions ===

fun setup_system_and_subsidies_no_funds(): (System, subsidies::Subsidies, subsidies::AdminCap) {
    let ctx = &mut tx_context::dummy();
    let system = system::new_for_testing(ctx);
    let (subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    (system, subsidies, admin_cap)
}

fun get_storage_resource(system: &mut System, unencoded_size: u64, epochs_ahead: u32): Storage {
    let ctx = &mut tx_context::dummy();
    let mut fake_coin = mint_frost(N_COINS, ctx);
    let storage_size = encoding::encoded_blob_length(
        unencoded_size,
        RED_STUFF_RAPTOR,
        system.n_shards(),
    );
    let storage = system.reserve_space(
        storage_size,
        epochs_ahead,
        &mut fake_coin,
        ctx,
    );
    fake_coin.burn_for_testing();
    storage
}

#[test]
fun test_extend_blob_funds_with_subsidies_full_pool_consumption(): (System, Coin<WAL>, Blob) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 150;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);
    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());
    // Set certify
    blob.certify_with_certified_msg_for_testing(system.epoch(), certify_message);
    // Assert certified
    assert!(blob.certified_epoch().is_some());
    let initial_blob_storage_end = blob.storage().end_epoch();

    subsidies.extend_blob(&mut system, &mut blob, 3, &mut payment, ctx);

    assert!(blob.storage().end_epoch() == initial_blob_storage_end + 3);
    assert!(subsidies.subsidy_pool_value() == 76);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);

    (system, payment, blob)
}

#[test]
fun test_subsidies_with_zero_buyer_rate(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 1_000_000;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 0); // 0%
    subsidies.set_system_subsidy_rate(&admin_cap, 10_00); // 10%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 925);
    assert!(subsidies.subsidy_pool_value() == 999_993);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

#[test]
fun test_subsidies_with_zero_system_rate(): (System, Coin<WAL>, Storage) {
    let ctx = &mut tx_context::dummy();
    let mut system = system::new_for_testing(ctx);
    let (mut subsidies, admin_cap) = subsidies::new_for_testing(ctx);
    let initial_funds_value = 1_000_000;
    subsidies.add_funds(mint_frost(initial_funds_value, ctx));
    subsidies.set_buyer_subsidy_rate(&admin_cap, 10_00); // 10%
    subsidies.set_system_subsidy_rate(&admin_cap, 0); // 0%

    let mut payment = mint_frost(1000, ctx);

    let storage = subsidies.reserve_space(&mut system, SIZE, 3, &mut payment, ctx);

    assert!(payment.value() == 932);
    assert!(subsidies.subsidy_pool_value() == 999_993);

    subsidies::destroy_admin_cap(admin_cap);
    subsidies::destroy_subsidies(subsidies);
    (system, payment, storage)
}

fun register_default_blob(system: &mut System, storage: Storage, deletable: bool): Blob {
    let ctx = &mut tx_context::dummy();
    let mut fake_coin = mint_frost(N_COINS, ctx);
    // Register a Blob
    let blob_id = blob::derive_blob_id(ROOT_HASH, RED_STUFF_RAPTOR, SIZE);
    let blob = system.register_blob(
        storage,
        blob_id,
        ROOT_HASH,
        SIZE,
        RED_STUFF_RAPTOR,
        deletable,
        &mut fake_coin,
        ctx,
    );

    fake_coin.burn_for_testing();
    blob
}
