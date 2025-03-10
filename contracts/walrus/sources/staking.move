// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable, unused_function, unused_field, unused_mut_parameter)]
/// Module: staking
module walrus::staking;

use std::string::String;
use sui::{clock::Clock, coin::Coin, dynamic_field as df};
use wal::wal::WAL;
use walrus::{
    auth::{Self, Authenticated, Authorized},
    committee::Committee,
    node_metadata::NodeMetadata,
    staked_wal::StakedWal,
    staking_inner::{Self, StakingInnerV1},
    storage_node::{Self, StorageNodeCap},
    system::System
};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// Error during the migration of the staking object to the new package version.
const EInvalidMigration: u64 = 0;
/// The package version is not compatible with the staking object.
const EWrongVersion: u64 = 1;

/// Flag to indicate the version of the Walrus system.
const VERSION: u64 = 1;

/// The one and only staking object.
public struct Staking has key {
    id: UID,
    version: u64,
    package_id: ID,
    new_package_id: Option<ID>,
}

/// Creates and shares a new staking object.
/// Must only be called by the initialization function.
public(package) fun create(
    epoch_zero_duration: u64,
    epoch_duration: u64,
    n_shards: u16,
    package_id: ID,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let mut staking = Staking {
        id: object::new(ctx),
        version: VERSION,
        package_id,
        new_package_id: option::none(),
    };
    df::add(
        &mut staking.id,
        VERSION,
        staking_inner::new(
            epoch_zero_duration,
            epoch_duration,
            n_shards,
            clock,
            ctx,
        ),
    );
    transfer::share_object(staking)
}

// === Public API: Storage Node ===

/// Creates a staking pool for the candidate, registers the candidate as a storage node.
public fun register_candidate(
    staking: &mut Staking,
    // node info
    name: String,
    network_address: String,
    metadata: NodeMetadata,
    public_key: vector<u8>,
    network_public_key: vector<u8>,
    proof_of_possession: vector<u8>,
    // voting parameters
    commission_rate: u16,
    storage_price: u64,
    write_price: u64,
    node_capacity: u64,
    ctx: &mut TxContext,
): StorageNodeCap {
    // use the Pool Object ID as the identifier of the storage node
    let staking_mut = staking.inner_mut();
    let node_id = staking_mut.create_pool(
        name,
        network_address,
        metadata,
        public_key,
        network_public_key,
        proof_of_possession,
        commission_rate,
        storage_price,
        write_price,
        node_capacity,
        ctx,
    );

    // Switch the commission receiver from the sender (default) to the cap.
    let cap = storage_node::new_cap(node_id, ctx);
    let receiver = auth::authorized_object(object::id(&cap));
    staking_mut.set_commission_receiver(node_id, auth::authenticate_sender(ctx), receiver);
    cap
}

// === Commission ===

/// Sets next_commission in the staking pool, which will then take effect as commission rate
/// one epoch after setting the value (to allow stakers to react to setting this).
public fun set_next_commission(staking: &mut Staking, cap: &StorageNodeCap, commission_rate: u16) {
    staking.inner_mut().set_next_commission(cap, commission_rate);
}

/// Collects the commission for the node. Transaction sender must be the
/// `CommissionReceiver` for the `StakingPool`.
public fun collect_commission(
    staking: &mut Staking,
    node_id: ID,
    auth: Authenticated,
    ctx: &mut TxContext,
): Coin<WAL> {
    staking.inner_mut().collect_commission(node_id, auth).into_coin(ctx)
}

/// Sets the commission receiver for the node.
public fun set_commission_receiver(
    staking: &mut Staking,
    node_id: ID,
    auth: Authenticated,
    receiver: Authorized,
) {
    staking.inner_mut().set_commission_receiver(node_id, auth, receiver);
}

// === Governance ===

/// Sets the governance authorized object for the pool.
public fun set_governance_authorized(
    staking: &mut Staking,
    node_id: ID,
    auth: Authenticated,
    authorized: Authorized,
) {
    staking.inner_mut().set_governance_authorized(node_id, auth, authorized);
}

/// Checks if the governance authorized object matches the authenticated object.
public(package) fun check_governance_authorization(
    staking: &Staking,
    node_id: ID,
    auth: Authenticated,
): bool {
    staking.inner().check_governance_authorization(node_id, auth)
}

/// Returns the current node weight for the given node id.
public(package) fun get_current_node_weight(staking: &Staking, node_id: ID): u16 {
    staking.inner().get_current_node_weight(node_id)
}

/// Computes the committee for the next epoch.
public fun compute_next_committee(staking: &Staking): Committee {
    staking.inner().compute_next_committee()
}

// === Voting ===

/// Sets the storage price vote for the pool.
public fun set_storage_price_vote(self: &mut Staking, cap: &StorageNodeCap, storage_price: u64) {
    self.inner_mut().set_storage_price_vote(cap, storage_price);
}

/// Sets the write price vote for the pool.
public fun set_write_price_vote(self: &mut Staking, cap: &StorageNodeCap, write_price: u64) {
    self.inner_mut().set_write_price_vote(cap, write_price);
}

/// Sets the node capacity vote for the pool.
public fun set_node_capacity_vote(self: &mut Staking, cap: &StorageNodeCap, node_capacity: u64) {
    self.inner_mut().set_node_capacity_vote(cap, node_capacity);
}

// === Get/ Update Node Parameters ===

/// Get `NodeMetadata` for the given node.
public fun node_metadata(self: &Staking, node_id: ID): NodeMetadata {
    self.inner().node_metadata(node_id)
}

/// Sets the public key of a node to be used starting from the next epoch for which the node is
/// selected.
public fun set_next_public_key(
    self: &mut Staking,
    cap: &StorageNodeCap,
    public_key: vector<u8>,
    proof_of_possession: vector<u8>,
    ctx: &mut TxContext,
) {
    self.inner_mut().set_next_public_key(cap, public_key, proof_of_possession, ctx);
}

/// Sets the name of a storage node.
public fun set_name(self: &mut Staking, cap: &StorageNodeCap, name: String) {
    self.inner_mut().set_name(cap, name);
}

/// Sets the network address or host of a storage node.
public fun set_network_address(self: &mut Staking, cap: &StorageNodeCap, network_address: String) {
    self.inner_mut().set_network_address(cap, network_address);
}

/// Sets the public key used for TLS communication for a node.
public fun set_network_public_key(
    self: &mut Staking,
    cap: &StorageNodeCap,
    network_public_key: vector<u8>,
) {
    self.inner_mut().set_network_public_key(cap, network_public_key);
}

/// Sets the metadata of a storage node.
public fun set_node_metadata(self: &mut Staking, cap: &StorageNodeCap, metadata: NodeMetadata) {
    self.inner_mut().set_node_metadata(cap, metadata);
}

// === Epoch Change ===

/// Ends the voting period and runs the apportionment if the current time allows.
/// Permissionless, can be called by anyone.
/// Emits: `EpochParametersSelected` event.
public fun voting_end(staking: &mut Staking, clock: &Clock) {
    staking.inner_mut().voting_end(clock)
}

/// Initiates the epoch change if the current time allows.
/// Emits: `EpochChangeStart` event.
public fun initiate_epoch_change(staking: &mut Staking, system: &mut System, clock: &Clock) {
    let staking_inner = staking.inner_mut();
    let rewards = system.advance_epoch(
        staking_inner.next_bls_committee(),
        staking_inner.next_epoch_params(),
    );

    staking_inner.initiate_epoch_change(clock, rewards);
}

/// Signals to the contract that the node has received all its shards for the new epoch.
public fun epoch_sync_done(
    staking: &mut Staking,
    cap: &mut StorageNodeCap,
    epoch: u32,
    clock: &Clock,
) {
    staking.inner_mut().epoch_sync_done(cap, epoch, clock);
}

// === Public API: Staking ===

/// Stake `Coin` with the staking pool.
public fun stake_with_pool(
    staking: &mut Staking,
    to_stake: Coin<WAL>,
    node_id: ID,
    ctx: &mut TxContext,
): StakedWal {
    staking.inner_mut().stake_with_pool(to_stake, node_id, ctx)
}

/// Marks the amount as a withdrawal to be processed and removes it from the stake weight of the
/// node. Allows the user to call withdraw_stake after the epoch change to the next epoch and
/// shard transfer is done.
public fun request_withdraw_stake(
    staking: &mut Staking,
    staked_wal: &mut StakedWal,
    ctx: &mut TxContext,
) {
    staking.inner_mut().request_withdraw_stake(staked_wal, ctx);
}

/// Withdraws the staked amount from the staking pool.
public fun withdraw_stake(
    staking: &mut Staking,
    staked_wal: StakedWal,
    ctx: &mut TxContext,
): Coin<WAL> {
    staking.inner_mut().withdraw_stake(staked_wal, ctx)
}

/// Allows a node to join the active set if it has sufficient stake.
/// This can be useful if another node in the active had its stake
/// reduced to be lower than that of the current node.
/// In that case, the current node will be added to the active set either
/// the next time stake is added or by calling this function.
public fun try_join_active_set(staking: &mut Staking, cap: &StorageNodeCap) {
    staking.inner_mut().try_join_active_set(cap)
}

// === Accessors ===

public(package) fun package_id(staking: &Staking): ID {
    staking.package_id
}

public(package) fun version(staking: &Staking): u64 {
    staking.version
}

/// Returns the current epoch of the staking object.
public fun epoch(staking: &Staking): u32 {
    staking.inner().epoch()
}

/// Checks if the weight reaches a quorum.
public(package) fun is_quorum(staking: &Staking, weight: u16): bool {
    staking.inner().is_quorum(weight)
}

// === Utility functions ===

/// Calculate the rewards for an amount with value `staked_principal`, staked in the pool with
/// the given `node_id` between `activation_epoch` and `withdraw_epoch`.
///
/// This function can be used with `dev_inspect` to calculate the expected rewards for a `StakedWal`
/// object or, more generally, the returns provided by a given node over a given period.
public fun calculate_rewards(
    staking: &Staking,
    node_id: ID,
    staked_principal: u64,
    activation_epoch: u32,
    withdraw_epoch: u32,
): u64 {
    staking.inner().calculate_rewards(node_id, staked_principal, activation_epoch, withdraw_epoch)
}

// === Upgrade ===

public(package) fun set_new_package_id(staking: &mut Staking, new_package_id: ID) {
    staking.new_package_id = option::some(new_package_id);
}

/// Migrate the staking object to the new package id.
///
/// This function sets the new package id and version and can be modified in future versions
/// to migrate changes in the `staking_inner` object if needed.
public(package) fun migrate(staking: &mut Staking) {
    assert!(staking.version < VERSION, EInvalidMigration);

    // Move the old system state inner to the new version.
    let staking_inner: StakingInnerV1 = df::remove(&mut staking.id, staking.version);
    df::add(&mut staking.id, VERSION, staking_inner);
    staking.version = VERSION;

    // Set the new package id.
    assert!(staking.new_package_id.is_some(), EInvalidMigration);
    staking.package_id = staking.new_package_id.extract();
}

// === Internals ===

/// Get a mutable reference to `StakingInner` from the `Staking`.
fun inner_mut(staking: &mut Staking): &mut StakingInnerV1 {
    assert!(staking.version == VERSION, EWrongVersion);
    df::borrow_mut(&mut staking.id, VERSION)
}

/// Get an immutable reference to `StakingInner` from the `Staking`.
fun inner(staking: &Staking): &StakingInnerV1 {
    assert!(staking.version == VERSION, EWrongVersion);
    df::borrow(&staking.id, VERSION)
}

// === Tests ===

#[test_only]
use sui::clock;

#[test_only]
public(package) fun inner_for_testing(staking: &Staking): &StakingInnerV1 {
    staking.inner()
}

#[test_only]
public(package) fun new_for_testing(ctx: &mut TxContext): Staking {
    let clock = clock::create_for_testing(ctx);
    let mut staking = Staking {
        id: object::new(ctx),
        version: VERSION,
        package_id: new_id(ctx),
        new_package_id: option::none(),
    };
    df::add(&mut staking.id, VERSION, staking_inner::new(0, 10, 1000, &clock, ctx));
    clock.destroy_for_testing();
    staking
}

#[test_only]
public(package) fun is_epoch_sync_done(self: &Staking): bool {
    self.inner().is_epoch_sync_done()
}

#[test_only]
fun new_id(ctx: &mut TxContext): ID {
    ctx.fresh_object_address().to_id()
}

#[test_only]
public(package) fun new_package_id(staking: &Staking): Option<ID> {
    staking.new_package_id
}
