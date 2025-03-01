// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::storage_accounting;

use sui::balance::{Self, Balance};
use wal::wal::WAL;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// Trying to access an epoch that is too far in the future.
const ETooFarInFuture: u64 = 0;

/// Holds information about a future epoch, namely how much
/// storage needs to be reclaimed and the rewards to be distributed.
public struct FutureAccounting has store {
    epoch: u32,
    /// This field stores `used_capacity` for the epoch.
    /// Currently, impossible to rename due to package upgrade limitations.
    storage_to_reclaim: u64,
    rewards_to_distribute: Balance<WAL>,
}

/// Constructor for FutureAccounting
public(package) fun new_future_accounting(
    epoch: u32,
    used_capacity: u64,
    rewards_to_distribute: Balance<WAL>,
): FutureAccounting {
    FutureAccounting { epoch, storage_to_reclaim: used_capacity, rewards_to_distribute }
}

/// Accessor for epoch, read-only
public(package) fun epoch(accounting: &FutureAccounting): u32 {
    *&accounting.epoch
}

/// Accessor for used_capacity, read-only.
public(package) fun used_capacity(accounting: &FutureAccounting): u64 {
    accounting.storage_to_reclaim
}

/// Increase `used_capacity` by `amount`.
public(package) fun increase_used_capacity(accounting: &mut FutureAccounting, amount: u64): u64 {
    accounting.storage_to_reclaim = accounting.storage_to_reclaim + amount;
    accounting.storage_to_reclaim
}

/// Accessor for rewards_to_distribute, mutable.
public(package) fun rewards_balance(accounting: &mut FutureAccounting): &mut Balance<WAL> {
    &mut accounting.rewards_to_distribute
}

/// Destructor for FutureAccounting, when empty.
public(package) fun delete_empty_future_accounting(self: FutureAccounting) {
    self.unwrap_balance().destroy_zero()
}

public(package) fun unwrap_balance(self: FutureAccounting): Balance<WAL> {
    let FutureAccounting { rewards_to_distribute, .. } = self;
    rewards_to_distribute
}

#[test_only]
public(package) fun burn_for_testing(self: FutureAccounting) {
    self.unwrap_balance().destroy_for_testing();
}

/// A ring buffer holding future accounts for a continuous range of epochs.
public struct FutureAccountingRingBuffer has store {
    current_index: u32,
    length: u32,
    ring_buffer: vector<FutureAccounting>,
}

/// Constructor for FutureAccountingRingBuffer
public(package) fun ring_new(length: u32): FutureAccountingRingBuffer {
    let ring_buffer = vector::tabulate!(
        length as u64,
        |epoch| FutureAccounting {
            epoch: epoch as u32,
            storage_to_reclaim: 0,
            rewards_to_distribute: balance::zero(),
        },
    );

    FutureAccountingRingBuffer { current_index: 0, length, ring_buffer }
}

#[test_only]
public(package) fun ring_lookup(
    self: &FutureAccountingRingBuffer,
    epochs_in_future: u32,
): &FutureAccounting {
    // Check for out-of-bounds access.
    assert!(epochs_in_future < self.length, ETooFarInFuture);

    let actual_index = (epochs_in_future + self.current_index) % self.length;
    &self.ring_buffer[actual_index as u64]
}

/// Lookup an entry a number of epochs in the future.
public(package) fun ring_lookup_mut(
    self: &mut FutureAccountingRingBuffer,
    epochs_in_future: u32,
): &mut FutureAccounting {
    // Check for out-of-bounds access.
    assert!(epochs_in_future < self.length, ETooFarInFuture);

    let actual_index = (epochs_in_future + self.current_index) % self.length;
    &mut self.ring_buffer[actual_index as u64]
}

public(package) fun ring_pop_expand(self: &mut FutureAccountingRingBuffer): FutureAccounting {
    // Get current epoch
    let current_index = self.current_index;
    let current_epoch = self.ring_buffer[current_index as u64].epoch;

    // Expand the ring buffer
    self
        .ring_buffer
        .push_back(FutureAccounting {
            epoch: current_epoch + self.length,
            storage_to_reclaim: 0,
            rewards_to_distribute: balance::zero(),
        });

    // Now swap remove the current element and increment the current_index
    let accounting = self.ring_buffer.swap_remove(current_index as u64);
    self.current_index = (current_index + 1) % self.length;

    accounting
}

// === Accessors ===

/// The maximum number of epochs for which we can use `self`.
public(package) fun max_epochs_ahead(self: &FutureAccountingRingBuffer): u32 {
    self.length
}
