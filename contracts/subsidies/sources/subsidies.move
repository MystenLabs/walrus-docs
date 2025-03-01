// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: `subsidies`
///
/// Module to manage a shared subsidy pool, allowing for discounted
/// storage costs for buyers and contributing to a subsidy for storage nodes.
/// It provides functionality to:
///  - Add funds to the shared subsidy pool.
///  - Set subsidy rates for buyers and storage nodes.
///  - Apply subsidies when reserving storage or extending blob lifetimes.
module subsidies::subsidies;

use sui::{balance::{Self, Balance}, coin::Coin};
use wal::wal::WAL;
use walrus::{blob::Blob, storage_resource::Storage, system::System};

/// Track the current version of the module
const VERSION: u64 = 2;

/// Subsidy rate is in basis points (1/100 of a percent).
const MAX_SUBSIDY_RATE: u16 = 10_000; // 100%

// === Errors ===
/// The provided subsidy rate is invalid.
const EInvalidSubsidyRate: u64 = 0;
/// The admin cap is not authorized for the `Subsidies` object.
const EUnauthorizedAdminCap: u64 = 1;
/// The package version is not compatible with the `Subsidies` object.
const EWrongVersion: u64 = 2;

// === Structs ===

/// Capability to perform admin operations, tied to a specific Subsidies object.
///
/// Only the holder of this capability can modify subsidy rates
public struct AdminCap has key, store {
    id: UID,
    subsidies_id: ID,
}

/// Subsidy rates are expressed in basis points (1/100 of a percent).
/// A subsidy rate of 100 basis points means a 1% subsidy.
/// The maximum subsidy rate is 10,000 basis points (100%).
public struct Subsidies has key, store {
    id: UID,
    /// The subsidy rate applied to the buyer at the moment of storage purchase
    /// in basis points.
    buyer_subsidy_rate: u16,
    /// The subsidy rate applied to the storage node when buying storage in basis
    /// points.
    system_subsidy_rate: u16,
    /// The balance of funds available in the subsidy pool.
    subsidy_pool: Balance<WAL>,
    /// Package ID of the subsidies contract.
    package_id: ID,
    /// The version of the subsidies contract.
    version: u64,
}

/// Creates a new `Subsidies` object and an `AdminCap`.
public fun new(package_id: ID, ctx: &mut TxContext): AdminCap {
    let subsidies = Subsidies {
        id: object::new(ctx),
        buyer_subsidy_rate: 0,
        system_subsidy_rate: 0,
        package_id,
        subsidy_pool: balance::zero(),
        version: VERSION,
    };
    let admin_cap = AdminCap { id: object::new(ctx), subsidies_id: object::id(&subsidies) };
    transfer::share_object(subsidies);
    admin_cap
}

/// Creates a new `Subsidies` object with initial rates and funds and an `AdminCap`.
public fun new_with_initial_rates_and_funds(
    package_id: ID,
    initial_buyer_subsidy_rate: u16,
    initial_system_subsidy_rate: u16,
    initial_funds: Coin<WAL>,
    ctx: &mut TxContext,
): AdminCap {
    assert!(initial_buyer_subsidy_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    assert!(initial_system_subsidy_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    let subsidies = Subsidies {
        id: object::new(ctx),
        buyer_subsidy_rate: initial_buyer_subsidy_rate,
        system_subsidy_rate: initial_system_subsidy_rate,
        subsidy_pool: initial_funds.into_balance(),
        package_id,
        version: VERSION,
    };
    let admin_cap = AdminCap { id: object::new(ctx), subsidies_id: object::id(&subsidies) };
    transfer::share_object(subsidies);
    admin_cap
}

/// Add additional funds to the subsidy pool.
///
/// These funds will be used to provide discounts for buyers
/// and rewards to storage nodes.
public fun add_funds(self: &mut Subsidies, funds: Coin<WAL>) {
    self.subsidy_pool.join(funds.into_balance());
}

/// Check if the admin cap is valid for this subsidies object.
///
/// Aborts if the cap does not match.
fun check_admin(self: &Subsidies, admin_cap: &AdminCap) {
    assert!(object::id(self) == admin_cap.subsidies_id, EUnauthorizedAdminCap);
}

fun check_version_upgrade(self: &Subsidies) {
    assert!(self.version < VERSION, EWrongVersion);
}

/// Set the subsidy rate for buyers, in basis points.
///
/// Aborts if new_rate is greater than the max value.
public fun set_buyer_subsidy_rate(self: &mut Subsidies, cap: &AdminCap, new_rate: u16) {
    check_admin(self, cap);
    assert!(new_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    self.buyer_subsidy_rate = new_rate;
}

/// Set the subsidy rate for storage nodes, in basis points.
///
/// Aborts if new_rate is greater than the max value.
public fun set_system_subsidy_rate(self: &mut Subsidies, cap: &AdminCap, new_rate: u16) {
    check_admin(self, cap);
    assert!(new_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    self.system_subsidy_rate = new_rate;
}

/// Applies subsidies and sends rewards to the system.
///
/// This will deduct funds from the subsidy pool,
/// and send the storage node subsidy to the system.
fun apply_subsidies(
    self: &mut Subsidies,
    cost: u64,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
    system: &mut System,
    ctx: &mut TxContext,
) {
    // Return early if the subsidy pool is empty.
    if (self.subsidy_pool.value() == 0) {
        return
    };

    let buyer_subsidy = cost * (self.buyer_subsidy_rate as u64) / (MAX_SUBSIDY_RATE as u64);
    let system_subsidy = cost * (self.system_subsidy_rate as u64) / (MAX_SUBSIDY_RATE as u64);
    let total_subsidy = buyer_subsidy + system_subsidy;

    // Apply subsidy up to the available amount in the pool.
    let (buyer_subsidy, system_subsidy) = if (self.subsidy_pool.value() >= total_subsidy) {
        (buyer_subsidy, system_subsidy)
    } else {
        // If we don't have enough in the pool to pay the full subsidies,
        // split the remainder proportionally between the buyer and system subsidies.
        let pool_value = self.subsidy_pool.value();
        let total_subsidy_rate = self.buyer_subsidy_rate + self.system_subsidy_rate;
        let buyer_subsidy =
            pool_value * (self.buyer_subsidy_rate as u64) / (total_subsidy_rate as u64);
        let system_subsidy =
            pool_value * (self.system_subsidy_rate as u64) / (total_subsidy_rate as u64);
        (buyer_subsidy, system_subsidy)
    };
    let buyer_subsidy_coin = self.subsidy_pool.split(buyer_subsidy).into_coin(ctx);
    payment.join(buyer_subsidy_coin);

    let system_subsidy_coin = self.subsidy_pool.split(system_subsidy).into_coin(ctx);
    system.add_subsidy(system_subsidy_coin, epochs_ahead)
}

/// Extends a blob's lifetime and applies the buyer and storage node subsidies.
///
/// It first extends the blob lifetime using system `extend_blob` method.
/// Then it applies the subsidies and deducts the funds from the subsidy pool.
public fun extend_blob(
    self: &mut Subsidies,
    system: &mut System,
    blob: &mut Blob,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
) {
    assert!(self.version == VERSION, EWrongVersion);
    let initial_payment_value = payment.value();
    system.extend_blob(blob, epochs_ahead, payment);
    self.apply_subsidies(
        initial_payment_value - payment.value(),
        epochs_ahead,
        payment,
        system,
        ctx,
    );
}

/// Reserves storage space and applies the buyer and storage node subsidies.
///
/// It first reserves the space using system `reserve_space` method.
/// Then it applies the subsidies and deducts the funds from the subsidy pool.
public fun reserve_space(
    self: &mut Subsidies,
    system: &mut System,
    storage_amount: u64,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Storage {
    assert!(self.version == VERSION, EWrongVersion);
    let initial_payment_value = payment.value();
    let storage = system.reserve_space(storage_amount, epochs_ahead, payment, ctx);
    self.apply_subsidies(
        initial_payment_value - payment.value(),
        epochs_ahead,
        payment,
        system,
        ctx,
    );
    storage
}

entry fun migrate(subsidies: &mut Subsidies, admin_cap: &AdminCap, package_id: ID) {
    check_admin(subsidies, admin_cap);
    check_version_upgrade(subsidies);
    subsidies.version = VERSION;
    subsidies.package_id = package_id;
}

// === Accessors ===

public fun admin_cap_subsidies_id(admin_cap: &AdminCap): ID {
    admin_cap.subsidies_id
}

/// Returns the current value of the subsidy pool.
public fun subsidy_pool_value(self: &Subsidies): u64 {
    self.subsidy_pool.value()
}

/// Returns the current rate for buyer subsidies.
public fun buyer_subsidy_rate(self: &Subsidies): u16 {
    self.buyer_subsidy_rate
}

/// Returns the current rate for storage node subsidies.
public fun system_subsidy_rate(self: &Subsidies): u16 {
    self.system_subsidy_rate
}

// === Tests ===

#[test_only]
use sui::test_utils::destroy;

#[test_only]
public fun get_subsidy_pool(self: &Subsidies): &Balance<WAL> {
    &self.subsidy_pool
}

#[test_only]
public fun new_for_testing(ctx: &mut TxContext): (Subsidies, AdminCap) {
    let package_id = object::new(ctx);
    let subsidies = Subsidies {
        id: object::new(ctx),
        buyer_subsidy_rate: 0,
        system_subsidy_rate: 0,
        subsidy_pool: balance::zero(),
        package_id: package_id.to_inner(),
        version: VERSION,
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
        subsidies_id: object::id(&subsidies),
    };
    object::delete(package_id);
    (subsidies, admin_cap)
}

#[test_only]
public fun new_with_initial_rates_and_funds_for_testing(
    initial_buyer_subsidy_rate: u16,
    initial_system_subsidy_rate: u16,
    initial_funds: Coin<WAL>,
    ctx: &mut TxContext,
): (Subsidies, AdminCap) {
    assert!(initial_buyer_subsidy_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    assert!(initial_system_subsidy_rate <= MAX_SUBSIDY_RATE, EInvalidSubsidyRate);
    let package_id = object::new(ctx);
    let subsidies = Subsidies {
        id: object::new(ctx),
        buyer_subsidy_rate: initial_buyer_subsidy_rate,
        system_subsidy_rate: initial_system_subsidy_rate,
        subsidy_pool: initial_funds.into_balance(),
        version: VERSION,
        package_id: package_id.to_inner(),
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
        subsidies_id: object::id(&subsidies),
    };
    object::delete(package_id);
    (subsidies, admin_cap)
}

#[test_only]
public fun destroy_admin_cap(admin_cap: AdminCap) {
    destroy(admin_cap);
}

#[test_only]
public fun destroy_subsidies(subsidies: Subsidies) {
    destroy(subsidies);
}
