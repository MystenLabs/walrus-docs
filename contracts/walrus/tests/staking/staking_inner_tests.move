// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::staking_inner_tests;

use std::unit_test::assert_eq;
use sui::{clock, test_utils::destroy, vec_map};
use walrus::{staking_inner, storage_node, test_utils::{Self as test, frost_per_wal}};

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
fun test_staking_rejoin_active_set() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // Reduce the active set size for testing.
    let active_set_size = 10;
    staking.active_set().set_max_size(active_set_size);

    // Register more pools than the active set size
    let mut pools = vector[];
    (active_set_size + 1).do!(|_| {
        let pool = test::pool().register(&mut staking, ctx);
        pools.push_back(pool);
    });

    // Now stake with all pools, pool 0 should be kicked out of the active set once
    // the last staking operation is performed.
    let mut staked_wal = vector[];
    let mut stake_amount = 10_000;
    pools.do_ref!(|pool| {
        let wal = staking.stake_with_pool(test::mint_wal(stake_amount, ctx), *pool, ctx);
        staked_wal.push_back(wal);
        // Increase the stake amount to have a clear ordering.
        stake_amount = stake_amount + 1;
        // Check that the new pool is in the active set.
        assert!(staking.active_set().active_ids().contains(pool));
    });

    // Check that pool 0 was removed from the active set.
    assert!(!staking.active_set().active_ids().contains(&pools[0]));

    // Try to rejoin the active set with pool 0.
    let cap = storage_node::new_cap(pools[0], ctx);
    staking.try_join_active_set(&cap);

    // This should not change anything since the node does not have enough stake.
    assert!(!staking.active_set().active_ids().contains(&pools[0]));

    // Now unstake from the pool 1, which puts its stake below the stake of pool 0.
    let staked_wal_1 = staked_wal.swap_remove(1);
    let coin = staking.withdraw_stake(staked_wal_1, ctx);
    // But pool 0 is still not in the active set.
    assert!(!staking.active_set().active_ids().contains(&pools[0]));

    // Now try to rejoin the active set with pool 0
    staking.try_join_active_set(&cap);
    // Check that the pool is now in the active set.
    assert!(staking.active_set().active_ids().contains(&pools[0]));
    // And pool 1 has been removed from the active set.
    assert!(!staking.active_set().active_ids().contains(&pools[1]));

    // Cleanup all objects.
    destroy(staked_wal);
    destroy(pools);
    destroy(staking);
    destroy(coin);
    destroy(cap);
    clock.destroy_for_testing();
}

#[test]
fun test_staking_active_set() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);

    // register pools in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);
    let pool_three = test::pool().name(b"pool_3".to_string()).register(&mut staking, ctx);

    // now Alice, Bob, and Carl stake in the pools
    let mut wal_alice = staking.stake_with_pool(test::mint_wal(100000, ctx), pool_one, ctx);
    let wal_alice_2 = staking.stake_with_pool(test::mint_wal(100000, ctx), pool_one, ctx);

    wal_alice.join(wal_alice_2);

    let wal_bob = staking.stake_with_pool(test::mint_wal(200000, ctx), pool_two, ctx);
    let wal_carl = staking.stake_with_pool(test::mint_wal(600000, ctx), pool_three, ctx);

    // expect the active set to be modified
    assert!(staking.active_set().total_stake() == 1000000 * frost_per_wal());
    assert!(staking.active_set().active_ids().length() == 3);
    assert!(staking.active_set().cur_min_stake() == 0);

    // trigger `advance_epoch` to update the committee
    staking.select_committee_and_calculate_votes();
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
// Scenario:
// 1. Alice stakes for pool_one enough for it to be in the active set.
// 2. Bob and Carl stake for pool_two and pool_three, respectively.
// 3. Alice unstakes from pool_one.
// 4. Advance epoch.
// 5. Expecting pool_one to NOT be in the active set.
fun test_staking_active_set_early_withdraw() {
    let ctx = &mut tx_context::dummy();
    let mut staking = {
        let clock = clock::create_for_testing(ctx);
        let staking = staking_inner::new(0, EPOCH_DURATION, 300, &clock, ctx);
        clock.destroy_for_testing();
        staking
    };

    // register pools in the `StakingInnerV1`.
    let pool_one = test::pool().name(b"pool_1".to_string()).register(&mut staking, ctx);
    let pool_two = test::pool().name(b"pool_2".to_string()).register(&mut staking, ctx);
    let pool_three = test::pool().name(b"pool_3".to_string()).register(&mut staking, ctx);

    // Alice stakes for pool_one
    let wal_alice = staking.stake_with_pool(test::mint_wal(100_000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(100_000, ctx), pool_two, ctx);
    let wal_carl = staking.stake_with_pool(test::mint_wal(100_000, ctx), pool_three, ctx);

    let active_ids = staking.active_set().active_ids();
    assert!(active_ids.contains(&pool_one));
    assert!(active_ids.contains(&pool_two));
    assert!(active_ids.contains(&pool_three));

    // Alice performs an early withdraw
    assert_eq!(
        staking.withdraw_stake(wal_alice, ctx).burn_for_testing(),
        100_000 * frost_per_wal(),
    );

    // make sure the node is removed from active set
    let active_ids = staking.active_set().active_ids();
    assert!(!active_ids.contains(&pool_one));
    assert!(active_ids.contains(&pool_two));
    assert!(active_ids.contains(&pool_three));

    staking.select_committee_and_calculate_votes();
    staking.advance_epoch(vec_map::empty());

    let cmt = staking.committee();

    assert!(!cmt.contains(&pool_one)); // should not be in the set
    assert!(cmt.contains(&pool_two));
    assert!(cmt.contains(&pool_three));

    destroy(vector[wal_bob, wal_carl]);
    destroy(staking);
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
    staking[pool_id].advance_epoch(test::mint_wal(0, ctx).into_balance(), &test::wctx(1, false));

    assert_eq!(staking[pool_id].storage_price(), 100000000);
    assert_eq!(staking[pool_id].write_price(), 100000000);
    assert_eq!(staking[pool_id].node_capacity(), 10000000000000);
    assert_eq!(staking[pool_id].commission_rate(), 0); // still old commission rate

    staking[pool_id].advance_epoch(test::mint_wal(0, ctx).into_balance(), &test::wctx(2, false));

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
    let wal_alice = staking.stake_with_pool(test::mint_wal(300000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(700000, ctx), pool_two, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee_and_calculate_votes();
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
    let wal_alice = staking.stake_with_pool(test::mint_wal(300000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(700000, ctx), pool_two, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee_and_calculate_votes();
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
    let wal_alice = staking.stake_with_pool(test::mint_wal(300000, ctx), pool_one, ctx);

    // trigger `advance_epoch` to update the committee and set the epoch state to sync
    staking.select_committee_and_calculate_votes();
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
