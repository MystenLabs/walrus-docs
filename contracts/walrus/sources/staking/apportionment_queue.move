// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A custom priority queue implementation for use in the apportionment algorithm.
/// This implementation uses a quotient-based priority with a tie-breaker to break ties when
/// priorities are equal.
module walrus::apportionment_queue;

use std::uq64_64::UQ64_64;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// Trying to pop a value from an empty heap.
const EPopFromEmptyHeap: u64 = 0;

/// Struct representing a priority queue.
public struct ApportionmentQueue<T> has drop {
    /// The `entries` vector contains a max heap, where the children of the node at index `i` are at
    /// indices `2 * i + 1` and `2 * i + 2`.
    /// INV: The parent node's priority is always higher or equal to its child nodes' priorities.
    entries: vector<Entry<T>>,
}

public struct Entry<T> has drop {
    priority: UQ64_64, // higher value means higher priority and will be popped first
    tie_breaker: u64, // used to break ties when priorities are equal
    value: T,
}

/// Create a new priority queue.
public fun new<T>(): ApportionmentQueue<T> {
    ApportionmentQueue { entries: vector[] }
}

/// Pop the entry with the highest priority value.
public fun pop_max<T>(pq: &mut ApportionmentQueue<T>): (UQ64_64, u64, T) {
    let len = pq.entries.length();
    assert!(len > 0, EPopFromEmptyHeap);
    // Swap the max element with the last element in the entries and remove the max element.
    let Entry { priority, tie_breaker, value } = pq.entries.swap_remove(0);
    // Restore the max heap condition at the root node.
    bubble_down(&mut pq.entries);
    (priority, tie_breaker, value)
}

/// Insert a new entry into the queue.
public fun insert<T>(
    pq: &mut ApportionmentQueue<T>,
    priority: UQ64_64,
    tie_breaker: u64,
    value: T,
) {
    pq.entries.push_back(Entry { priority, tie_breaker, value });
    bubble_up(&mut pq.entries);
}

/// Restore the max heap condition at the root node after popping the max element.
fun bubble_down<T>(elements: &mut vector<Entry<T>>) {
    let len = elements.length();
    let mut i = 0;
    while (i < len) {
        let left = i * 2 + 1;
        let right = left + 1;
        let mut max = i;
        // Find the node with the highest priority betweenthe node and its children.
        if (left < len && elements[left].higher_priority_than(&elements[max])) {
            max = left;
        };
        if (right < len && elements[right].higher_priority_than(&elements[max])) {
            max = right;
        };
        // If the current node has the highest priority, we're done.
        if (max == i) {
            break
        };
        // Swap the current node with the node with the highest priority one.
        elements.swap(max, i);
        i = max;
    }
}

/// Restore the max heap condition after inserting a new element at the end of the entries.
fun bubble_up<T>(elements: &mut vector<Entry<T>>) {
    let len = elements.length();
    let mut i = len - 1;
    while (i > 0) {
        let parent = (i - 1) / 2;
        if (elements[i].higher_priority_than(&elements[parent])) {
            elements.swap(i, parent);
        } else {
            break
        };
        i = parent;
    }
}

fun higher_priority_than<T>(entry1: &Entry<T>, entry2: &Entry<T>): bool {
    (entry1.priority.gt(entry2.priority)) ||
        (entry1.priority == entry2.priority && entry1.tie_breaker > entry2.tie_breaker)
}

#[test_only]
use std::uq64_64;

#[test_only]
public fun new_filled<T>(
    mut priorities: vector<UQ64_64>,
    mut tie_breakers: vector<u64>,
    mut values: vector<T>,
): ApportionmentQueue<T> {
    let len = priorities.length();
    assert!(tie_breakers.length() == len, 0);
    assert!(values.length() == len, 0);
    priorities.reverse();
    tie_breakers.reverse();
    values.reverse();
    let mut queue = new();
    let mut i = 0;
    while (i < len) {
        let priority = priorities.pop_back();
        let tie_breaker = tie_breakers.pop_back();
        let value = values.pop_back();
        queue.insert(priority, tie_breaker, value);
        i = i + 1;
    };
    values.destroy_empty();
    queue
}

#[test]
fun test_pq() {
    let priorities = vector[3, 1, 4, 2, 5, 2].map!(|val| uq64_64::from_raw(val));
    let tie_breakers = vector[1, 2, 3, 4, 5, 6];
    let values = vector[10, 20, 30, 40, 50, 60];
    let mut h = new_filled(priorities, tie_breakers, values);
    h.check_pop_max(5, 50);
    h.check_pop_max(4, 30);
    h.check_pop_max(3, 10);
    h.insert(uq64_64::from_raw(7), 7, 70);
    h.check_pop_max(7, 70);
    h.check_pop_max(2, 60);
    h.insert(uq64_64::from_raw(0), 8, 80);
    h.check_pop_max(2, 40);
    h.check_pop_max(1, 20);
    h.check_pop_max(0, 80);

    let priorities = vector[5, 3, 1, 2, 4].map!(|val| uq64_64::from_raw(val));
    let tie_breakers = vector[10, 20, 30, 40, 50];
    let values = vector[10, 20, 30, 40, 50];
    let mut h = new_filled(priorities, tie_breakers, values);
    h.check_pop_max(5, 10);
    h.check_pop_max(4, 50);
    h.check_pop_max(3, 20);
    h.check_pop_max(2, 40);
    h.check_pop_max(1, 30);
}

#[test_only]
fun check_pop_max(h: &mut ApportionmentQueue<u64>, expected_priority: u128, expected_value: u64) {
    let expected_priority = uq64_64::from_raw(expected_priority);
    let (priority, _tie_breaker, value) = h.pop_max();
    assert!(priority == expected_priority);
    assert!(value == expected_value);
}
