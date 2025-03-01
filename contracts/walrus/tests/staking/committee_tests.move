// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::committee_tests;

use std::unit_test::{assert_eq, assert_ref_eq};
use sui::{address, vec_map};
use walrus::committee::{Self, Committee};

#[test]
fun empty_committee() {
    let cmt = committee::empty();
    assert_eq!(cmt.size(), 0);
}

#[test]
// Scenario: pass unsorted shard assignments during initialization and transition,
// expect the nodes to preserve their assigned shards during reassigment.
fun sort_and_preserve_shards_correctly() {
    // nodes are sorted in reverse order (3 to 0), and that's intentional, shards num is 8
    let size = 4;
    let mut nodes = vector::tabulate!(size, |i| address::from_u256((3 - i) as u256).to_id());
    let initial = vec_map::from_keys_values(
        nodes,
        vector::tabulate!(size, |_| 2),
    );

    let cmt = committee::initialize(initial);

    assert_eq!(cmt.size(), size);
    assert_eq!(cmt[&@0.to_id()], vector[0, 1]);
    assert_eq!(cmt[&@1.to_id()], vector[2, 3]);
    assert_eq!(cmt[&@2.to_id()], vector[4, 5]);
    assert_eq!(cmt[&@3.to_id()], vector[6, 7]);

    // Transition the committee, again, supply nodes in reverse order
    // remove two last nodes, total number of nodes is now 2, assign 4 shards to each
    nodes.pop_back();
    nodes.pop_back();

    let size = 2;
    let new_assignments = vec_map::from_keys_values(nodes, vector::tabulate!(size, |_| 4));
    let cmt2 = cmt.transition(new_assignments);

    assert_eq!(cmt2.size(), 2);

    // testing first node
    assert!(cmt2[&@3.to_id()].contains(&6)); // initial
    assert!(cmt2[&@3.to_id()].contains(&7));
    assert!(cmt2[&@3.to_id()].contains(&1)); // free shards assigned
    assert!(cmt2[&@3.to_id()].contains(&0));

    // testing second node
    assert!(cmt2[&@2.to_id()].contains(&4)); // initial
    assert!(cmt2[&@2.to_id()].contains(&5));
    assert!(cmt2[&@2.to_id()].contains(&2)); // freed shards assigned
    assert!(cmt2[&@2.to_id()].contains(&3));
}

#[test]
fun default_scenario() {
    let n1 = @1.to_id();
    let n2 = @2.to_id();
    let n3 = @3.to_id();
    let n4 = @4.to_id();
    let n5 = @5.to_id();

    // Initialize the committee with 2 shards per node, 5 nodes, 10 shards in total
    let cmt = committee::initialize(
        vec_map::from_keys_values(
            vector[n1, n2, n3, n4, n5],
            vector[2, 2, 2, 2, 2],
        ),
    );

    assert_eq!(cmt.size(), 5);

    assert_eq!(cmt[&n1], vector[0, 1]);
    assert_eq!(cmt[&n2], vector[2, 3]);
    assert_eq!(cmt[&n3], vector[4, 5]);
    assert_eq!(cmt[&n4], vector[6, 7]);
    assert_eq!(cmt[&n5], vector[8, 9]);

    // Transition the committee to 4/3 shards per node, 3 nodes, same number of shards
    let cmt2 = cmt.transition(
        vec_map::from_keys_values(
            vector[n1, n2, n3],
            vector[4, 3, 3],
        ),
    );

    assert_eq!(cmt2.size(), 3);

    // we make sure that the shards this node had are still in place
    // repeat the checks for all nodes 1-3
    assert_eq!(cmt2[&n1].length(), 4);
    assert!(cmt2[&n1].contains(&0));
    assert!(cmt2[&n1].contains(&1));

    assert_eq!(cmt2[&n2].length(), 3);
    assert!(cmt2[&n2].contains(&2));
    assert!(cmt2[&n2].contains(&3));

    assert_eq!(cmt2[&n3].length(), 3);
    assert!(cmt2[&n3].contains(&4));
    assert!(cmt2[&n3].contains(&5));

    // store shard assignments to check later
    let n2_shards = cmt2[&n2];
    let n3_shards = cmt2[&n3];

    // Transition the committee to 3, 3, 2, 2 for nodes 2-5 (removing node 1)
    let cmt3 = cmt2.transition(
        vec_map::from_keys_values(
            vector[n2, n3, n4, n5],
            vector[3, 3, 2, 2],
        ),
    );

    assert_eq!(cmt3.size(), 4);

    // Make sure that n2 and n3 have the same shards as before
    assert_eq!(cmt3[&n2], n2_shards);
    assert_eq!(cmt3[&n3], n3_shards);

    // Make sure that n4 and n5 have correct number of shards
    assert_eq!(cmt3[&n4].length(), 2);
    assert_eq!(cmt3[&n5].length(), 2);

    // Transition the committee to just N1 owning all the shards
    let cmt4 = cmt3.transition(
        vec_map::from_keys_values(
            vector[n1],
            vector[10],
        ),
    );

    assert!(cmt4.size() == 1);
    assert!(cmt4[&n1].length() == 10);
    assert!(cmt4[&n1].contains(&0));
    assert!(cmt4[&n1].contains(&1));
    assert!(cmt4[&n1].contains(&2));
    assert!(cmt4[&n1].contains(&3));
    assert!(cmt4[&n1].contains(&4));
    assert!(cmt4[&n1].contains(&5));
    assert!(cmt4[&n1].contains(&6));
    assert!(cmt4[&n1].contains(&7));
    assert!(cmt4[&n1].contains(&8));
    assert!(cmt4[&n1].contains(&9));
}

#[test]
fun ignore_empty_assignments() {
    let (n1, n2, n3, n4, n5) = (@1, @2, @3, @4, @5);

    // expect n4 and n5 to be ignored
    let cmt = committee::initialize(
        vec_map::from_keys_values(
            vector[n1, n2, n3, n4, n5].map!(|addr| addr.to_id()),
            vector[2, 2, 2, 0, 0],
        ),
    );

    assert!(cmt.is_sorted());

    // expect n1 and n5 to be ignored
    let cmt2 = cmt.transition(
        vec_map::from_keys_values(
            vector[n1, n2, n3, n4, n5].map!(|addr| addr.to_id()),
            vector[0, 2, 2, 2, 0],
        ),
    );

    assert!(cmt2.is_sorted());
    assert_eq!(cmt2.size(), 3);
    assert_ref_eq!(cmt.shards(&n2.to_id()), cmt2.shards(&n2.to_id()));
    assert_ref_eq!(cmt.shards(&n3.to_id()), cmt2.shards(&n3.to_id()));
}

// #[test] // requires manual --gas-limit set, ignored for convenience
#[allow(unused_function)]
fun large_set_assignments_1() {
    let nodes = vector::tabulate!(1000, |i| address::from_u256(i as u256).to_id());
    let assignments = vec_map::from_keys_values(nodes, vector::tabulate!(1000, |_| 1));
    let _cmt = committee::initialize(assignments);
}

// #[test] // requires manual --gas-limit set, ignored for convenience
#[allow(unused_function)]
fun large_set_assignments_2() {
    let nodes = vector::tabulate!(1000, |i| address::from_u256(i as u256).to_id());
    let assignments = vec_map::from_keys_values(nodes, vector::tabulate!(1000, |_| 1));

    let cmt = committee::initialize(assignments);
    cmt.transition(
        vec_map::from_keys_values(
            nodes,
            vector::tabulate!(1000, |i| (i % 3) as u16),
        ),
    );
}

#[test, expected_failure(abort_code = committee::EInvalidShardAssignment)]
fun reject_invalid_shard_assignment() {
    let (n1, n2, n3) = (@1.to_id(), @2.to_id(), @3.to_id());

    let cmt = committee::initialize(
        vec_map::from_keys_values(
            vector[n1, n2, n3],
            vector[2, 2, 2],
        ),
    );

    // expect transaction to succeed (same number of shards)
    let cmt2 = cmt.transition(
        vec_map::from_keys_values(
            vector[n1, n2, n3],
            vector[1, 3, 2],
        ),
    );

    assert!(cmt2.is_sorted());

    // expect transaction to fail (different number of shards)
    let _ = cmt2.transition(
        vec_map::from_keys_values(
            vector[n1, n2, n3],
            vector[3, 3, 2],
        ),
    );
}

#[test]
fun diff_at_different_sizes() {
    let cmt_1 = cmt(vector[@1, @2, @3]);
    let cmt_2 = cmt(vector[@2, @3, @4]);
    let (left, right) = committee::diff(&cmt_1, &cmt_2);

    assert_eq!(left, vector[@1.to_id()]);
    assert_eq!(right, vector[@4.to_id()]);
}

fun cmt(ids: vector<address>): Committee {
    let size = ids.length();
    committee::initialize(
        vec_map::from_keys_values(
            ids.map!(|addr| addr.to_id()),
            vector::tabulate!(size, |i| i as u16),
        ),
    )
}
