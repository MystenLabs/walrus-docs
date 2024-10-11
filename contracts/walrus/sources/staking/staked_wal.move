// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: `staked_wal`
///
/// Implements the `StakedWal` functionality - a staked WAL is an object that
/// represents a staked amount of WALs in a staking pool. It is created in the
/// `staking_pool` on staking and can be split, joined, and burned. The burning
/// is performed via the `withdraw_stake` method in the `staking_pool`.
module walrus::staked_wal;

use sui::balance::Balance;
use wal::wal::WAL;

// Keep errors in `walrus-sui/types/move_errors.rs` up to date with changes here.
const ENotWithdrawing: u64 = 0;
const EMetadataMismatch: u64 = 1;
const EInvalidAmount: u64 = 2;
const ENonZeroPrincipal: u64 = 3;
const ECantJoinWithdrawing: u64 = 4;
const ECantSplitWithdrawing: u64 = 5;

/// The state of the staked WAL. It can be either `Staked` or `Withdrawing`.
/// The `Withdrawing` state contains the epoch when the staked WAL can be
///
public enum StakedWalState has store, copy, drop {
    // Default state of the staked WAL - it is staked in the staking pool.
    Staked,
    // The staked WAL is in the process of withdrawing. The value inside the
    // variant is the epoch when the staked WAL can be withdrawn.
    Withdrawing { withdraw_epoch: u32, pool_token_amount: u64 },
}

/// Represents a staked WAL, does not store the `Balance` inside, but uses
/// `u64` to represent the staked amount. Behaves similarly to `Balance` and
/// `Coin` providing methods to `split` and `join`.
public struct StakedWal has key, store {
    id: UID,
    /// Whether the staked WAL is active or withdrawing.
    state: StakedWalState,
    /// ID of the staking pool.
    node_id: ID,
    /// The staked amount.
    principal: Balance<WAL>,
    /// The Walrus epoch when the staked WAL was activated.
    activation_epoch: u32,
}

/// Protected method to create a new staked WAL.
public(package) fun mint(
    node_id: ID,
    principal: Balance<WAL>,
    activation_epoch: u32,
    ctx: &mut TxContext,
): StakedWal {
    StakedWal {
        id: object::new(ctx),
        state: StakedWalState::Staked,
        node_id,
        principal,
        activation_epoch,
    }
}

/// Burns the staked WAL and returns the `principal`.
public(package) fun into_balance(sw: StakedWal): Balance<WAL> {
    let StakedWal { id, principal, .. } = sw;
    id.delete();
    principal
}

/// Sets the staked WAL state to `Withdrawing`
public(package) fun set_withdrawing(
    sw: &mut StakedWal,
    withdraw_epoch: u32,
    pool_token_amount: u64,
) {
    sw.state = StakedWalState::Withdrawing { withdraw_epoch, pool_token_amount };
}

// === Accessors ===

/// Returns the `node_id` of the staked WAL.
public fun node_id(sw: &StakedWal): ID { sw.node_id }

/// Returns the `principal` of the staked WAL. Called `value` to be consistent
/// with `Coin`.
public fun value(sw: &StakedWal): u64 { sw.principal.value() }

/// Returns the `activation_epoch` of the staked WAL.
public fun activation_epoch(sw: &StakedWal): u32 { sw.activation_epoch }

/// Returns true if the staked WAL is in the `Staked` state.
public fun is_staked(sw: &StakedWal): bool { sw.state == StakedWalState::Staked }

/// Checks whether the staked WAL is in the `Withdrawing` state.
public fun is_withdrawing(sw: &StakedWal): bool {
    match (sw.state) {
        StakedWalState::Withdrawing { .. } => true,
        _ => false,
    }
}

/// Returns the `withdraw_epoch` of the staked WAL if it is in the `Withdrawing`.
/// Aborts otherwise.
public fun withdraw_epoch(sw: &StakedWal): u32 {
    match (sw.state) {
        StakedWalState::Withdrawing { withdraw_epoch, .. } => withdraw_epoch,
        _ => abort ENotWithdrawing,
    }
}

/// Return the `withdraw_amount` of the staked WAL if it is in the `Withdrawing`.
/// Aborts otherwise.
public fun pool_token_amount(sw: &StakedWal): u64 {
    match (sw.state) {
        StakedWalState::Withdrawing { pool_token_amount, .. } => pool_token_amount,
        _ => abort ENotWithdrawing,
    }
}

// === Public APIs ===

/// Joins the staked WAL with another staked WAL, adding the `principal` of the
/// `other` staked WAL to the current staked WAL.
///
/// Aborts if the `node_id` or `activation_epoch` of the staked WALs do not match.
public fun join(sw: &mut StakedWal, other: StakedWal) {
    let StakedWal { id, state, node_id, activation_epoch, principal } = other;
    assert!(sw.state == state, EMetadataMismatch);
    assert!(sw.node_id == node_id, EMetadataMismatch);
    assert!(!sw.is_withdrawing(), ECantJoinWithdrawing);
    assert!(sw.activation_epoch == activation_epoch, EMetadataMismatch);

    id.delete();

    sw.principal.join(principal);
}

/// Splits the staked WAL into two parts, one with the `amount` and the other
/// with the remaining `principal`. The `node_id`, `activation_epoch` are the
/// same for both the staked WALs.
///
/// Aborts if the `amount` is greater than the `principal` of the staked WAL.
public fun split(sw: &mut StakedWal, amount: u64, ctx: &mut TxContext): StakedWal {
    assert!(sw.principal.value() >= amount, EInvalidAmount);
    assert!(!sw.is_withdrawing(), ECantSplitWithdrawing);

    StakedWal {
        id: object::new(ctx),
        state: sw.state, // state is preserved
        node_id: sw.node_id,
        principal: sw.principal.split(amount),
        activation_epoch: sw.activation_epoch,
    }
}

/// Destroys the staked WAL if the `principal` is zero. Ignores the `node_id`
/// and `activation_epoch` of the staked WAL given that it is zero.
public fun destroy_zero(sw: StakedWal) {
    assert!(sw.principal.value() == 0, ENonZeroPrincipal);
    let StakedWal { id, principal, .. } = sw;
    principal.destroy_zero();
    id.delete();
}

#[test_only]
public fun destroy_for_testing(sw: StakedWal) {
    let StakedWal { id, principal, .. } = sw;
    principal.destroy_for_testing();
    id.delete();
}
