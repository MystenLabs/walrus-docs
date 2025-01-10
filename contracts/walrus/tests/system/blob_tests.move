// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::blob_tests;

use sui::bcs;
use walrus::{
    blob::{Self, Blob},
    encoding,
    epoch_parameters::epoch_params_for_testing,
    messages,
    metadata,
    storage_resource::{Self, split_by_epoch, destroy, Storage},
    system::{Self, System},
    system_state_inner,
    test_utils::{Self, bls_min_pk_sign, signers_to_bitmap}
};

const RED_STUFF: u8 = 0;
const MAX_EPOCHS_AHEAD: u32 = 104;

const ROOT_HASH: u256 = 0xABC;
const SIZE: u64 = 5_000_000;
const EPOCH: u32 = 0;

const N_COINS: u64 = 1_000_000_000;

#[test]
fun blob_register_happy_path() {
    let mut system: system::System = system::new_for_testing();

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let blob = register_default_blob(&mut system, storage, false);

    blob.burn();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = blob::EResourceSize)]
fun blob_insufficient_space() {
    let mut system: system::System = system::new_for_testing();

    // Get a storage resource that is too small.
    let storage = get_storage_resource(&mut system, SIZE / 2, 3);

    // Test fails here
    let _blob = register_default_blob(&mut system, storage, false);

    abort
}

#[test]
fun blob_certify_happy_path() {
    let mut system: system::System = system::new_for_testing();

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);

    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Assert certified
    assert!(blob.certified_epoch().is_some());

    blob.burn();
    system.destroy_for_testing();
}

#[test]
fun blob_certify_single_function() {
    let sk = test_utils::bls_sk_for_testing();

    // Create a new system object
    let mut system: system::System = system::new_for_testing();

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a Blob
    let mut blob1 = register_default_blob(&mut system, storage, false);

    // BCS confirmation message for epoch 0 and blob id `blob_id` with intents
    let confirmation_message = messages::certified_permanent_message_bytes(
        EPOCH,
        default_blob_id(),
    );
    // Signature from private key scalar(117) on `confirmation`
    let signature = bls_min_pk_sign(&confirmation_message, &sk);
    // Set certify
    system.certify_blob(&mut blob1, signature, signers_to_bitmap(&vector[0]), confirmation_message);

    // Assert certified
    assert!(blob1.certified_epoch().is_some());

    blob1.burn();
    system.destroy_for_testing();
}

#[test]
fun blob_certify_deletable_blob() {
    let sk = test_utils::bls_sk_for_testing();

    // Create a new system object
    let mut system: system::System = system::new_for_testing();

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a Blob
    let mut blob1 = register_default_blob(&mut system, storage, true);

    // BCS confirmation message for epoch 0 and blob id `blob_id` with intents
    let confirmation_message = messages::certified_deletable_message_bytes(
        EPOCH,
        default_blob_id(),
        blob1.object_id(),
    );
    // Signature from private key scalar(117) on `confirmation`
    let signature = bls_min_pk_sign(&confirmation_message, &sk);
    // Set certify
    system.certify_blob(&mut blob1, signature, signers_to_bitmap(&vector[0]), confirmation_message);

    // Assert certified
    assert!(blob1.certified_epoch().is_some());

    blob1.burn();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = blob::EInvalidBlobPersistenceType)]
fun blob_certify_deletable_msg_for_permanent_blob() {
    let sk = test_utils::bls_sk_for_testing();

    // Create a new system object
    let mut system: system::System = system::new_for_testing();

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a Blob
    let mut blob1 = register_default_blob(&mut system, storage, false);

    // BCS confirmation message for epoch 0 and blob id `blob_id` with intents
    let confirmation_message = messages::certified_deletable_message_bytes(
        EPOCH,
        default_blob_id(),
        blob1.object_id(),
    );
    // Signature from private key scalar(117) on `confirmation`
    let signature = bls_min_pk_sign(&confirmation_message, &sk);
    // Set certify, test fails here
    system.certify_blob(&mut blob1, signature, signers_to_bitmap(&vector[0]), confirmation_message);

    abort
}

#[test, expected_failure(abort_code = blob::EInvalidBlobObject)]
fun blob_certify_deletable_wrong_object_id() {
    let sk = test_utils::bls_sk_for_testing();

    // Create a new system object
    let mut system: system::System = system::new_for_testing();

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a Blob
    let mut blob1 = register_default_blob(&mut system, storage, true);

    // BCS confirmation message for epoch 0 and blob id `blob_id` with intents, with wrong object id
    let confirmation_message = messages::certified_deletable_message_bytes(
        EPOCH,
        default_blob_id(),
        object::id_from_address(@1),
    );

    // Signature from private key scalar(117) on `confirmation`
    let signature = bls_min_pk_sign(&confirmation_message, &sk);
    // Set certify, test fails here
    system.certify_blob(&mut blob1, signature, signers_to_bitmap(&vector[0]), confirmation_message);

    abort
}

#[test, expected_failure(abort_code = blob::EInvalidBlobId)]
fun blob_certify_bad_blob_id() {
    let mut system: system::System = system::new_for_testing();

    let storage = get_storage_resource(&mut system, SIZE, 3);

    let mut blob = register_default_blob(&mut system, storage, false);

    // Create certify message with wrong blob id.
    let certify_message = messages::certified_deletable_blob_message_for_testing(
        0x42,
        blob.object_id(),
    );

    // Try to certify. Test fails here.
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    abort
}

#[test]
fun certified_blob_message() {
    let blob_id = default_blob_id();
    let message_bytes = messages::certified_permanent_message_bytes(EPOCH, blob_id);
    let msg = messages::new_certified_message(message_bytes, EPOCH, 10);

    let message = msg.certify_blob_message();
    assert!(message.certified_blob_id() == blob_id);
}

#[test, expected_failure(abort_code = bcs::EOutOfRange)]
fun certified_blob_message_too_short() {
    let mut msg_bytes = messages::certified_permanent_message_bytes(EPOCH, default_blob_id());
    // Shorten message
    let _ = msg_bytes.pop_back();
    let cert_msg = messages::new_certified_message(msg_bytes, EPOCH, 10);

    // Test fails here
    let _message = cert_msg.certify_blob_message();
}

#[test]
fun blob_extend_happy_path() {
    let ctx = &mut tx_context::dummy();
    let mut system: system::System = system::new_for_testing();

    let end_epoch_1 = 3;
    let end_epoch_2 = 5;

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, end_epoch_1);

    // Get a longer storage period
    let mut storage_long = get_storage_resource(&mut system, SIZE, end_epoch_2);

    // Split by period
    let trailing_storage = storage_long.split_by_epoch(end_epoch_1, ctx);

    // Register a Blob
    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(default_blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Check that the blob expires in the initial epoch.
    assert!(blob.storage().end_epoch() == end_epoch_1);

    // Now extend the blob
    system.extend_blob_with_resource(&mut blob, trailing_storage);

    // Check that the blob has been extended.
    assert!(blob.storage().end_epoch() == end_epoch_2);

    storage_long.destroy();
    blob.burn();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = storage_resource::EIncompatibleEpochs)]
fun blob_extend_bad_period() {
    let ctx = &mut tx_context::dummy();
    let mut system: system::System = system::new_for_testing();

    let end_epoch_1 = 3;
    let end_epoch_2 = 5;

    // Get some space for a few epochs
    let storage = get_storage_resource(&mut system, SIZE, end_epoch_1);

    // Get a longer storage period
    let mut storage_long = get_storage_resource(&mut system, SIZE, end_epoch_2);

    // Split by period, one epoch too late.
    let trailing_storage = storage_long.split_by_epoch(end_epoch_1 + 1, ctx);

    // Register a Blob
    let mut blob = register_default_blob(&mut system, storage, false);
    let certify_message = messages::certified_permanent_blob_message_for_testing(default_blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Check that the blob expires in the initial epoch.
    assert!(blob.storage().end_epoch() == end_epoch_1);

    // Now try to extend the blob. Test fails here.
    system.extend_blob_with_resource(&mut blob, trailing_storage);

    abort
}

#[test]
fun direct_extend_happy() {
    let mut system: system::System = system::new_for_testing();
    let initial_duration = 3;
    let extension = 3;

    let storage = get_storage_resource(&mut system, SIZE, initial_duration);

    let mut blob = register_default_blob(&mut system, storage, false);

    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Now extend the blob with another 3 epochs
    let mut fake_coin = test_utils::mint(N_COINS, &mut tx_context::dummy());
    system.extend_blob(&mut blob, extension, &mut fake_coin);

    // Assert end epoch
    assert!(blob.storage().end_epoch() == EPOCH + initial_duration + extension);

    fake_coin.burn_for_testing();
    blob.burn();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = blob::ENotCertified)]
fun direct_extend_not_certified() {
    let mut system: system::System = system::new_for_testing();
    let initial_duration = 3;
    let extension = 3;

    let storage = get_storage_resource(&mut system, SIZE, initial_duration);

    let mut blob = register_default_blob(&mut system, storage, false);

    // Don't certify the blob

    // Now try to extend the blob with another 3 epochs
    let mut fake_coin = test_utils::mint(N_COINS, &mut tx_context::dummy());
    system.extend_blob(&mut blob, extension, &mut fake_coin);
    abort
}

#[test, expected_failure(abort_code = blob::EResourceBounds)]
fun direct_extend_expired() {
    let mut system: system::System = system::new_for_testing();
    let initial_duration = 1;
    let extension = 3;

    let storage = get_storage_resource(&mut system, SIZE, initial_duration);

    let mut blob = register_default_blob(&mut system, storage, false);

    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Advance the epoch
    let committee = test_utils::new_bls_committee_for_testing(1);
    let (_, balances) = system
        .advance_epoch(committee, &epoch_params_for_testing())
        .into_keys_values();

    balances.do!(|b| { b.destroy_for_testing(); });

    let mut fake_coin = test_utils::mint(N_COINS, &mut tx_context::dummy());
    // Now extend the blob with another 3 epochs. Test fails here.
    system.extend_blob(&mut blob, extension, &mut fake_coin);

    abort
}

#[test, expected_failure(abort_code = system_state_inner::EInvalidEpochsAhead)]
fun direct_extend_too_long() {
    let mut system: system::System = system::new_for_testing();
    let initial_duration = 3;
    let extension = MAX_EPOCHS_AHEAD;

    let storage = get_storage_resource(&mut system, SIZE, initial_duration);

    let mut blob = register_default_blob(&mut system, storage, false);

    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    let mut fake_coin = test_utils::mint(N_COINS, &mut tx_context::dummy());
    // Try to extend the blob with max epochs. Test fails here.
    system.extend_blob(&mut blob, extension, &mut fake_coin);

    abort
}

#[test]
fun delete_blob() {
    let mut system: system::System = system::new_for_testing();

    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a deletable blob.
    let mut blob = register_default_blob(&mut system, storage, true);

    let certify_message = messages::certified_deletable_blob_message_for_testing(
        blob.blob_id(),
        blob.object_id(),
    );

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Assert certified
    assert!(blob.certified_epoch().is_some());

    // Now delete the blob
    let storage = system.delete_blob(blob);

    storage.destroy();
    system.destroy_for_testing();
}

#[test, expected_failure(abort_code = blob::EBlobNotDeletable)]
fun delete_undeletable_blob() {
    let mut system: system::System = system::new_for_testing();

    let storage = get_storage_resource(&mut system, SIZE, 3);

    // Register a non-deletable blob.
    let mut blob = register_default_blob(&mut system, storage, false);

    let certify_message = messages::certified_permanent_blob_message_for_testing(blob.blob_id());

    // Set certify
    blob.certify_with_certified_msg(system.epoch(), certify_message);

    // Assert certified
    assert!(blob.certified_epoch().is_some());

    // Now delete the blob. Test fails here.
    let _storage = system.delete_blob(blob);

    abort
}

// === Metadata ===

#[test]
fun blob_add_metadata() {
    call_function_with_default_blob!(|blob| {
        let metadata = metadata::new();
        blob.add_metadata(metadata);
        blob.insert_or_update_metadata_pair(b"key1".to_string(), b"value1".to_string());
        blob.insert_or_update_metadata_pair(b"key1".to_string(), b"value3".to_string());

        let (key, value) = blob.remove_metadata_pair(&b"key1".to_string());
        assert!(key == b"key1".to_string());
        assert!(value == b"value3".to_string());
    })
}

#[test, expected_failure(abort_code = blob::EDuplicateMetadata)]
fun blob_add_metadata_already_exists() {
    call_function_with_default_blob!(|blob| {
        let metadata1 = metadata::new();
        blob.add_metadata(metadata1);
        let metadata2 = metadata::new();

        // The metadata field already exists. Test fails here.
        blob.add_metadata(metadata2);
    })
}

#[test, expected_failure(abort_code = blob::EMissingMetadata)]
fun blob_take_metadata_nonexistent() {
    call_function_with_default_blob!(|blob| {
        // Try to take the metadata from a blob without metadata. Test fails here.
        blob.take_metadata();
    })
}

#[test, expected_failure(abort_code = blob::EMissingMetadata)]
fun blob_insert_metadata_pair_nonexistent() {
    call_function_with_default_blob!(|blob| {
        // Try to insert metadata into a blob without metadata. Test fails here.
        blob.insert_or_update_metadata_pair(b"key1".to_string(), b"value1".to_string());
    })
}

#[test, expected_failure(abort_code = blob::EMissingMetadata)]
fun blob_remove_metadata_pair_nonexistent() {
    call_function_with_default_blob!(|blob| {
        // Try to remove metadata from a blob without metadata. Test fails here.
        blob.remove_metadata_pair(&b"key1".to_string());
    })
}

// === Helper functions ===

fun get_storage_resource(system: &mut System, unencoded_size: u64, epochs_ahead: u32): Storage {
    let ctx = &mut tx_context::dummy();
    let mut fake_coin = test_utils::mint(N_COINS, ctx);
    let storage_size = encoding::encoded_blob_length(unencoded_size, RED_STUFF, system.n_shards());
    let storage = system.reserve_space(
        storage_size,
        epochs_ahead,
        &mut fake_coin,
        ctx,
    );
    fake_coin.burn_for_testing();
    storage
}

fun register_default_blob(system: &mut System, storage: Storage, deletable: bool): Blob {
    let ctx = &mut tx_context::dummy();
    let mut fake_coin = test_utils::mint(N_COINS, ctx);
    // Register a Blob
    let blob_id = blob::derive_blob_id(ROOT_HASH, RED_STUFF, SIZE);
    let blob = system.register_blob(
        storage,
        blob_id,
        ROOT_HASH,
        SIZE,
        RED_STUFF,
        deletable,
        &mut fake_coin,
        ctx,
    );

    fake_coin.burn_for_testing();
    blob
}

fun default_blob_id(): u256 {
    blob::derive_blob_id(ROOT_HASH, RED_STUFF, SIZE)
}

/// Utiliy macro that calls the given function on a new Blob.
///
/// Creates the system, registers the default blob, and calls the given function with the blob.
/// Finally, it destroys the blob and returns the system.
macro fun call_function_with_default_blob($f: |&mut Blob| -> ()) {
    let mut system: system::System = system::new_for_testing();
    let storage = get_storage_resource(&mut system, SIZE, 3);
    let mut blob = register_default_blob(&mut system, storage, false);

    // Call the function with the blob.
    $f(&mut blob);

    // Cleanup.
    blob.burn();
    system.destroy_for_testing();
}
