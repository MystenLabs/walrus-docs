// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::blob;

use std::string::String;
use sui::{bcs, dynamic_field, hash};
use walrus::{
    encoding,
    events::{emit_blob_registered, emit_blob_certified, emit_blob_deleted},
    messages::CertifiedBlobMessage,
    metadata::{Self, Metadata},
    storage_resource::Storage
};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The blob is not certified.
const ENotCertified: u64 = 0;
/// The blob is not deletable.
const EBlobNotDeletable: u64 = 1;
/// The bounds of the storage resource are exceeded.
const EResourceBounds: u64 = 2;
/// The storage resource size is insufficient.
const EResourceSize: u64 = 3;
// Error code 4 is available
/// The blob was already certified.
const EAlreadyCertified: u64 = 5;
/// The blob ID is incorrect.
const EInvalidBlobId: u64 = 6;
/// The metadata field already exists.
const EDuplicateMetadata: u64 = 7;
/// The blob does not have any metadata.
const EMissingMetadata: u64 = 8;
/// The blob persistence type of the blob does not match the certificate.
const EInvalidBlobPersistenceType: u64 = 9;
/// The blob object ID of a deletable blob does not match the ID in the certificate.
const EInvalidBlobObject: u64 = 10;

// The fixed dynamic filed name for metadata
const METADATA_DF: vector<u8> = b"metadata";

// === Object definitions ===

/// The blob structure represents a blob that has been registered to with some storage,
/// and then may eventually be certified as being available in the system.
public struct Blob has key, store {
    id: UID,
    registered_epoch: u32,
    blob_id: u256,
    size: u64,
    encoding_type: u8,
    // Stores the epoch first certified.
    certified_epoch: option::Option<u32>,
    storage: Storage,
    // Marks if this blob can be deleted.
    deletable: bool,
}

// === Accessors ===

public fun object_id(self: &Blob): ID {
    object::id(self)
}

public fun registered_epoch(self: &Blob): u32 {
    self.registered_epoch
}

public fun blob_id(self: &Blob): u256 {
    self.blob_id
}

public fun size(self: &Blob): u64 {
    self.size
}

public fun encoding_type(self: &Blob): u8 {
    self.encoding_type
}

public fun certified_epoch(self: &Blob): &Option<u32> {
    &self.certified_epoch
}

public fun storage(self: &Blob): &Storage {
    &self.storage
}

public fun encoded_size(self: &Blob, n_shards: u16): u64 {
    encoding::encoded_blob_length(
        self.size,
        self.encoding_type,
        n_shards,
    )
}

public(package) fun storage_mut(self: &mut Blob): &mut Storage {
    &mut self.storage
}

public fun end_epoch(self: &Blob): u32 {
    self.storage.end_epoch()
}

/// Aborts if the blob is not certified or already expired.
public(package) fun assert_certified_not_expired(self: &Blob, current_epoch: u32) {
    // Assert this is a certified blob
    assert!(self.certified_epoch.is_some(), ENotCertified);

    // Check the blob is within its availability period
    assert!(current_epoch < self.storage.end_epoch(), EResourceBounds);
}

public struct BlobIdDerivation has drop {
    encoding_type: u8,
    size: u64,
    root_hash: u256,
}

/// Derives the blob_id for a blob given the root_hash, encoding_type and size.
public fun derive_blob_id(root_hash: u256, encoding_type: u8, size: u64): u256 {
    let blob_id_struct = BlobIdDerivation {
        encoding_type,
        size,
        root_hash,
    };

    let serialized = bcs::to_bytes(&blob_id_struct);
    let encoded = hash::blake2b256(&serialized);
    let mut decoder = bcs::new(encoded);
    let blob_id = decoder.peel_u256();
    blob_id
}

/// Creates a new blob in `registered_epoch`.
/// `size` is the size of the unencoded blob. The reserved space in `storage` must be at
/// least the size of the encoded blob.
public(package) fun new(
    storage: Storage,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    deletable: bool,
    registered_epoch: u32,
    n_shards: u16,
    ctx: &mut TxContext,
): Blob {
    let id = object::new(ctx);

    // Check resource bounds.
    assert!(registered_epoch >= storage.start_epoch(), EResourceBounds);
    assert!(registered_epoch < storage.end_epoch(), EResourceBounds);

    // check that the encoded size is less than the storage size
    let encoded_size = encoding::encoded_blob_length(
        size,
        encoding_type,
        n_shards,
    );
    assert!(encoded_size <= storage.size(), EResourceSize);

    // Cryptographically verify that the Blob ID authenticates
    // both the size and encoding_type (sanity check).
    assert!(derive_blob_id(root_hash, encoding_type, size) == blob_id, EInvalidBlobId);

    // Emit register event
    emit_blob_registered(
        registered_epoch,
        blob_id,
        size,
        encoding_type,
        storage.end_epoch(),
        deletable,
        id.to_inner(),
    );

    Blob {
        id,
        registered_epoch,
        blob_id,
        size,
        encoding_type,
        certified_epoch: option::none(),
        storage,
        deletable,
    }
}

/// Certifies that a blob will be available in the storage system until the end epoch of the
/// storage associated with it, given a [`CertifiedBlobMessage`].
public(package) fun certify_with_certified_msg(
    blob: &mut Blob,
    current_epoch: u32,
    message: CertifiedBlobMessage,
) {
    // Check that the blob is registered in the system
    assert!(blob.blob_id() == message.certified_blob_id(), EInvalidBlobId);

    // Check that the blob is not already certified
    assert!(!blob.certified_epoch.is_some(), EAlreadyCertified);

    // Check that the storage in the blob is still valid
    assert!(current_epoch < blob.storage.end_epoch(), EResourceBounds);

    // Check the blob persistence type
    assert!(
        blob.deletable == message.blob_persistence_type().is_deletable(),
        EInvalidBlobPersistenceType,
    );

    // Check that the object id matches the message
    if (blob.deletable) {
        assert!(
            message.blob_persistence_type().object_id() == object::id(blob),
            EInvalidBlobObject,
        );
    };

    // Mark the blob as certified
    blob.certified_epoch.fill(current_epoch);

    blob.emit_certified(false);
}

/// Deletes a deletable blob and returns the contained storage.
///
/// Emits a `BlobDeleted` event for the given epoch.
/// Aborts if the Blob is not deletable or already expired.
/// Also removes any metadata associated with the blob.
public(package) fun delete(mut self: Blob, epoch: u32): Storage {
    dynamic_field::remove_if_exists<_, Metadata>(&mut self.id, METADATA_DF);
    let Blob {
        id,
        storage,
        deletable,
        blob_id,
        certified_epoch,
        ..,
    } = self;
    assert!(deletable, EBlobNotDeletable);
    assert!(storage.end_epoch() > epoch, EResourceBounds);
    let object_id = id.to_inner();
    id.delete();
    emit_blob_deleted(epoch, blob_id, storage.end_epoch(), object_id, certified_epoch.is_some());
    storage
}

/// Allows calling `.share()` on a `Blob` to wrap it into a shared `SharedBlob` whose lifetime can
/// be extended by anyone.
public use fun walrus::shared_blob::new as Blob.share;

/// Allow the owner of a blob object to destroy it.
///
/// This function also burns any [`Metadata`] associated with the blob, if present.
public fun burn(mut self: Blob) {
    dynamic_field::remove_if_exists<_, Metadata>(&mut self.id, METADATA_DF);
    let Blob { id, storage, .. } = self;

    id.delete();
    storage.destroy();
}

/// Extend the period of validity of a blob with a new storage resource.
/// The new storage resource must be the same size as the storage resource
/// used in the blob, and have a longer period of validity.
public(package) fun extend_with_resource(blob: &mut Blob, extension: Storage, current_epoch: u32) {
    // We only extend certified blobs within their period of validity
    // with storage that extends this period. First we check for these
    // conditions.

    blob.assert_certified_not_expired(current_epoch);

    // Check that the extension is valid, and the end
    // period of the extension is after the current period.
    assert!(extension.end_epoch() > blob.storage.end_epoch(), EResourceBounds);

    // Note: if the amounts do not match there will be an abort here.
    blob.storage.fuse_periods(extension);

    blob.emit_certified(true);
}

/// Emits a `BlobCertified` event for the given blob.
public(package) fun emit_certified(self: &Blob, is_extension: bool) {
    // Emit certified event
    //
    // Note: We use the original certified period also for extensions since
    // for the purposes of reconfiguration this is the committee that has a
    // quorum that hold the resource.
    emit_blob_certified(
        *self.certified_epoch.borrow(),
        self.blob_id,
        self.storage.end_epoch(),
        self.deletable,
        self.id.to_inner(),
        is_extension,
    );
}

// === Metadata ===

/// Adds the metadata dynamic field to the Blob.
///
/// Aborts if the metadata is already present.
public fun add_metadata(self: &mut Blob, metadata: Metadata) {
    assert!(!dynamic_field::exists_(&self.id, METADATA_DF), EDuplicateMetadata);
    dynamic_field::add(&mut self.id, METADATA_DF, metadata)
}

/// Adds the metadata dynamic field to the Blob, replacing the existing metadata if present.
///
/// Returns the replaced metadata if present.
public fun add_or_replace_metadata(self: &mut Blob, metadata: Metadata): option::Option<Metadata> {
    let old_metadata = if (dynamic_field::exists_(&self.id, METADATA_DF)) {
        option::some(self.take_metadata())
    } else {
        option::none()
    };
    self.add_metadata(metadata);
    old_metadata
}

/// Removes the metadata dynamic field from the Blob, returning the contained `Metadata`.
///
/// Aborts if the metadata does not exist.
public fun take_metadata(self: &mut Blob): Metadata {
    assert!(dynamic_field::exists_(&self.id, METADATA_DF), EMissingMetadata);
    dynamic_field::remove(&mut self.id, METADATA_DF)
}

/// Returns the metadata associated with the Blob.
///
/// Aborts if the metadata does not exist.
fun metadata(self: &mut Blob): &mut Metadata {
    assert!(dynamic_field::exists_(&self.id, METADATA_DF), EMissingMetadata);
    dynamic_field::borrow_mut(&mut self.id, METADATA_DF)
}

/// Returns the metadata associated with the Blob, if it exists.
///
/// Creates new metadata if it does not exist.
fun metadata_or_create(self: &mut Blob): &mut Metadata {
    if (!dynamic_field::exists_(&self.id, METADATA_DF)) {
        self.add_metadata(metadata::new());
    };
    dynamic_field::borrow_mut(&mut self.id, METADATA_DF)
}

/// Inserts a key-value pair into the metadata.
///
/// If the key is already present, the value is updated. Creates new metadata on the Blob object if
/// it does not exist already.
public fun insert_or_update_metadata_pair(self: &mut Blob, key: String, value: String) {
    self.metadata_or_create().insert_or_update(key, value)
}

/// Removes the metadata associated with the given key.
///
/// Aborts if the metadata does not exist.
public fun remove_metadata_pair(self: &mut Blob, key: &String): (String, String) {
    self.metadata().remove(key)
}

/// Removes and returns the metadata associated with the given key, if it exists.
public fun remove_metadata_pair_if_exists(self: &mut Blob, key: &String): option::Option<String> {
    if (!dynamic_field::exists_(&self.id, METADATA_DF)) {
        option::none()
    } else {
        self.metadata().remove_if_exists(key)
    }
}

#[test_only]
public fun certify_with_certified_msg_for_testing(
    blob: &mut Blob,
    current_epoch: u32,
    message: CertifiedBlobMessage,
) {
    certify_with_certified_msg(blob, current_epoch, message)
}
