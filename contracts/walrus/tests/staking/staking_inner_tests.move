// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::staking_inner_tests;

use std::unit_test::assert_eq;
use sui::{clock, test_utils::destroy, vec_map};
use walrus::{staking_inner, storage_node, test_utils as test};

const EPOCH_DURATION: u64 = 7 * 24 * 60 * 60 * 1000;

#[test]
fun test_registration() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);

    // check the initial state: no active stake, no committee selected
    assert!(staking.epoch() == 0);
    assert!(staking.has_pool(pool_one));
    assert!(staking.has_pool(pool_two));
    assert!(staking.committee().size() == 0);
    assert!(staking.previous_committee().size() == 0);

    // destroy empty pools
    staking.destroy_empty_pool(pool_one, ctx);
    staking.destroy_empty_pool(pool_two, ctx);

    // make sure the pools are no longer there
    assert!(!staking.has_pool(pool_one));
    assert!(!staking.has_pool(pool_two));

    destroy(staking);
    clock.destroy_for_testing();
}

#[test]
fun test_staking_active_set() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);
    let pool_three = test::pool().name(b"pool_3".to_string()).register(&mut staking, ctx);

    // now Alice, Bob, and Carl stake in the pools
    let mut wal_alice = staking.stake_with_pool(test::mint(100000, ctx), pool_one, ctx);
    let wal_alice_2 = staking.stake_with_pool(test::mint(100000, ctx), pool_one, ctx);

    wal_alice.join(wal_alice_2);

    let wal_bob = staking.stake_with_pool(test::mint(200000, ctx), pool_two, ctx);
    let wal_carl = staking.stake_with_pool(test::mint(600000, ctx), pool_three, ctx);

    // expect the active set to be modified
    assert!(staking.active_set().total_stake() == 1000000);
    assert!(staking.active_set().active_ids().length() == 3);
    assert!(staking.active_set().cur_min_stake() == 0);

    // trigger `advance_epoch` to update the committee
    staking.select_committee();
    staking.advance_epoch(vec_map::empty()); // no rewards for E0

    // we expect:
    // - all 3 pools have been advanced
    // - all 3 pools have been added to the committee
    // - shards have been assigned to the pools evenly

    destroy(wal_alice);
    destroy(staking);
    destroy(wal_bob);
    destroy(wal_carl);
    clock.destroy_for_testing();
}

#[test]
fun test_parameter_changes() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_id = test::pool()
        .commission_rate(0)
        .name(b"pool_1".to_string())
        .register(&mut staking, ctx);

    let cap = storage_node::new_cap(pool_id, ctx);

    staking.set_next_commission(&cap, 10000);
    staking.set_storage_price_vote(&cap, 100000000);
    staking.set_write_price_vote(&cap, 100000000);
    staking.set_node_capacity_vote(&cap, 10000000000000);

    // manually trigger advance epoch to apply the changes
    // TODO: this should be triggered via a system api
    staking[pool_id].advance_epoch(test::mint(0, ctx).into_balance(), &test::wctx(1, false));

    assert_eq!(staking[pool_id].storage_price(), 100000000);
    assert_eq!(staking[pool_id].write_price(), 100000000);
    assert_eq!(staking[pool_id].node_capacity(), 10000000000000);
    assert_eq!(staking[pool_id].commission_rate(), 0); // still old commission rate

    staking[pool_id].advance_epoch(test::mint(0, ctx).into_balance(), &test::wctx(2, false));

    assert_eq!(staking[pool_id].commission_rate(), 10000); // new commission rate

    destroy(staking);
    destroy(cap);
    clock.destroy_for_testing();
}

#[test]
fun test_epoch_sync_done() {
    let ctx = &mut tx_context::dummy();
    let mut clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);

    // now Alice, Bob, and Carl stake in the pools
    let wal_alice = staking.stake_with_pool(test::mint(300000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint(700000, ctx), pool_two, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee();
    staking.advance_epoch(vec_map::empty()); // no rewards for E0

    clock.increment_for_testing(EPOCH_DURATION);

    let epoch = staking.epoch();
    // send epoch sync done message from pool_one, which does not have a quorum
    let mut cap1 = storage_node::new_cap(pool_one, ctx);
    staking.epoch_sync_done(&mut cap1, epoch, &clock);

    assert!(!staking.is_epoch_sync_done());

    // send epoch sync done message from pool_two, which creates a quorum
    let mut cap2 = storage_node::new_cap(pool_two, ctx);
    staking.epoch_sync_done(&mut cap2, epoch, &clock);

    assert!(staking.is_epoch_sync_done());

    destroy(wal_alice);
    destroy(staking);
    destroy(wal_bob);
    cap1.destroy_cap_for_testing();
    cap2.destroy_cap_for_testing();
    clock.destroy_for_testing();
}

#[test, expected_failure(abort_code = staking_inner::EDuplicateSyncDone)]
fun test_epoch_sync_done_duplicate() {
    let ctx = &mut tx_context::dummy();
    let mut clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);

    // now Alice, Bob, and Carl stake in the pools
    let wal_alice = staking.stake_with_pool(test::mint(300000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint(700000, ctx), pool_two, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee();
    staking.advance_epoch(vec_map::empty()); // no rewards for E0

    clock.increment_for_testing(7 * 24 * 60 * 60 * 1000);
    let epoch = staking.epoch();
    // send epoch sync done message from pool_one, which does not have a quorum
    let mut cap = storage_node::new_cap(pool_one, ctx);
    staking.epoch_sync_done(&mut cap, epoch, &clock);

    assert!(!staking.is_epoch_sync_done());

    // try to send duplicate, test fails here
    staking.epoch_sync_done(&mut cap, epoch, &clock);

    destroy(wal_alice);
    destroy(staking);
    destroy(wal_bob);
    cap.destroy_cap_for_testing();
    clock.destroy_for_testing();
}

#[test, expected_failure(abort_code = staking_inner::EInvalidSyncEpoch)]
fun test_epoch_sync_wrong_epoch() {
    let ctx = &mut tx_context::dummy();
    let mut clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register the pool in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);

    // now Alice, Bob, and Carl stake in the pools
    let wal_alice = staking.stake_with_pool(test::mint(300000, ctx), pool_one, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee();
    staking.advance_epoch(vec_map::empty()); // no rewards for E0

    clock.increment_for_testing(7 * 24 * 60 * 60 * 1000);

    // send epoch sync done message from pool_one, which does not have a quorum
    let mut cap = storage_node::new_cap(pool_one, ctx);
    // wrong epoch, test fails here
    let wrong_epoch = staking.epoch() - 1;
    staking.epoch_sync_done(&mut cap, wrong_epoch, &clock);

    destroy(wal_alice);
    destroy(staking);
    cap.destroy_cap_for_testing();
    clock.destroy_for_testing();
}

fun dhondt_case(shards: u16, stake: vector<u64>, expected: vector<u16>) {
    use walrus::staking_inner::pub_dhondt as dhondt;
    let allocation = dhondt(shards, stake);
    assert_eq!(allocation, expected);
    assert_eq!(allocation.sum!(), shards);
}

#[test]
fun test_dhondt_basic() {
    // even
    let stake = vector[25000, 25000, 25000, 25000];
    dhondt_case(4, stake, vector[1, 1, 1, 1]);
    dhondt_case(778, stake, vector[195, 195, 194, 194]);
    dhondt_case(1000, stake, vector[250, 250, 250, 250]);
    // uneven
    let stake = vector[50000, 30000, 15000, 5000];
    dhondt_case(4, stake, vector[2, 2, 0, 0]);
    dhondt_case(777, stake, vector[389, 234, 116, 38]);
    dhondt_case(1000, stake, vector[500, 300, 150, 50]);
    // uneven+even
    let stake = vector[50000, 50000, 30000, 15000, 15000, 5000];
    dhondt_case(4, stake, vector[2, 1, 1, 0, 0, 0]);
    dhondt_case(777, stake, vector[236, 236, 142, 70, 70, 23]);
    dhondt_case(1000, stake, vector[303, 303, 182, 91, 91, 30]);
}

#[test]
fun test_dhondt_ties() {
    // even
    let stake = vector[25000, 25000, 25000, 25000];
    dhondt_case(7, stake, vector[2, 2, 2, 1]);
    dhondt_case(6, stake, vector[2, 2, 1, 1]);
    // small uneven stake
    let stake = vector[200, 200, 200, 100];
    dhondt_case(7, stake, vector[2, 2, 2, 1]);
    let stake = vector[200, 200, 200, 100, 100, 100];
    dhondt_case(9, stake, vector[2, 2, 2, 1, 1, 1]);
    // tie with many solutions
    let stake = vector[780_000, 650_000, 520_000, 390_000, 260_000];
    dhondt_case(18, stake, vector[6, 5, 4, 2, 1]);
}

#[test]
fun test_dhondt_edge_case() {
    // no shards
    let stake = vector[100, 90, 80];
    dhondt_case(0, stake, vector[0, 0, 0]);
    // low stake
    let stake = vector[1, 0, 0];
    dhondt_case(5, stake, vector[4, 1, 0]);
    // nearly identical stake
    let s = 1_000_000;
    let stake = vector[s, s - 1];
    dhondt_case(3, stake, vector[2, 1]);
    // large stake
    let stake = vector[1_000_000_000_000, 900_000_000_000, 100_000_000_000];
    dhondt_case(500, stake, vector[250, 225, 25]);
}

#[test, expected_failure(abort_code = walrus::staking_inner::ENoStake)]
fun test_dhondt_no_stake() {
    let stake = vector[0, 0, 0];
    dhondt_case(0, stake, vector[0, 0, 0]);
}

use fun sum as vector.sum;
macro fun sum<$T>($v: vector<$T>): $T {
    let v = $v;
    let mut acc = (0: $T);
    v.do!(|e| acc = acc + e);
    acc
}

#[test]
fun test_larger_dhondt_inputs_100_nodes_fixed_stake() {
    let stake_basis_points = vector::tabulate!(100, |i| {
        if (i < 5) 1250
        else if (i < 9) 733
        else if (i < 10) 728
        else 1
    });
    assert_eq!(stake_basis_points.sum!(), 10_000);
    larger_dhondt_inputs(stake_basis_points)
}

#[test]
fun test_dhondt_without_max_shards() {
    let stakes = vector[600, 100, 200, 100];
    let expected = vector[500, 125, 250, 125];
    dhondt_case(1000, stakes, expected);
}

#[test]
fun test_dhondt_with_max_shards() {
    let stakes = vector::tabulate!(21, |i| {
        if (i == 5) 200
        else 20
    });
    let expected = vector::tabulate!(21, |i| {
        if (i == 5) 100
        else 45
    });
    dhondt_case(1000, stakes, expected);
}

#[test]
fun test_larger_dhondt_inputs_1000_nodes_fixed_stake() {
    let stake_basis_points = vector::tabulate!(1000, |i| {
        if (i < 50) 125
        else if (i < 90) 60
        else if (i < 100) 45
        else 1
    });
    assert_eq!(stake_basis_points.sum!(), 10_000);
    larger_dhondt_inputs(stake_basis_points)
}

fun larger_dhondt_inputs(stake_basis_points: vector<u128>) {
    use walrus::staking_inner::pub_dhondt as dhondt;

    let total_stake = 10_000_000_000_000_000_000;
    let shards = 1_000;
    let nodes = stake_basis_points.length();
    let stake = stake_basis_points.map!(|bp| (bp * total_stake / 10_000) as u64);

    let allocation = dhondt(shards, stake);
    let mut with_shards = 0;
    let mut large_allocations = 0;
    let mut small_allocations = 0;
    allocation.do_ref!(|n| {
        if (*n > 0) with_shards = with_shards + 1;
        if (*n > 50) large_allocations = large_allocations + 1;
        if (*n < 5) small_allocations = small_allocations + 1;
    });
    assert_eq!(with_shards, nodes / 10);
    assert_eq!(allocation.sum!(), shards);
}

#[random_test]
fun test_larger_dhondt_inputs_100_nodes_random_stake(seed: vector<u8>) {
    random_dhondt_inputs(seed, 100, 10_000_000_000_000_000_000);
}

#[random_test]
fun test_larger_dhondt_inputs_1000_nodes_random_stake(seed: vector<u8>) {
    random_dhondt_inputs(seed, 1_000, 10_000_000_000_000_000_000);
}

#[random_test]
fun test_larger_dhondt_setup_1000_nodes_random_stake(seed: vector<u8>) {
    random_dhondt_setup(seed, 1_000, 10_000_000_000_000_000_000);
}

fun random_dhondt_inputs(seed: vector<u8>, nodes: u64, total_stake: u64) {
    use walrus::staking_inner::pub_dhondt as dhondt;

    let shards = 1_000;
    let stake = random_dhondt_setup(seed, nodes, total_stake);
    let allocation = dhondt(shards, stake);
    assert_eq!(allocation.sum!(), shards);
}

fun random_dhondt_setup(seed: vector<u8>, nodes: u64, mut total_stake: u64): vector<u64> {
    let mut rng = sui::random::new_generator_from_seed_for_testing(seed);
    std::u8::max_value!();
    let mut stake = vector::tabulate!(nodes, |_| {
        let stake = rng.generate_u64_in_range(1, 100) * (total_stake / 1000);
        total_stake = total_stake - stake;
        stake
    });
    *&mut stake[0] = stake[0] + total_stake;
    stake
}
