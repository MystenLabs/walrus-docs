// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::pending_values;

use sui::vec_map::{Self, VecMap};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// No value for the provided epoch exists.
const EMissingEpochValue: u64 = 0;
/// The value that the pending values should be reduced by for an epoch is too large.
const EReduceValueTooLarge: u64 = 1;

/// Represents a map of pending values. The key is the epoch when the value is
/// pending, and the value is the amount of WALs or pool shares.
public struct PendingValues(VecMap<u32, u64>) has copy, drop, store;

/// Create a new empty `PendingValues` instance.
public(package) fun empty(): PendingValues { PendingValues(vec_map::empty()) }

/// Insert a new pending value for the given epoch, or add to the existing value.
public(package) fun insert_or_add(self: &mut PendingValues, epoch: u32, value: u64) {
    let map = &mut self.0;
    if (!map.contains(&epoch)) {
        map.insert(epoch, value);
    } else {
        let curr = map[&epoch];
        *&mut map[&epoch] = curr + value;
    };
}

/// Insert a new pending value for the given epoch, or replace the existing.
public(package) fun insert_or_replace(self: &mut PendingValues, epoch: u32, value: u64) {
    let map = &mut self.0;
    if (!map.contains(&epoch)) {
        map.insert(epoch, value);
    } else {
        *&mut map[&epoch] = value;
    };
}

/// Reduce the pending value for the given epoch by the given value.
public(package) fun reduce(self: &mut PendingValues, epoch: u32, value: u64) {
    let map = &mut self.0;
    if (!map.contains(&epoch)) {
        abort EMissingEpochValue
    } else {
        let curr = map[&epoch];
        assert!(curr >= value, EReduceValueTooLarge);
        *&mut map[&epoch] = curr - value;
    };
}

/// Get the total value of the pending values up to the given epoch.
public(package) fun value_at(self: &PendingValues, epoch: u32): u64 {
    self.0.keys().fold!(0, |mut value, e| {
        if (e <= epoch) value = value + self.0[&e];
        value
    })
}

/// Reduce the pending values to the given epoch. This method removes all the
/// values that are pending for epochs less than or equal to the given epoch.
public(package) fun flush(self: &mut PendingValues, to_epoch: u32): u64 {
    let mut value = 0;
    self.0.keys().do!(|epoch| if (epoch <= to_epoch) {
        let (_, epoch_value) = self.0.remove(&epoch);
        value = value + epoch_value;
    });
    value
}

/// Get a reference to the inner `VecMap<u32, u64>`.
public(package) fun inner(self: &PendingValues): &VecMap<u32, u64> { &self.0 }

/// Get a mutable reference to the inner `VecMap<u32, u64>`.
public(package) fun inner_mut(self: &mut PendingValues): &mut VecMap<u32, u64> { &mut self.0 }

/// Unwrap the `PendingValues` into a `VecMap<u32, u64>`.
public(package) fun unwrap(self: PendingValues): VecMap<u32, u64> {
    let PendingValues(map) = self;
    map
}

/// Check if the `PendingValues` is empty.
public(package) fun is_empty(self: &PendingValues): bool { self.0.is_empty() }

#[test]
fun test_pending_values() {
    use std::unit_test::assert_eq;

    let mut pending = empty();
    assert!(pending.is_empty());

    pending.insert_or_add(0, 10);
    pending.insert_or_add(0, 10);
    pending.insert_or_add(1, 20);

    // test reads
    assert_eq!(pending.value_at(0), 20);
    assert_eq!(pending.value_at(1), 40);

    // test flushing, and reads after flushing
    assert_eq!(pending.flush(0), 20);
    assert_eq!(pending.value_at(0), 0);

    // flush the rest of the values and check if the map is empty
    assert_eq!(pending.value_at(1), 20);
    assert_eq!(pending.flush(1), 20);
    assert!(pending.is_empty());

    // unwrap the pending values
    let _ = pending.unwrap();
}
