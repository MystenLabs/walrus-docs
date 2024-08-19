// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module to emit blob events. Used to allow filtering all blob events in the
/// rust client (as work-around for the lack of composable event filters).
module blob_store::blob_events {
    use sui::event;

    // Event definitions

    /// Signals a blob with meta-data is registered.
    public struct BlobRegistered has copy, drop {
        epoch: u64,
        blob_id: u256,
        size: u64,
        erasure_code_type: u8,
        end_epoch: u64,
    }

    /// Signals a blob is certified.
    public struct BlobCertified has copy, drop {
        epoch: u64,
        blob_id: u256,
        end_epoch: u64,
    }

    /// Signals that a BlobID is invalid.
    public struct InvalidBlobID has copy, drop {
        epoch: u64, // The epoch in which the blob ID is first registered as invalid
        blob_id: u256,
    }

    public(package) fun emit_blob_registered(
        epoch: u64,
        blob_id: u256,
        size: u64,
        erasure_code_type: u8,
        end_epoch: u64,
    ) {
        event::emit(BlobRegistered { epoch, blob_id, size, erasure_code_type, end_epoch });
    }

    public(package) fun emit_blob_certified(epoch: u64, blob_id: u256, end_epoch: u64) {
        event::emit(BlobCertified { epoch, blob_id, end_epoch });
    }

    public(package) fun emit_invalid_blob_id(epoch: u64, blob_id: u256) {
        event::emit(InvalidBlobID { epoch, blob_id });
    }
}
