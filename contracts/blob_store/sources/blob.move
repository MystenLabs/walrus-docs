// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::blob {
    use sui::bcs;
    use sui::hash;

    use blob_store::committee::{Self, CertifiedMessage};
    use blob_store::system::{Self, System};
    use blob_store::storage_resource::{
        Storage,
        start_epoch,
        end_epoch,
        storage_size,
        fuse_periods,
        destroy};
    use blob_store::encoding;
    use blob_store::blob_events::{emit_blob_registered, emit_blob_certified};

    // A certify blob message structure
    const BLOB_CERT_MSG_TYPE: u8 = 1;

    // Error codes
    const ERROR_INVALID_MSG_TYPE: u64 = 1;
    const ERROR_RESOURCE_BOUNDS: u64 = 2;
    const ERROR_RESOURCE_SIZE: u64 = 3;
    const ERROR_WRONG_EPOCH: u64 = 4;
    const ERROR_ALREADY_CERTIFIED: u64 = 5;
    const ERROR_INVALID_BLOB_ID: u64 = 6;
    const ERROR_NOT_CERTIFIED : u64 = 7;

    // Object definitions

    /// The blob structure represents a blob that has been registered to with some storage,
    /// and then may eventually be certified as being available in the system.
    public struct Blob has key, store {
        id: UID,
        stored_epoch: u64,
        blob_id: u256,
        size: u64,
        erasure_code_type: u8,
        certified: option::Option<u64>, // Store the epoch first certified
        storage: Storage,
    }

    // Accessor functions

    public fun stored_epoch(b: &Blob) : u64 {
        b.stored_epoch
    }

    public fun blob_id(b: &Blob) : u256 {
        b.blob_id
    }

    public fun size(b: &Blob) : u64 {
        b.size
    }

    public fun erasure_code_type(b: &Blob) : u8 {
        b.erasure_code_type
    }

    public fun certified(b: &Blob) : &Option<u64> {
        &b.certified
    }

    public fun storage(b: &Blob) : &Storage {
        &b.storage
    }

    public struct BlobIdDerivation has drop {
        erasure_code_type: u8,
        size: u64,
        root_hash: u256,
    }

    /// Derive the blob_id for a blob given the root_hash, erasure_code_type and size.
    public fun derive_blob_id(root_hash: u256, erasure_code_type: u8, size : u64) : u256 {

        let blob_id_struct = BlobIdDerivation {
            erasure_code_type,
            size,
            root_hash,
        };

        let serialized = bcs::to_bytes(&blob_id_struct);
        let encoded = hash::blake2b256(&serialized);
        let mut decoder = bcs::new(encoded);
        let blob_id = bcs::peel_u256(&mut decoder);
        blob_id
    }

    /// Register a new blob in the system.
    /// `size` is the size of the unencoded blob. The reserved space in `storage` must be at
    /// least the size of the encoded blob.
    public fun register<WAL>(
        sys: &System<WAL>,
        storage: Storage,
        blob_id: u256,
        root_hash: u256,
        size: u64,
        erasure_code_type: u8,
        ctx: &mut TxContext,
        ) : Blob {

        let id = object::new(ctx);
        let stored_epoch = system::epoch(sys);

        // Check resource bounds.
        assert!(stored_epoch >= start_epoch(&storage), ERROR_RESOURCE_BOUNDS);
        assert!(stored_epoch < end_epoch(&storage), ERROR_RESOURCE_BOUNDS);

        // check that the encoded size is less than the storage size
        let encoded_size = encoding::encoded_blob_length(
            size,
            erasure_code_type,
            system::n_shards(sys)
        );
        assert!(encoded_size <= storage_size(&storage), ERROR_RESOURCE_SIZE);

        // Cryptographically verify that the Blob ID authenticates
        // both the size and fe_type.
        assert!(derive_blob_id(root_hash, erasure_code_type, size) == blob_id,
            ERROR_INVALID_BLOB_ID);


        // Emit register event
        emit_blob_registered(
            stored_epoch,
            blob_id,
            size,
            erasure_code_type,
            end_epoch(&storage),
        );

        Blob {
            id,
            stored_epoch,
            blob_id,
            size,
            //
            erasure_code_type,
            certified: option::none(),
            storage,
        }

    }

    public struct CertifiedBlobMessage has drop {
        epoch: u64,
        blob_id: u256,
    }

    /// Construct the certified blob message, note that constructing
    /// implies a certified message, that is already checked.
    public fun certify_blob_message(
        message: CertifiedMessage
        ) : CertifiedBlobMessage {

        // Assert type is correct
        assert!(committee::intent_type(&message) == BLOB_CERT_MSG_TYPE,
            ERROR_INVALID_MSG_TYPE);

        // The certified blob message contain a blob_id : u256
        let epoch = committee::cert_epoch(&message);
        let message_body = committee::into_message(message);

        let mut bcs_body = bcs::new(message_body);
        let blob_id = bcs::peel_u256(&mut bcs_body);

        // On purpose we do not check that nothing is left in the message
        // to allow in the future for extensibility.

        CertifiedBlobMessage {
            epoch,
            blob_id,
        }
    }

    /// Certify that a blob will be available in the storage system until the end epoch of the
    /// storage associated with it, given a [`CertifiedBlobMessage`].
    public fun certify_with_certified_msg<WAL>(
        sys: &System<WAL>,
        message: CertifiedBlobMessage,
        blob: &mut Blob,
    ){

        // Check that the blob is registered in the system
        assert!(blob_id(blob) == message.blob_id, ERROR_INVALID_BLOB_ID);

        // Check that the blob is not already certified
        assert!(!option::is_some(&blob.certified), ERROR_ALREADY_CERTIFIED);

        // Check that the message is from the current epoch
        assert!(message.epoch == system::epoch(sys), ERROR_WRONG_EPOCH);

        // Check that the storage in the blob is still valid
        assert!(message.epoch < end_epoch(storage(blob)), ERROR_RESOURCE_BOUNDS);

        // Mark the blob as certified
        blob.certified = option::some(message.epoch);

        // Emit certified event
        emit_blob_certified(
            message.epoch,
            message.blob_id,
            end_epoch(storage(blob)),
        );
    }

    /// Certify that a blob will be available in the storage system until the end epoch of the
    /// storage associated with it.
    public fun certify<WAL>(
        sys: &System<WAL>,
        blob: &mut Blob,
        signature: vector<u8>,
        members: vector<u16>,
        message: vector<u8>,
    ) {
        let certified_msg = committee::verify_quorum_in_epoch(
            system::current_committee(sys),
            signature,
            members,
            message
        );
        let certified_blob_msg = certify_blob_message(certified_msg);
        certify_with_certified_msg(sys, certified_blob_msg, blob);
    }

    /// After the period of validity expires for the blob we can destroy the blob resource.
    public fun destroy_blob<WAL>(
        sys: &System<WAL>,
        blob: Blob,
    ){

        let current_epoch = system::epoch(sys);
        assert!(current_epoch >= end_epoch(storage(&blob)), ERROR_RESOURCE_BOUNDS);

        // Destroy the blob
        let Blob {
            id,
            stored_epoch: _,
            blob_id: _,
            size: _,
            erasure_code_type: _,
            certified: _,
            storage,
        } = blob;

        object::delete(id);
        destroy(storage);
    }

    /// Extend the period of validity of a blob with a new storage resource.
    /// The new storage resource must be the same size as the storage resource
    /// used in the blob, and have a longer period of validity.
    public fun extend<WAL>(
        sys: &System<WAL>,
        blob: &mut Blob,
        extension: Storage){

        // We only extend certified blobs within their period of validity
        // with storage that extends this period. First we check for these
        // conditions.

        // Assert this is a certified blob
        assert!(option::is_some(&blob.certified), ERROR_NOT_CERTIFIED);

        // Check the blob is within its availability period
        assert!(system::epoch(sys) < end_epoch(storage(blob)), ERROR_RESOURCE_BOUNDS);

        // Check that the extension is valid, and the end
        // period of the extension is after the current period.
        assert!(end_epoch(&extension) > end_epoch(storage(blob)), ERROR_RESOURCE_BOUNDS);

        // Note: if the amounts do not match there will be an abort here.
        fuse_periods(&mut blob.storage , extension);

        // Emit certified event
        //
        // Note: We use the original certified period since for the purposes of
        // reconfiguration this is the committee that has a quorum that hold the
        // resource.
        emit_blob_certified(
            *option::borrow(&blob.certified),
            blob.blob_id,
            end_epoch(storage(blob)),
        );

    }

    // Testing Functions

    #[test_only]
    public fun drop_for_testing(b: Blob) {
        // deconstruct
        let Blob {
            id,
            stored_epoch: _,
            blob_id: _,
            size: _,
            erasure_code_type: _,
            certified: _,
            storage,
        } = b;

        object::delete(id);
        destroy(storage);
    }

    #[test_only]
    // Accessor for blob
    public fun message_blob_id(m: &CertifiedBlobMessage) : u256 {
        m.blob_id
    }

    #[test_only]
    public fun certified_blob_message_for_testing(
        epoch: u64,
        blob_id: u256,
        ) : CertifiedBlobMessage {
        CertifiedBlobMessage {
            epoch,
            blob_id,
        }
    }

}
