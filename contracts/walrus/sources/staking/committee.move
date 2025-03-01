// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module defines the `Committee` struct which stores the current
/// committee with shard assignments. Additionally, it manages transitions /
/// transfers of shards between committees with the least amount of changes.
module walrus::committee;

use sui::vec_map::{Self, VecMap};
use walrus::sort;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The shard assignment is invalid.
const EInvalidShardAssignment: u64 = 0;

/// Represents the current committee in the system. Each node in the committee
/// has assigned shard IDs.
///
/// The `VecMap` inside the `Committee` is guaranteed to be sorted by the node ID.
public struct Committee(VecMap<ID, vector<u16>>) has copy, drop, store;

/// Creates an empty committee. Only relevant for epoch 0, when no nodes are
/// assigned any shards.
public(package) fun empty(): Committee { Committee(vec_map::empty()) }

/// Check if the given `ID` is in the `Committee`.
public(package) fun contains(cmt: &Committee, node_id: &ID): bool {
    cmt.0.contains(node_id)
}

/// Initializes the committee with the given `assigned_number` of shards per
/// node. Shards are assigned sequentially to each node.
///
/// Assumptions:
/// - The values of assigned_number are <= 1000 (i.e., the limit of a vector)
public(package) fun initialize(assigned_number: VecMap<ID, u16>): Committee {
    let mut shard_idx: u16 = 0;
    let sorted_assignments = sort::sort_vec_map_by_node_id!(assigned_number);
    let (keys, values) = sorted_assignments.into_keys_values();

    let cmt = vec_map::from_keys_values(
        keys,
        values.map!(|v| vector::tabulate!(v as u64, |_| {
            let res = shard_idx;
            shard_idx = shard_idx + 1;
            res
        })),
    );

    Committee(cmt)
}

/// Transitions the current committee to the new committee with the given shard
/// assignments. The function tries to minimize the number of changes by keeping
/// as many shards in place as possible.
public(package) fun transition(cmt: &Committee, mut new_assignments: VecMap<ID, u16>): Committee {
    // Store the total number of shards in the new committee, before
    // new_assignments is modified.
    let mut new_num_of_shards = 0;
    new_assignments.size().do!(|idx| {
        let (_, shards) = new_assignments.get_entry_by_idx(idx);
        new_num_of_shards = new_num_of_shards + *shards;
    });

    let mut new_cmt = vec_map::empty();
    let mut to_move = vector[];
    let size = cmt.0.size();

    let mut current_num_of_shards = 0;
    size.do!(|idx| {
        let (node_id, prev_shards) = cmt.0.get_entry_by_idx(idx);
        current_num_of_shards = current_num_of_shards + prev_shards.length();
        let node_id = *node_id;
        let assigned_len = new_assignments.get_idx_opt(&node_id).map!(|idx| {
            let (_, value) = new_assignments.remove_entry_by_idx(idx);
            value as u64
        });

        // if the node is not in the new committee, remove all shards, make
        // them available for reassignment
        if (assigned_len.is_none() || assigned_len.borrow() == &0) {
            to_move.append(*prev_shards);
            return
        };

        let curr_len = prev_shards.length();
        let assigned_len = assigned_len.destroy_some();

        // node stays the same, we copy the shards over, best scenario
        if (curr_len == assigned_len) {
            new_cmt.insert(node_id, *prev_shards);
        };

        // if the node is in the new committee, check if the number of shards
        // assigned to the node has decreased. If so, remove the extra shards,
        // and move the node to the new committee
        if (curr_len > assigned_len) {
            let mut node_shards = *prev_shards;
            (curr_len - assigned_len).do!(|_| to_move.push_back(node_shards.pop_back()));
            new_cmt.insert(node_id, node_shards);
        };

        // Mark the node as needing more shards.
        if (curr_len < assigned_len) {
            new_assignments.insert(node_id, assigned_len as u16);
        };
    });

    // Check that the number of shards in the new committee is equal to
    // the number of shards in the current committee.
    assert!((new_num_of_shards as u64) == current_num_of_shards, EInvalidShardAssignment);

    // Now the `new_assignments` only contains nodes for which we didn't have
    // enough shards to assign, and the nodes that were not part of the old
    // committee.
    let (keys, values) = new_assignments.into_keys_values();
    keys.zip_do!(values, |key, value| {
        if (value == 0) return; // ignore nodes with 0 shards

        let mut current_shards = cmt.0.try_get(&key).destroy_or!(vector[]);
        current_shards
            .length()
            .diff(value as u64)
            .do!(|_| current_shards.push_back(to_move.pop_back()));

        new_cmt.insert(key, current_shards);
    });

    Committee(sort::sort_vec_map_by_node_id!(new_cmt))
}

#[syntax(index)]
/// Get the shards assigned to the given `node_id`.
public(package) fun shards(cmt: &Committee, node_id: &ID): &vector<u16> {
    cmt.0.get(node_id)
}

/// Get the number of nodes in the committee.
public(package) fun size(cmt: &Committee): u64 {
    cmt.0.size()
}

/// Get the inner representation of the committee.
public(package) fun inner(cmt: &Committee): &VecMap<ID, vector<u16>> {
    &cmt.0
}

/// Copy the inner representation of the committee.
public(package) fun to_inner(cmt: &Committee): VecMap<ID, vector<u16>> {
    cmt.0
}

/// Finds the difference between two committees, returns the difference in two
/// sets of nodes, one set for nodes that are in the first committee but not in
/// the second, and the other set is vice versa.
///
/// Committee is always sorted by the node ID, so the diff algorithm is simple.
public(package) fun diff(cmt_1: &Committee, cmt_2: &Committee): (vector<ID>, vector<ID>) {
    let mut i = 0;
    let mut j = 0;
    let mut diff_1 = vector[];
    let mut diff_2 = vector[];
    let lhs_size = cmt_1.size();
    let rhs_size = cmt_2.size();

    while (i < lhs_size && j < rhs_size) {
        let (lhs, _) = cmt_1.0.get_entry_by_idx(i);
        let (rhs, _) = cmt_2.0.get_entry_by_idx(j);

        if (lhs == rhs) {
            i = i + 1;
            j = j + 1;
            continue
        };

        // in LHS, but not in RHS
        if (lhs.to_address().to_u256() < rhs.to_address().to_u256()) {
            i = i + 1;
            diff_1.push_back(*lhs);
            continue
        };

        // in RHS, but not in LHS
        diff_2.push_back(*rhs);
        j = j + 1;
    };

    // fill in the rest, if any, for the LHS
    while (i < lhs_size) {
        let (lhs, _) = cmt_1.0.get_entry_by_idx(i);
        diff_1.push_back(*lhs);
        i = i + 1;
    };

    // fill in the rest, if any, for the RHS
    while (j < rhs_size) {
        let (rhs, _) = cmt_2.0.get_entry_by_idx(j);
        diff_2.push_back(*rhs);
        j = j + 1;
    };

    (diff_1, diff_2)
}

#[test_only]
/// Check if the committee is sorted by the node ID.
public(package) fun is_sorted(cmt: &Committee): bool {
    sort::is_vec_map_sorted_by_node_id!(&cmt.0)
}
