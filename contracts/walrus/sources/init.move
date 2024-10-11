// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::init;

use sui::clock::Clock;
use walrus::{staking, system};

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
public fun initialize_walrus(
    cap: InitCap,
    epoch_zero_duration: u64,
    epoch_duration: u64,
    n_shards: u16,
    max_epochs_ahead: u32,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    system::create_empty(max_epochs_ahead, ctx);
    staking::create(epoch_zero_duration, epoch_duration, n_shards, clock, ctx);
    cap.destroy();
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
