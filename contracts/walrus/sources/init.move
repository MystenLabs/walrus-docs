// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::init;

use std::type_name;
use sui::{clock::Clock, package::UpgradeCap};
use walrus::{events, staking::{Self, Staking}, system::{Self, System}, upgrade};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// Error during the migration to the new system/staking object versions.
const EInvalidMigration: u64 = 0;
/// The provided upgrade cap does not belong to this package.
const EInvalidUpgradeCap: u64 = 1;

/// Must only be created by `init`.
public struct InitCap has key, store {
    id: UID,
}

/// Init function, creates an init cap and transfers it to the sender.
/// This allows the sender to call the function to actually initialize the system
/// with the corresponding parameters. Once that function is called, the cap is destroyed.
fun init(ctx: &mut TxContext) {
    let id = object::new(ctx);
    let init_cap = InitCap { id };
    transfer::transfer(init_cap, ctx.sender());
}

/// Function to initialize walrus and share the system and staking objects.
/// This can only be called once, after which the `InitCap` is destroyed.
/// TODO: decide what to add as system parameters instead of constants.
public fun initialize_walrus(
    init_cap: InitCap,
    upgrade_cap: UpgradeCap,
    epoch_zero_duration: u64,
    epoch_duration: u64,
    n_shards: u16,
    max_epochs_ahead: u32,
    clock: &Clock,
    ctx: &mut TxContext,
): upgrade::EmergencyUpgradeCap {
    let package_id = upgrade_cap.package();
    assert!(
        type_name::get<InitCap>().get_address() == package_id.to_address().to_ascii_string(),
        EInvalidUpgradeCap,
    );
    system::create_empty(max_epochs_ahead, package_id, ctx);
    staking::create(epoch_zero_duration, epoch_duration, n_shards, package_id, clock, ctx);
    let emergency_upgrade_cap = upgrade::new(upgrade_cap, ctx);
    init_cap.destroy();
    emergency_upgrade_cap
}

/// Migrate the staking and system objects to the new package id.
///
/// This must be called in the new package after an upgrade is committed
/// to emit an event that informs all storage nodes and prevent previous package
/// versions from being used.
public fun migrate(staking: &mut Staking, system: &mut System) {
    staking.migrate();
    system.migrate();
    // Check that the package id and version are the same.
    assert!(staking.package_id() == system.package_id(), EInvalidMigration);
    assert!(staking.version() == system.version(), EInvalidMigration);
    // Emit an event to inform storage nodes of the upgrade.
    events::emit_contract_upgraded(
        staking.epoch(),
        staking.package_id(),
        staking.version(),
    );
}

fun destroy(cap: InitCap) {
    let InitCap { id } = cap;
    id.delete();
}

// === Test only ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
/// Does the same as `initialize_walrus` but does not check the package id of the upgrade cap.
///
/// This is needed for testing, since the package ID of all types will be zero, which cannot be used
/// as the package ID for an upgrade cap.
public fun initialize_for_testing(
    init_cap: InitCap,
    upgrade_cap: UpgradeCap,
    epoch_zero_duration: u64,
    epoch_duration: u64,
    n_shards: u16,
    max_epochs_ahead: u32,
    clock: &Clock,
    ctx: &mut TxContext,
): upgrade::EmergencyUpgradeCap {
    let package_id = upgrade_cap.package();
    system::create_empty(max_epochs_ahead, package_id, ctx);
    staking::create(epoch_zero_duration, epoch_duration, n_shards, package_id, clock, ctx);
    let emergency_upgrade_cap = upgrade::new(upgrade_cap, ctx);
    init_cap.destroy();
    emergency_upgrade_cap
}
