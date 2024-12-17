// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::pending_values;

use sui::vec_map::{Self, VecMap};

/// Attempt to reduce the value of a pending value for an epoch that does not
/// exist.
const EIncorrectValue: u64 = 0;

/// Represents a map of pending values. The key is the epoch when the value is
/// pending, and the value is the amount of WALs or pool tokens.
public struct PendingValues(VecMap<u32, u64>) has store, drop, copy;

/// Create a new empty `PendingValues` instance.
public(package) fun empty(): PendingValues { PendingValues(vec_map::empty()) }

public(package) fun insert_or_add(self: &mut PendingValues, epoch: u32, value: u64) {
    let map = &mut self.0;
    if (!map.contains(&epoch)) {
        map.insert(epoch, value);
    } else {
        let curr = map[&epoch];
        *&mut map[&epoch] = curr + value;
    };
}

/// Reduce the pending value for the given epoch by the given value.
public(package) fun reduce(self: &mut PendingValues, epoch: u32, value: u64) {
    let map = &mut self.0;
    if (!map.contains(&epoch)) {
        abort EIncorrectValue
    } else {
        let curr = map[&epoch];
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
