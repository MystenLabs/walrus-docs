// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::storage_accounting {
    use sui::balance::{Self, Balance};

    // Errors
    const EIndexOutOfBounds: u64 = 3;

    /// Holds information about a future epoch, namely how much
    /// storage needs to be reclaimed and the rewards to be distributed.
    public struct FutureAccounting<phantom WAL> has store {
        epoch: u64,
        storage_to_reclaim: u64,
        rewards_to_distribute: Balance<WAL>,
    }

    /// Constructor for FutureAccounting
    public fun new_future_accounting<WAL>(
        epoch: u64,
        storage_to_reclaim: u64,
        rewards_to_distribute: Balance<WAL>,
    ): FutureAccounting<WAL> {
        FutureAccounting { epoch, storage_to_reclaim, rewards_to_distribute }
    }

    /// Accessor for epoch, read-only
    public fun epoch<WAL>(accounting: &FutureAccounting<WAL>): u64 {
        *&accounting.epoch
    }

    /// Accessor for storage_to_reclaim, mutable.
    public fun storage_to_reclaim<WAL>(accounting: &mut FutureAccounting<WAL>): u64 {
        accounting.storage_to_reclaim
    }

    /// Increase storage to reclaim
    public fun increase_storage_to_reclaim<WAL>(
        accounting: &mut FutureAccounting<WAL>,
        amount: u64,
    ) {
        accounting.storage_to_reclaim = accounting.storage_to_reclaim + amount;
    }

    /// Accessor for rewards_to_distribute, mutable.
    public fun rewards_to_distribute<WAL>(
        accounting: &mut FutureAccounting<WAL>,
    ): &mut Balance<WAL> {
        &mut accounting.rewards_to_distribute
    }

    /// Destructor for FutureAccounting, when empty.
    public fun delete_empty_future_accounting<WAL>(self: FutureAccounting<WAL>) {
        let FutureAccounting {
            epoch: _,
            storage_to_reclaim: _,
            rewards_to_distribute,
        } = self;

        rewards_to_distribute.destroy_zero()
    }

    #[test_only]
    public fun burn_for_testing<WAL>(self: FutureAccounting<WAL>) {
        let FutureAccounting {
            epoch: _,
            storage_to_reclaim: _,
            rewards_to_distribute,
        } = self;

        rewards_to_distribute.destroy_for_testing();
    }

    /// A ring buffer holding future accounts for a continuous range of epochs.
    public struct FutureAccountingRingBuffer<phantom WAL> has store {
        current_index: u64,
        length: u64,
        ring_buffer: vector<FutureAccounting<WAL>>,
    }

    /// Constructor for FutureAccountingRingBuffer
    public fun ring_new<WAL>(length: u64): FutureAccountingRingBuffer<WAL> {
        let mut ring_buffer: vector<FutureAccounting<WAL>> = vector::empty();
        let mut i = 0;
        while (i < length) {
            ring_buffer.push_back(FutureAccounting {
                epoch: i,
                storage_to_reclaim: 0,
                rewards_to_distribute: balance::zero(),
            });
            i = i + 1;
        };

        FutureAccountingRingBuffer { current_index: 0, length: length, ring_buffer: ring_buffer }
    }

    /// Lookup an entry a number of epochs in the future.
    public fun ring_lookup_mut<WAL>(
        self: &mut FutureAccountingRingBuffer<WAL>,
        epochs_in_future: u64,
    ): &mut FutureAccounting<WAL> {
        // Check for out-of-bounds access.
        assert!(epochs_in_future < self.length, EIndexOutOfBounds);

        let actual_index = (epochs_in_future + self.current_index) % self.length;
        &mut self.ring_buffer[actual_index]
    }

    public fun ring_pop_expand<WAL>(
        self: &mut FutureAccountingRingBuffer<WAL>,
    ): FutureAccounting<WAL> {
        // Get current epoch
        let current_index = self.current_index;
        let current_epoch = self.ring_buffer[current_index].epoch;

        // Expand the ring buffer
        self
            .ring_buffer
            .push_back(FutureAccounting {
                epoch: current_epoch + self.length,
                storage_to_reclaim: 0,
                rewards_to_distribute: balance::zero(),
            });

        // Now swap remove the current element and increment the current_index
        let accounting = self.ring_buffer.swap_remove(current_index);
        self.current_index = (current_index + 1) % self.length;

        accounting
    }
}
