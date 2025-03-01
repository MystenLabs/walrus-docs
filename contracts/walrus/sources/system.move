// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable, unused_function, unused_field, unused_mut_parameter)]
/// Module: system
module walrus::system;

use sui::{balance::Balance, coin::Coin, dynamic_field, vec_map::VecMap};
use wal::wal::WAL;
use walrus::{
    blob::Blob,
    bls_aggregate::BlsCommittee,
    epoch_parameters::EpochParams,
    storage_node::StorageNodeCap,
    storage_resource::Storage,
    system_state_inner::{Self, SystemStateInnerV1}
};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// Error during the migration of the system object to the new package version.
const EInvalidMigration: u64 = 0;
/// The package version is not compatible with the system object.
const EWrongVersion: u64 = 1;

/// Flag to indicate the version of the system.
const VERSION: u64 = 2;

/// The one and only system object.
public struct System has key {
    id: UID,
    version: u64,
    package_id: ID,
    new_package_id: Option<ID>,
}

/// Creates and shares an empty system object.
/// Must only be called by the initialization function.
public(package) fun create_empty(max_epochs_ahead: u32, package_id: ID, ctx: &mut TxContext) {
    let mut system = System {
        id: object::new(ctx),
        version: VERSION,
        package_id,
        new_package_id: option::none(),
    };
    let system_state_inner = system_state_inner::create_empty(max_epochs_ahead, ctx);
    dynamic_field::add(&mut system.id, VERSION, system_state_inner);
    transfer::share_object(system);
}

/// Marks blob as invalid given an invalid blob certificate.
public fun invalidate_blob_id(
    system: &System,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
): u256 {
    system.inner().invalidate_blob_id(signature, members_bitmap, message)
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
    signers_bitmap: vector<u8>,
    message: vector<u8>,
) {
    self.inner().certify_blob(blob, signature, signers_bitmap, message);
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

/// Extend the period of validity of a blob by extending its contained storage resource
/// by `extended_epochs` epochs.
public fun extend_blob(
    self: &mut System,
    blob: &mut Blob,
    extended_epochs: u32,
    payment: &mut Coin<WAL>,
) {
    self.inner_mut().extend_blob(blob, extended_epochs, payment);
}

/// Adds rewards to the system for the specified number of epochs ahead.
/// The rewards are split equally across the future accounting ring buffer up to the
/// specified epoch.
public fun add_subsidy(system: &mut System, subsidy: Coin<WAL>, epochs_ahead: u32) {
    system.inner_mut().add_subsidy(subsidy, epochs_ahead)
}

// === Deny List Features ===

/// Register a deny list update.
public fun register_deny_list_update(
    self: &mut System,
    cap: &StorageNodeCap,
    deny_list_root: u256,
    deny_list_sequence: u64,
) {
    self.inner_mut().register_deny_list_update(cap, deny_list_root, deny_list_sequence)
}

/// Perform the update of the deny list.
public fun update_deny_list(
    self: &mut System,
    cap: &mut StorageNodeCap,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
) {
    self.inner_mut().update_deny_list(cap, signature, members_bitmap, message)
}

/// Delete a blob that is deny listed by f+1 members.
public fun delete_deny_listed_blob(
    self: &System,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
) {
    self.inner().delete_deny_listed_blob(signature, members_bitmap, message)
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

/// Update epoch to next epoch, and update the committee, price and capacity.
///
/// Called by the epoch change function that connects `Staking` and `System`. Returns
/// the balance of the rewards from the previous epoch.
public(package) fun advance_epoch(
    self: &mut System,
    new_committee: BlsCommittee,
    new_epoch_params: &EpochParams,
): VecMap<ID, Balance<WAL>> {
    self.inner_mut().advance_epoch(new_committee, new_epoch_params)
}

// === Accessors ===

public(package) fun package_id(system: &System): ID {
    system.package_id
}

public(package) fun version(system: &System): u64 {
    system.version
}

// === Upgrade ===

public(package) fun set_new_package_id(system: &mut System, new_package_id: ID) {
    system.new_package_id = option::some(new_package_id);
}

/// Migrate the system object to the new package id.
///
/// This function sets the new package id and version and can be modified in future versions
/// to migrate changes in the `system_state_inner` object if needed.
public(package) fun migrate(system: &mut System) {
    assert!(system.version < VERSION, EInvalidMigration);

    // Move the old system state inner to the new version.
    let system_state_inner: SystemStateInnerV1 = dynamic_field::remove(
        &mut system.id,
        system.version,
    );
    dynamic_field::add(&mut system.id, VERSION, system_state_inner);
    system.version = VERSION;

    // Set the new package id.
    assert!(system.new_package_id.is_some(), EInvalidMigration);
    system.package_id = system.new_package_id.extract();
}

// === Internals ===

/// Get a mutable reference to `SystemStateInner` from the `System`.
fun inner_mut(system: &mut System): &mut SystemStateInnerV1 {
    assert!(system.version == VERSION, EWrongVersion);
    dynamic_field::borrow_mut(&mut system.id, VERSION)
}

/// Get an immutable reference to `SystemStateInner` from the `System`.
public(package) fun inner(system: &System): &SystemStateInnerV1 {
    assert!(system.version == VERSION, EWrongVersion);
    dynamic_field::borrow(&system.id, VERSION)
}

// === Testing ===

#[test_only]
/// Accessor for the current committee.
public(package) fun committee(self: &System): &BlsCommittee {
    self.inner().committee()
}

#[test_only]
public(package) fun committee_mut(self: &mut System): &mut BlsCommittee {
    self.inner_mut().committee_mut()
}

#[test_only]
public fun new_for_testing(ctx: &mut TxContext): System {
    let mut system = System {
        id: object::new(ctx),
        version: VERSION,
        package_id: new_id(ctx),
        new_package_id: option::none(),
    };
    let system_state_inner = system_state_inner::new_for_testing();
    dynamic_field::add(&mut system.id, VERSION, system_state_inner);
    system
}

#[test_only]
public(package) fun new_for_testing_with_multiple_members(ctx: &mut TxContext): System {
    let mut system = System {
        id: object::new(ctx),
        version: VERSION,
        package_id: new_id(ctx),
        new_package_id: option::none(),
    };
    let system_state_inner = system_state_inner::new_for_testing_with_multiple_members(ctx);
    dynamic_field::add(&mut system.id, VERSION, system_state_inner);
    system
}

#[test_only]
fun new_id(ctx: &mut TxContext): ID {
    ctx.fresh_object_address().to_id()
}

#[test_only]
public(package) fun new_package_id(system: &System): Option<ID> {
    system.new_package_id
}

#[test_only]
public(package) fun destroy_for_testing(self: System) {
    sui::test_utils::destroy(self);
}
