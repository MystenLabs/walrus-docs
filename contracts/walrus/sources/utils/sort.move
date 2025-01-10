// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Implements sorting macros for commonly used data structures.
module walrus::sort;

use sui::vec_map::{Self, VecMap};

/// Sort the given `VecMap` by the node ID transformed into `u256`.
///
/// Uses the insertion sort algorithm, given that the `VecMap` is already mostly sorted.
public macro fun sort_vec_map_by_node_id<$V>($self: VecMap<ID, $V>): VecMap<ID, $V> {
    let self = $self;

    if (self.size() <= 1) return self;
    let (mut keys, mut values) = self.into_keys_values();
    let len = keys.length();
    let mut i = 1;

    while (i < len) {
        let mut j = i;
        while (j > 0 && keys[j - 1].to_address().to_u256() > keys[j].to_address().to_u256()) {
            keys.swap(j - 1, j);
            values.swap(j - 1, j);
            j = j - 1;
        };
        i = i + 1;
    };

    vec_map::from_keys_values(keys, values)
}

/// Check if the given `VecMap` is sorted by the node ID transformed into `u256`.
public macro fun is_vec_map_sorted_by_node_id<$V>($self: &VecMap<ID, $V>): bool {
    let self = $self;

    let len = self.size();
    if (len <= 1) return true;
    let mut i = 1;
    while (i < len) {
        let (lhs, _) = self.get_entry_by_idx(i - 1);
        let (rhs, _) = self.get_entry_by_idx(i);
        if (lhs.to_address().to_u256() > rhs.to_address().to_u256()) {
            return false
        };
        i = i + 1;
    };

    true
}
