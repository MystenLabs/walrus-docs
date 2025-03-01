// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Contains an active set of storage nodes. The active set is a smart collection
/// that only stores up to a 1000 nodes. The nodes are sorted by the amount of
/// staked WAL. Additionally, the active set tracks the total amount of staked
/// WAL to make the calculation of the rewards and voting power distribution easier.
///
/// TODOs:
/// - consider using a different data structure for the active set (#714)
/// - consider removing `min_stake` field, use threshold from number of
///   shards and total_staked (#715)
module walrus::active_set_tests;

use std::unit_test::assert_eq;
use walrus::active_set;

#[test]
fun test_insert() {
    let mut set = active_set::new(3, 100);
    set.insert_or_update(@1.to_id(), 99); // lower than min_stake
    set.insert_or_update(@1.to_id(), 200);
    set.insert_or_update(@2.to_id(), 300);
    set.insert_or_update(@3.to_id(), 400);

    assert_eq!(set.size(), 3);
    assert_eq!(set.max_size(), 3);

    let active_ids = set.active_ids();
    assert!(active_ids.contains(&@1.to_id()));
    assert!(active_ids.contains(&@2.to_id()));
    assert!(active_ids.contains(&@3.to_id()));
    assert_eq!(set.cur_min_stake(), 200);

    // now insert a node with even more staked WAL
    set.insert_or_update(@4.to_id(), 500);

    assert_eq!(set.size(), 3);
    assert_eq!(set.cur_min_stake(), 300);

    let active_ids = set.active_ids();
    assert!(active_ids.contains(&@2.to_id()));
    assert!(active_ids.contains(&@3.to_id()));
    assert!(active_ids.contains(&@4.to_id()));

    // and now insert a node with less staked WAL
    set.insert_or_update(@5.to_id(), 250);

    assert_eq!(set.size(), 3);
    assert_eq!(set.cur_min_stake(), 300);

    let active_ids = set.active_ids();
    assert!(active_ids.contains(&@2.to_id()));
    assert!(active_ids.contains(&@3.to_id()));
    assert!(active_ids.contains(&@4.to_id()));

    // and now insert 3 more nodes with super high staked WAL
    set.insert_or_update(@6.to_id(), 1000);
    set.insert_or_update(@7.to_id(), 1000);
    set.insert_or_update(@8.to_id(), 1000);

    assert_eq!(set.size(), 3);
    assert_eq!(set.cur_min_stake(), 1000);

    let active_ids = set.active_ids();
    assert!(active_ids.contains(&@6.to_id()));
    assert!(active_ids.contains(&@7.to_id()));
    assert!(active_ids.contains(&@8.to_id()));
}

#[test]
fun test_size_1() {
    let mut set = active_set::new(1, 100);
    assert_eq!(set.cur_min_stake(), 100);
    set.insert_or_update(@1.to_id(), 1000);
    assert_eq!(set.cur_min_stake(), 1000);
    set.insert_or_update(@2.to_id(), 1001);
    assert_eq!(set.cur_min_stake(), 1001);
}

#[test]
fun kick_out_attack() {
    let mut set = active_set::new(3, 0);
    set.insert_or_update(@1.to_id(), 100);
    set.insert_or_update(@2.to_id(), 200);
    set.insert_or_update(@3.to_id(), 300);

    assert_eq!(set.size(), 3);
    assert_eq!(set.cur_min_stake(), 100);
    assert_eq!(set.threshold_stake(), 0);

    // now insert a node that kicks out the first one
    // and then removes itself
    set.insert_or_update(@4.to_id(), 101);

    assert_eq!(set.size(), 3);
    assert!(set.active_ids().contains(&@4.to_id()));
    assert!(!set.active_ids().contains(&@1.to_id())); // kicked out

    set.insert_or_update(@4.to_id(), 0); // stake is 0, removes itself

    assert_eq!(set.size(), 2);
    assert!(!set.active_ids().contains(&@4.to_id()));
    assert!(!set.active_ids().contains(&@1.to_id()));

    // TODO: can we have a reserve that keeps the node with less than min stake
    // in the active set and "returns" it when the attacking node leaves?
}
