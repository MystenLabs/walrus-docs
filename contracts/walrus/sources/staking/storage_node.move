// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_field, unused_function, unused_variable, unused_use)]
module walrus::storage_node;

use std::string::String;
use sui::{bls12381::{UncompressedG1, g1_from_bytes, g1_to_uncompressed_g1}, group_ops::Element};
use walrus::{
    event_blob::EventBlobAttestation,
    extended_field::{Self, ExtendedField},
    node_metadata::NodeMetadata
};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The network public key length is invalid.
const EInvalidNetworkPublicKey: u64 = 0;

/// Represents a storage node in the system.
public struct StorageNodeInfo has store {
    name: String,
    node_id: ID,
    network_address: String,
    public_key: Element<UncompressedG1>,
    next_epoch_public_key: Option<Element<UncompressedG1>>,
    network_public_key: vector<u8>,
    metadata: ExtendedField<NodeMetadata>,
}

/// A Capability which represents a storage node and authorizes the holder to
/// perform operations on the storage node.
public struct StorageNodeCap has key, store {
    id: UID,
    node_id: ID,
    last_epoch_sync_done: u32,
    last_event_blob_attestation: Option<EventBlobAttestation>,
    /// Stores the Merkle root of the deny list for the storage node.
    deny_list_root: u256,
    /// Stores the sequence number of the deny list for the storage node.
    deny_list_sequence: u64,
    /// Stores the size of the deny list for the storage node.
    deny_list_size: u64,
}

/// A public constructor for the StorageNodeInfo.
public(package) fun new(
    name: String,
    node_id: ID,
    network_address: String,
    public_key: vector<u8>,
    network_public_key: vector<u8>,
    metadata: NodeMetadata,
    ctx: &mut TxContext,
): StorageNodeInfo {
    assert!(network_public_key.length() == 33, EInvalidNetworkPublicKey);
    StorageNodeInfo {
        node_id,
        name,
        network_address,
        public_key: g1_to_uncompressed_g1(&g1_from_bytes(&public_key)),
        next_epoch_public_key: option::none(),
        network_public_key,
        metadata: extended_field::new(metadata, ctx),
    }
}

/// Create a new storage node capability.
public(package) fun new_cap(node_id: ID, ctx: &mut TxContext): StorageNodeCap {
    StorageNodeCap {
        id: object::new(ctx),
        node_id,
        last_epoch_sync_done: 0,
        last_event_blob_attestation: option::none(),
        deny_list_root: 0,
        deny_list_sequence: 0,
        deny_list_size: 0,
    }
}

// === Accessors ===

/// Return the public key of the storage node.
public(package) fun public_key(self: &StorageNodeInfo): &Element<UncompressedG1> {
    &self.public_key
}

/// Return the name of the storage node.
public(package) fun metadata(self: &StorageNodeInfo): NodeMetadata {
    *self.metadata.borrow()
}

/// Return the public key of the storage node for the next epoch.
public(package) fun next_epoch_public_key(self: &StorageNodeInfo): &Element<UncompressedG1> {
    self.next_epoch_public_key.borrow_with_default(&self.public_key)
}

/// Return the node ID of the storage node.
public fun id(cap: &StorageNodeInfo): ID { cap.node_id }

/// Return the pool ID of the storage node.
public fun node_id(cap: &StorageNodeCap): ID { cap.node_id }

/// Return the last epoch in which the storage node attested that it has
/// finished syncing.
public fun last_epoch_sync_done(cap: &StorageNodeCap): u32 {
    cap.last_epoch_sync_done
}

/// Return the latest event blob attestion.
public fun last_event_blob_attestation(cap: &mut StorageNodeCap): Option<EventBlobAttestation> {
    cap.last_event_blob_attestation
}

/// Return the deny list root of the storage node.
public fun deny_list_root(cap: &StorageNodeCap): u256 { cap.deny_list_root }

/// Return the deny list sequence number of the storage node.
public fun deny_list_sequence(cap: &StorageNodeCap): u64 { cap.deny_list_sequence }

// === Modifiers ===

/// Set the last epoch in which the storage node attested that it has finished syncing.
public(package) fun set_last_epoch_sync_done(self: &mut StorageNodeCap, epoch: u32) {
    self.last_epoch_sync_done = epoch;
}

/// Set the last epoch in which the storage node attested that it has finished syncing.
public(package) fun set_last_event_blob_attestation(
    self: &mut StorageNodeCap,
    attestation: EventBlobAttestation,
) {
    self.last_event_blob_attestation = option::some(attestation);
}

/// Sets the public key to be used starting from the next epoch for which the node is selected.
public(package) fun set_next_public_key(self: &mut StorageNodeInfo, public_key: vector<u8>) {
    let public_key = g1_from_bytes(&public_key);
    self.next_epoch_public_key.swap_or_fill(g1_to_uncompressed_g1(&public_key));
}

/// Sets the name of the storage node.
public(package) fun set_name(self: &mut StorageNodeInfo, name: String) {
    self.name = name;
}

/// Sets the network address or host of the storage node.
public(package) fun set_network_address(self: &mut StorageNodeInfo, network_address: String) {
    self.network_address = network_address;
}

/// Sets the public key used for TLS communication.
public(package) fun set_network_public_key(
    self: &mut StorageNodeInfo,
    network_public_key: vector<u8>,
) {
    assert!(network_public_key.length() == 33, EInvalidNetworkPublicKey);
    self.network_public_key = network_public_key;
}

/// Sets the metadata of the storage node.
public(package) fun set_node_metadata(self: &mut StorageNodeInfo, metadata: NodeMetadata) {
    self.metadata.swap(metadata);
}

/// Set the public key to the next epochs public key.
public(package) fun rotate_public_key(self: &mut StorageNodeInfo) {
    if (self.next_epoch_public_key.is_some()) {
        self.public_key = self.next_epoch_public_key.extract()
    }
}

/// Destroy the storage node.
public(package) fun destroy(self: StorageNodeInfo) {
    let StorageNodeInfo { metadata, .. } = self;
    metadata.destroy();
}

/// Set the deny list root of the storage node.
public(package) fun set_deny_list_properties(
    self: &mut StorageNodeCap,
    root: u256,
    sequence: u64,
    size: u64,
) {
    self.deny_list_root = root;
    self.deny_list_sequence = sequence;
    self.deny_list_size = size;
}

// === Testing ===

#[test_only]
/// Create a storage node with dummy name & address
public fun new_for_testing(public_key: vector<u8>): StorageNodeInfo {
    let ctx = &mut tx_context::dummy();
    let node_id = ctx.fresh_object_address().to_id();
    StorageNodeInfo {
        node_id,
        name: b"node".to_string(),
        network_address: b"127.0.0.1".to_string(),
        public_key: g1_to_uncompressed_g1(&g1_from_bytes(&public_key)),
        next_epoch_public_key: option::none(),
        network_public_key: x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677ab",
        metadata: extended_field::new(walrus::node_metadata::default(), ctx),
    }
}

#[test_only]
public fun destroy_cap_for_testing(cap: StorageNodeCap) {
    let StorageNodeCap { id, .. } = cap;
    id.delete();
}
