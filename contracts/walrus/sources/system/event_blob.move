// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module to certify event blobs.
module walrus::event_blob;

use sui::vec_map::{Self, VecMap};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The provided sequence number is invalid.
const EInvalidSequenceNumber: u64 = 0;

// === Definitions related to event blob certification ===

/// Event blob index which was attested by a storage node.
public struct EventBlobAttestation has copy, drop, store {
    checkpoint_sequence_num: u64,
    epoch: u32,
}

/// State of a certified event blob.
public struct EventBlob has copy, drop, store {
    /// Blob id of the certified event blob.
    blob_id: u256,
    /// Ending sui checkpoint of the certified event blob.
    ending_checkpoint_sequence_number: u64,
}

/// State of event blob stream.
public struct EventBlobCertificationState has store {
    /// Latest certified event blob.
    latest_certified_blob: Option<EventBlob>,
    /// Current event blob being attested.
    aggregate_weight_per_blob: VecMap<u256, u16>,
}

// === Accessors related to event blob attestation ===

public(package) fun new_attestation(
    checkpoint_sequence_num: u64,
    epoch: u32,
): EventBlobAttestation {
    EventBlobAttestation {
        checkpoint_sequence_num,
        epoch,
    }
}

public(package) fun last_attested_event_blob_checkpoint_seq_num(self: &EventBlobAttestation): u64 {
    self.checkpoint_sequence_num
}

public(package) fun last_attested_event_blob_epoch(self: &EventBlobAttestation): u32 { self.epoch }

// === Accessors for EventBlob ===

public(package) fun new_event_blob(
    ending_checkpoint_sequence_number: u64,
    blob_id: u256,
): EventBlob {
    EventBlob {
        blob_id,
        ending_checkpoint_sequence_number,
    }
}

/// Returns the blob id of the event blob
public(package) fun blob_id(self: &EventBlob): u256 {
    self.blob_id
}

/// Returns the ending checkpoint sequence number of the event blob
public(package) fun ending_checkpoint_sequence_number(self: &EventBlob): u64 {
    self.ending_checkpoint_sequence_number
}

// === Accessors for EventBlobCertificationState ===

/// Creates a blob state with no signers and no last checkpoint sequence number
public(package) fun create_with_empty_state(): EventBlobCertificationState {
    EventBlobCertificationState {
        latest_certified_blob: option::none(),
        aggregate_weight_per_blob: sui::vec_map::empty(),
    }
}

/// Returns the blob id of the latest certified event blob
public(package) fun get_latest_certified_blob_id(self: &EventBlobCertificationState): Option<u256> {
    self.latest_certified_blob.map!(|state| state.blob_id())
}

/// Returns the checkpoint sequence number of the latest certified event
/// blob
public(package) fun get_latest_certified_checkpoint_sequence_number(
    self: &EventBlobCertificationState,
): Option<u64> {
    self.latest_certified_blob.map!(|state| state.ending_checkpoint_sequence_number())
}

/// Returns the number of blobs being tracked
public(package) fun get_num_tracked_blobs(self: &EventBlobCertificationState): u64 {
    self.aggregate_weight_per_blob.size()
}

/// Returns true if a blob is already certified or false otherwise
public(package) fun is_blob_already_certified(
    self: &EventBlobCertificationState,
    ending_checkpoint_sequence_num: u64,
): bool {
    self
        .get_latest_certified_checkpoint_sequence_number()
        .map!(
            |
                latest_certified_sequence_num,
            | latest_certified_sequence_num >= ending_checkpoint_sequence_num,
        )
        .destroy_or!(false)
}

/// Updates the latest certified event blob
public(package) fun update_latest_certified_event_blob(
    self: &mut EventBlobCertificationState,
    checkpoint_sequence_number: u64,
    blob_id: u256,
) {
    self.get_latest_certified_checkpoint_sequence_number().do!(|latest_certified_sequence_num| {
        assert!(checkpoint_sequence_number > latest_certified_sequence_num, EInvalidSequenceNumber);
    });
    self.latest_certified_blob = option::some(new_event_blob(checkpoint_sequence_number, blob_id));
}

/// Update the aggregate weight of an event blob
public(package) fun update_aggregate_weight(
    self: &mut EventBlobCertificationState,
    blob_id: u256,
    weight: u16,
): u16 {
    let agg_weight = &mut self.aggregate_weight_per_blob[&blob_id];
    *agg_weight = *agg_weight + weight;
    *agg_weight
}

/// Start tracking which nodes are signing the event blob with given id for
/// event blob certification
public(package) fun start_tracking_blob(self: &mut EventBlobCertificationState, blob_id: u256) {
    if (!self.aggregate_weight_per_blob.contains(&blob_id)) {
        self.aggregate_weight_per_blob.insert(blob_id, 0);
    };
}

/// Reset blob certification state upon epoch change
public(package) fun reset(self: &mut EventBlobCertificationState) {
    self.aggregate_weight_per_blob = vec_map::empty();
}
