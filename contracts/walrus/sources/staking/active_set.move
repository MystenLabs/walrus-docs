// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Contains an active set of storage nodes. The active set is a smart collection
/// that only stores up to a 1000 nodes. The active set tracks the total amount of staked
/// WAL to make the calculation of the rewards and voting power distribution easier.
///
/// TODOs:
/// - consider using a different data structure for the active set (#714)
/// - consider removing `min_stake` field, use threshold from number of
///   shards and total_staked (#715)
module walrus::active_set;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The maximum size of an ActiveSet must be strictly larger than zero.
const EZeroMaxSize: u64 = 0;
/// The node is already part of the active set.
const EDuplicateInsertion: u64 = 1;

public struct ActiveSetEntry has copy, drop, store {
    node_id: ID,
    staked_amount: u64,
}

/// The active set of storage nodes, a smart collection that only stores up
/// to a 1000 nodes.
/// Additionally, the active set tracks the total amount of staked WAL to make
/// the calculation of the rewards and voting power distribution easier.
///
/// TODO: implement a reserve to track N + K nodes, where N is the active set
/// size and K is the number of nodes that are in the process of being added to
/// the active set. This will allow us to handle removals from the active set
/// without refetching the nodes from the storage.
public struct ActiveSet has copy, drop, store {
    /// The maximum number of storage nodes in the active set.
    /// Potentially remove this field.
    max_size: u16,
    /// The minimum amount of staked WAL needed to enter the active set. This is used to
    /// determine if a storage node can be added to the active set.
    threshold_stake: u64,
    /// The list of storage nodes in the active set and their stake.
    nodes: vector<ActiveSetEntry>,
    /// The total amount of staked WAL in the active set.
    total_stake: u64,
}

/// Creates a new active set with the given `size` and `threshold_stake`. The
/// latter is used to filter out storage nodes that do not have enough staked
/// WAL to be included in the active set initially.
public(package) fun new(max_size: u16, threshold_stake: u64): ActiveSet {
    assert!(max_size > 0, EZeroMaxSize);
    ActiveSet {
        max_size,
        threshold_stake,
        nodes: vector[],
        total_stake: 0,
    }
}

/// Inserts the node if it is not already in the active set, otherwise updates its stake.
/// If the node's stake is below the threshold value, it is removed from the set.
/// Returns true if the node is in the set after the operation, false otherwise.
public(package) fun insert_or_update(set: &mut ActiveSet, node_id: ID, staked_amount: u64): bool {
    // Currently, the `threshold_stake` is set to `0`, so we need to account for that.
    if (staked_amount == 0 || staked_amount < set.threshold_stake) {
        set.remove(node_id);
        return false
    };

    if (set.update(node_id, staked_amount)) true
    else set.insert(node_id, staked_amount)
}

/// Updates the staked amount of the storage node with the given `node_id` in
/// the active set. Returns true if the node is in the set.
public(package) fun update(set: &mut ActiveSet, node_id: ID, staked_amount: u64): bool {
    let index = set.nodes.find_index!(|entry| entry.node_id == node_id);
    if (index.is_none()) {
        return false
    };
    index.do!(|idx| {
        set.total_stake = set.total_stake + staked_amount - set.nodes[idx].staked_amount;
        set.nodes[idx].staked_amount = staked_amount;
    });
    true
}

/// Inserts a storage node with the given `node_id` and `staked_amount` into the
/// active set. The node is only added if it has enough staked WAL to be included
/// in the active set. If the active set is full, the node with the smallest
/// staked WAL is removed to make space for the new node.
/// Returns true if the node was inserted, false otherwise.
fun insert(set: &mut ActiveSet, node_id: ID, staked_amount: u64): bool {
    assert!(set.nodes.find_index!(|entry| entry.node_id == node_id).is_none(), EDuplicateInsertion);

    // If the nodes are less than the max size, insert the node.
    if (set.nodes.length() as u16 < set.max_size) {
        set.total_stake = set.total_stake + staked_amount;
        set.nodes.push_back(ActiveSetEntry { node_id, staked_amount });
        return true
    };

    // Find the node with the smallest amount of stake and less than the new node.
    let mut min_stake = staked_amount;
    let mut min_idx = option::none();
    set.nodes.length().do!(|i| {
        if (set.nodes[i].staked_amount < min_stake) {
            min_idx = option::some(i);
            min_stake = set.nodes[i].staked_amount;
        }
    });

    // If there is such a node, replace it in the list.
    if (min_idx.is_some()) {
        let min_idx = min_idx.extract();
        set.total_stake = set.total_stake - min_stake + staked_amount;
        *&mut set.nodes[min_idx] = ActiveSetEntry { node_id, staked_amount };
        true
    } else {
        false
    }
}

/// Removes the storage node with the given `node_id` from the active set.
public(package) fun remove(set: &mut ActiveSet, node_id: ID) {
    let index = set.nodes.find_index!(|entry| entry.node_id == node_id);
    index.do!(|idx| {
        let entry = set.nodes.swap_remove(idx);
        set.total_stake = set.total_stake - entry.staked_amount;
    });
}

/// Sets the maximum size of the active set.
#[test_only]
public(package) fun set_max_size(set: &mut ActiveSet, max_size: u16) {
    set.max_size = max_size;
}

/// The maximum size of the active set.
public(package) fun max_size(set: &ActiveSet): u16 { set.max_size }

/// The current size of the active set.
public(package) fun size(set: &ActiveSet): u16 { set.nodes.length() as u16 }

/// The IDs of the nodes in the active set.
public(package) fun active_ids(set: &ActiveSet): vector<ID> {
    set.nodes.map_ref!(|node| node.node_id)
}

/// The IDs and stake of the nodes in the active set.
public(package) fun active_ids_and_stake(set: &ActiveSet): (vector<ID>, vector<u64>) {
    let mut active_ids = vector[];
    let mut stake = vector[];
    set.nodes.do_ref!(|entry| {
        active_ids.push_back(entry.node_id);
        stake.push_back(entry.staked_amount);
    });
    (active_ids, stake)
}

/// The minimum amount of staked WAL in the active set.
public(package) fun threshold_stake(set: &ActiveSet): u64 { set.threshold_stake }

/// The total amount of staked WAL in the active set.
public(package) fun total_stake(set: &ActiveSet): u64 { set.total_stake }

/// Current minimum stake needed to be in the active set.
/// If the active set is full, the minimum stake is the stake of the node with the smallest stake.
/// Otherwise, the minimum stake is the threshold stake.
/// Test only to discourage using this since it iterates over all nodes. When the `min_stake` is
/// needed within [`ActiveSet`], prefer inlining/integrating it in other loops.
#[test_only]
public(package) fun cur_min_stake(set: &ActiveSet): u64 {
    if (set.nodes.length() == set.max_size as u64) {
        let mut min_stake = std::u64::max_value!();
        set.nodes.length().do!(|i| {
            if (set.nodes[i].staked_amount < min_stake) {
                min_stake = set.nodes[i].staked_amount;
            }
        });
        min_stake
    } else {
        set.threshold_stake
    }
}

#[test_only]
public fun stake_for_node(set: &ActiveSet, node_id: ID): u64 {
    set
        .nodes
        .find_index!(|entry| entry.node_id == node_id)
        .map!(|index| set.nodes[index].staked_amount)
        .destroy_or!(0)
}

// === Test ===

#[test]
fun test_evict_correct_node_simple() {
    let mut set = new(5, 0);
    set.insert_or_update(object::id_from_address(@0x1), 10);
    set.insert_or_update(object::id_from_address(@0x2), 9);
    set.insert_or_update(object::id_from_address(@0x3), 8);
    set.insert_or_update(object::id_from_address(@0x4), 7);
    set.insert_or_update(object::id_from_address(@0x5), 6);

    let mut total_stake = 10 + 9 + 8 + 7 + 6;

    assert!(set.total_stake == total_stake);

    // insert another node which should eject node 5
    set.insert_or_update(object::id_from_address(@0x6), 11);

    // check if total stake was updated correctly
    total_stake = total_stake - 6 + 11;
    assert!(set.total_stake == total_stake);

    let active_ids = set.active_ids();

    // node 5 should not be part of the set
    assert!(!active_ids.contains(&object::id_from_address(@0x5)));

    // all other nodes should be
    assert!(active_ids.contains(&object::id_from_address(@0x1)));
    assert!(active_ids.contains(&object::id_from_address(@0x2)));
    assert!(active_ids.contains(&object::id_from_address(@0x3)));
    assert!(active_ids.contains(&object::id_from_address(@0x4)));
    assert!(active_ids.contains(&object::id_from_address(@0x6)));
}

#[test]
fun test_evict_correct_node_with_updates() {
    let nodes = vector[
        object::id_from_address(@0x1),
        object::id_from_address(@0x2),
        object::id_from_address(@0x3),
        object::id_from_address(@0x4),
        object::id_from_address(@0x5),
        object::id_from_address(@0x6),
    ];

    let mut set = new(5, 0);
    set.insert_or_update(nodes[3], 7);
    set.insert_or_update(nodes[0], 10);
    set.insert_or_update(nodes[2], 8);
    set.insert_or_update(nodes[1], 9);
    set.insert_or_update(nodes[4], 6);

    let mut total_stake = 10 + 9 + 8 + 7 + 6;

    assert!(set.total_stake == total_stake);

    // update nodes again
    set.insert_or_update(nodes[0], 12);
    // check if total stake was updated correctly
    total_stake = total_stake - 10 + 12;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[0]) == 12);

    set.insert_or_update(nodes[2], 13);
    // check if total stake was updated correctly
    total_stake = total_stake - 8 + 13;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[2]) == 13);

    set.insert_or_update(nodes[3], 9);
    // check if total stake was updated correctly
    total_stake = total_stake - 7 + 9;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[3]) == 9);

    set.insert_or_update(nodes[1], 10);
    // check if total stake was updated correctly
    total_stake = total_stake - 9 + 10;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[1]) == 10);

    set.insert_or_update(nodes[4], 7);
    // check if total stake was updated correctly
    total_stake = total_stake - 6 + 7;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[4]) == 7);

    // insert another node which should eject nodes[4] (address @5)
    set.insert_or_update(nodes[5], 11);
    // check if total stake was updated correctly
    total_stake = total_stake - 7 + 11;
    assert!(set.total_stake == total_stake);
    // check if the stake of the node was updated correctly
    assert!(set.stake_for_node(nodes[5]) == 11);

    let active_ids = set.active_ids();

    // node 5 should not be part of the set
    assert!(!active_ids.contains(&nodes[4]));

    // all other nodes should be
    assert!(active_ids.contains(&nodes[0]));
    assert!(active_ids.contains(&nodes[1]));
    assert!(active_ids.contains(&nodes[2]));
    assert!(active_ids.contains(&nodes[3]));
    assert!(active_ids.contains(&nodes[5]));
}
