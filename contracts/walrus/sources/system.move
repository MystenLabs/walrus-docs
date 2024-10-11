// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable, unused_function, unused_field, unused_mut_parameter)]
/// Module: system
module walrus::system;

use sui::{balance::Balance, coin::Coin, dynamic_object_field};
use wal::wal::WAL;
use walrus::{
    blob::Blob,
    bls_aggregate::BlsCommittee,
    epoch_parameters::EpochParams,
    storage_node::StorageNodeCap,
    storage_resource::Storage,
    system_state_inner::{Self, SystemStateInnerV1}
};

/// Flag to indicate the version of the system.
const VERSION: u64 = 0;

/// The one and only system object.
public struct System has key {
    id: UID,
    version: u64,
}

/// Creates and shares an empty system object.
/// Must only be called by the initialization function.
public(package) fun create_empty(max_epochs_ahead: u32, ctx: &mut TxContext) {
    let mut system = System { id: object::new(ctx), version: VERSION };
    let system_state_inner = system_state_inner::create_empty(max_epochs_ahead, ctx);
    dynamic_object_field::add(&mut system.id, VERSION, system_state_inner);
    transfer::share_object(system);
}

/// Marks blob as invalid given an invalid blob certificate.
public fun invalidate_blob_id(
    system: &System,
    signature: vector<u8>,
    members: vector<u16>,
    message: vector<u8>,
): u256 {
    system.inner().invalidate_blob_id(signature, members, message)
}

/// Certifies a blob containing Walrus events.
public fun certify_event_blob(
    system: &mut System,
    cap: &mut StorageNodeCap,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    ending_checkpoint_sequence_num: u64,
    epoch: u32,
    ctx: &mut TxContext,
) {
    system
        .inner_mut()
        .certify_event_blob(
            cap,
            blob_id,
            root_hash,
            size,
            encoding_type,
            ending_checkpoint_sequence_num,
            epoch,
            ctx,
        )
}

/// Allows buying a storage reservation for a given period of epochs.
public fun reserve_space(
    self: &mut System,
    storage_amount: u64,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Storage {
    self.inner_mut().reserve_space(storage_amount, epochs_ahead, payment, ctx)
}

/// Registers a new blob in the system.
/// `size` is the size of the unencoded blob. The reserved space in `storage` must be at
/// least the size of the encoded blob.
public fun register_blob(
    self: &mut System,
    storage: Storage,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    deletable: bool,
    write_payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Blob {
    self
        .inner_mut()
        .register_blob(
            storage,
            blob_id,
            root_hash,
            size,
            encoding_type,
            deletable,
            write_payment,
            ctx,
        )
}

/// Certify that a blob will be available in the storage system until the end epoch of the
/// storage associated with it.
public fun certify_blob(
    self: &System,
    blob: &mut Blob,
    signature: vector<u8>,
    signers: vector<u16>,
    message: vector<u8>,
) {
    self.inner().certify_blob(blob, signature, signers, message);
}

/// Deletes a deletable blob and returns the contained storage resource.
public fun delete_blob(self: &System, blob: Blob): Storage {
    self.inner().delete_blob(blob)
}

/// Extend the period of validity of a blob with a new storage resource.
/// The new storage resource must be the same size as the storage resource
/// used in the blob, and have a longer period of validity.
public fun extend_blob_with_resource(self: &System, blob: &mut Blob, extension: Storage) {
    self.inner().extend_blob_with_resource(blob, extension);
}

/// Extend the period of validity of a blob by extending its contained storage resource.
public fun extend_blob(
    self: &mut System,
    blob: &mut Blob,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
) {
    self.inner_mut().extend_blob(blob, epochs_ahead, payment);
}

// === Public Accessors ===

/// Get epoch. Uses the committee to get the epoch.
public fun epoch(self: &System): u32 {
    self.inner().epoch()
}

/// Accessor for total capacity size.
public fun total_capacity_size(self: &System): u64 {
    self.inner().total_capacity_size()
}

/// Accessor for used capacity size.
public fun used_capacity_size(self: &System): u64 {
    self.inner().used_capacity_size()
}

/// Accessor for the number of shards.
public fun n_shards(self: &System): u16 {
    self.inner().n_shards()
}

// === Restricted to Package ===

/// Accessor for the current committee.
public(package) fun committee(self: &System): &BlsCommittee {
    self.inner().committee()
}

#[test_only]
public(package) fun committee_mut(self: &mut System): &mut BlsCommittee {
    self.inner_mut().committee_mut()
}

/// Update epoch to next epoch, and update the committee, price and capacity.
///
/// Called by the epoch change function that connects `Staking` and `System`. Returns
/// the balance of the rewards from the previous epoch.
public(package) fun advance_epoch(
    self: &mut System,
    new_committee: BlsCommittee,
    new_epoch_params: EpochParams,
): Balance<WAL> {
    self.inner_mut().advance_epoch(new_committee, new_epoch_params)
}

// === Internals ===

/// Get a mutable reference to `SystemStateInner` from the `System`.
fun inner_mut(system: &mut System): &mut SystemStateInnerV1 {
    assert!(system.version == VERSION);
    dynamic_object_field::borrow_mut(&mut system.id, VERSION)
}

/// Get an immutable reference to `SystemStateInner` from the `System`.
public(package) fun inner(system: &System): &SystemStateInnerV1 {
    assert!(system.version == VERSION);
    dynamic_object_field::borrow(&system.id, VERSION)
}

// === Testing ===

#[test_only]
public(package) fun new_for_testing(): System {
    let ctx = &mut tx_context::dummy();
    let mut system = System { id: object::new(ctx), version: VERSION };
    let system_state_inner = system_state_inner::new_for_testing();
    dynamic_object_field::add(&mut system.id, VERSION, system_state_inner);
    system
}

#[test_only]
public(package) fun new_for_testing_with_multiple_members(ctx: &mut TxContext): System {
    let mut system = System { id: object::new(ctx), version: VERSION };
    let system_state_inner = system_state_inner::new_for_testing_with_multiple_members(ctx);
    dynamic_object_field::add(&mut system.id, VERSION, system_state_inner);
    system
}
