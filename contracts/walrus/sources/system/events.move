// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module to emit events. Used to allow filtering all events in the
/// rust client (as work-around for the lack of composable event filters).
module walrus::events;

use sui::event;

// === Event definitions ===

/// Signals that a blob with meta-data has been registered.
public struct BlobRegistered has copy, drop {
    epoch: u32,
    blob_id: u256,
    size: u64,
    encoding_type: u8,
    end_epoch: u32,
    deletable: bool,
    // The object id of the related `Blob` object
    // Used for keeping track of deletable blobs on the storage nodes.
    object_id: ID,
}

/// Signals that a blob is certified.
public struct BlobCertified has copy, drop {
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    deletable: bool,
    // The object id of the related `Blob` object
    object_id: ID,
    // Marks if this is an extension for explorers, etc.
    is_extension: bool,
}

/// Signals that a blob has been deleted.
public struct BlobDeleted has copy, drop {
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    // The object ID of the related `Blob` object.
    object_id: ID,
    // If the blob object was previously certified.
    was_certified: bool,
}

/// Signals that a BlobID is invalid.
public struct InvalidBlobID has copy, drop {
    epoch: u32, // The epoch in which the blob ID is first registered as invalid
    blob_id: u256,
}

/// Signals that epoch `epoch` has started and the epoch change is in progress.
public struct EpochChangeStart has copy, drop {
    epoch: u32,
}

/// Signals that a set of storage nodes holding at least 2f+1 shards have finished the epoch
/// change, i.e., received all of their assigned shards.
public struct EpochChangeDone has copy, drop {
    epoch: u32,
}

/// Signals that a node has received the specified shards for the new epoch.
public struct ShardsReceived has copy, drop {
    epoch: u32,
    shards: vector<u16>,
}

/// Signals that the committee and the system parameters for `next_epoch` have been selected.
public struct EpochParametersSelected has copy, drop {
    next_epoch: u32,
}

/// Signals that the given shards can be recovered using the shard recovery endpoint.
public struct ShardRecoveryStart has copy, drop {
    epoch: u32,
    shards: vector<u16>,
}

/// Signals that the contract has been upgraded and migrated.
public struct ContractUpgraded has copy, drop {
    epoch: u32,
    package_id: ID,
    version: u64,
}

/// Signals that a Denylist update has started.
public struct RegisterDenyListUpdate has copy, drop {
    epoch: u32,
    root: u256,
    sequence_number: u64,
    node_id: ID,
}

/// Signals that a Denylist update has been certified.
public struct DenyListUpdate has copy, drop {
    epoch: u32,
    root: u256,
    sequence_number: u64,
    node_id: ID,
}

/// Signals that a blob was denylisted by f+1 nodes.
public struct DenyListBlobDeleted has copy, drop {
    epoch: u32,
    blob_id: u256,
}

/// Signals that a new contract upgrade has been proposed.
public struct ContractUpgradeProposed has copy, drop {
    epoch: u32,
    package_digest: vector<u8>,
}

/// Signals that a contract upgrade proposal has received a quorum of votes.
public struct ContractUpgradeQuorumReached has copy, drop {
    epoch: u32,
    package_digest: vector<u8>,
}

// === Functions to emit the events from other modules ===

public(package) fun emit_blob_registered(
    epoch: u32,
    blob_id: u256,
    size: u64,
    encoding_type: u8,
    end_epoch: u32,
    deletable: bool,
    object_id: ID,
) {
    event::emit(BlobRegistered {
        epoch,
        blob_id,
        size,
        encoding_type,
        end_epoch,
        deletable,
        object_id,
    });
}

public(package) fun emit_blob_certified(
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    deletable: bool,
    object_id: ID,
    is_extension: bool,
) {
    event::emit(BlobCertified { epoch, blob_id, end_epoch, deletable, object_id, is_extension });
}

public(package) fun emit_invalid_blob_id(epoch: u32, blob_id: u256) {
    event::emit(InvalidBlobID { epoch, blob_id });
}

public(package) fun emit_blob_deleted(
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    object_id: ID,
    was_certified: bool,
) {
    event::emit(BlobDeleted { epoch, blob_id, end_epoch, object_id, was_certified });
}

public(package) fun emit_epoch_change_start(epoch: u32) {
    event::emit(EpochChangeStart { epoch })
}

public(package) fun emit_epoch_change_done(epoch: u32) {
    event::emit(EpochChangeDone { epoch })
}

public(package) fun emit_shards_received(epoch: u32, shards: vector<u16>) {
    event::emit(ShardsReceived { epoch, shards })
}

public(package) fun emit_epoch_parameters_selected(next_epoch: u32) {
    event::emit(EpochParametersSelected { next_epoch })
}

public(package) fun emit_shard_recovery_start(epoch: u32, shards: vector<u16>) {
    event::emit(ShardRecoveryStart { epoch, shards })
}

public(package) fun emit_contract_upgraded(epoch: u32, package_id: ID, version: u64) {
    event::emit(ContractUpgraded { epoch, package_id, version })
}

public(package) fun emit_register_deny_list_update(
    epoch: u32,
    root: u256,
    sequence_number: u64,
    node_id: ID,
) {
    event::emit(RegisterDenyListUpdate { epoch, root, sequence_number, node_id })
}

public(package) fun emit_deny_list_update(
    epoch: u32,
    root: u256,
    sequence_number: u64,
    node_id: ID,
) {
    event::emit(DenyListUpdate { epoch, root, sequence_number, node_id })
}

public(package) fun emit_deny_listed_blob_deleted(epoch: u32, blob_id: u256) {
    event::emit(DenyListBlobDeleted { epoch, blob_id })
}

public(package) fun emit_contract_upgrade_proposed(epoch: u32, package_digest: vector<u8>) {
    event::emit(ContractUpgradeProposed { epoch, package_digest })
}

public(package) fun emit_contract_upgrade_quorum_reached(epoch: u32, package_digest: vector<u8>) {
    event::emit(ContractUpgradeQuorumReached { epoch, package_digest })
}
