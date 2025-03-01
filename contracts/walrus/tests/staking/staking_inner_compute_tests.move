// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::staking_inner_compute_tests;

use sui::{clock, test_utils::destroy};
use walrus::{staking_inner, test_utils as test};

const EPOCH_DURATION: u64 = 7 * 24 * 60 * 60 * 1000;

#[test]
fun test_compute_single_node() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 10, &clock, ctx);
    let pool_one = test::pool().register(&mut staking, ctx);
    let wal_alice = staking.stake_with_pool(test::mint_wal(1_000_000, ctx), pool_one, ctx);

    let committee = staking.compute_next_committee();

    assert!(committee.size() == 1);
    assert!(committee[&pool_one].length() == 10);

    destroy(wal_alice);
    destroy(staking);
    clock.destroy_for_testing();
}

#[test]
fun test_compute_even_distribution() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 6, &clock, ctx);

    let pool_one = test::pool().register(&mut staking, ctx);
    let pool_two = test::pool().register(&mut staking, ctx);
    let pool_three = test::pool().register(&mut staking, ctx);

    let wal_alice = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_two, ctx);
    let wal_karl = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_three, ctx);

    let committee = staking.compute_next_committee();

    assert!(committee.size() == 3);
    assert!(committee[&pool_one].length() == 2);
    assert!(committee[&pool_two].length() == 2);
    assert!(committee[&pool_three].length() == 2);

    destroy(wal_alice);
    destroy(wal_bob);
    destroy(wal_karl);
    destroy(staking);
    clock.destroy_for_testing();
}

#[test]
fun test_compute_uneven_distribution() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 10, &clock, ctx);

    let pool_one = test::pool().register(&mut staking, ctx);
    let pool_two = test::pool().register(&mut staking, ctx);
    let pool_three = test::pool().register(&mut staking, ctx);

    let wal_alice = staking.stake_with_pool(test::mint_wal(4_000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(2_000, ctx), pool_two, ctx);
    let wal_karl = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_three, ctx);

    let committee = staking.compute_next_committee();

    assert!(committee.size() == 3);
    assert!(committee[&pool_one].length() == 6);
    assert!(committee[&pool_two].length() == 3);
    assert!(committee[&pool_three].length() == 1);

    destroy(wal_alice);
    destroy(wal_bob);
    destroy(wal_karl);
    destroy(staking);
    clock.destroy_for_testing();
}

#[test]
fun test_compute_equal_stake_nodes() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 10, &clock, ctx);

    let pool_one = test::pool().register(&mut staking, ctx);
    let pool_two = test::pool().register(&mut staking, ctx);
    let pool_three = test::pool().register(&mut staking, ctx);

    let wal_alice = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_one, ctx);
    let wal_bob = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_two, ctx);
    let wal_karl = staking.stake_with_pool(test::mint_wal(1_000, ctx), pool_three, ctx);

    let committee = staking.compute_next_committee();

    assert!(committee.size() == 3);
    assert!(committee[&pool_one].length() == 4);
    assert!(committee[&pool_two].length() == 3);
    assert!(committee[&pool_three].length() == 3);

    destroy(wal_alice);
    destroy(wal_bob);
    destroy(wal_karl);
    destroy(staking);
    clock.destroy_for_testing();
}

#[test]
fun test_compute_large_committee() {
    let ctx = &mut tx_context::dummy();
    let clock = clock::create_for_testing(ctx);
    let mut staking = staking_inner::new(0, EPOCH_DURATION, 100, &clock, ctx);

    let n_nodes: u16 = 20;
    let mut staked_wals = vector::empty();

    n_nodes.do!(|i| {
        let pool = test::pool().register(&mut staking, ctx);
        let stake = 1_000 + i;
        staked_wals.push_back(staking.stake_with_pool(
            test::mint_wal(stake as u64, ctx),
            pool,
            ctx,
        ));
    });

    let committee = staking.compute_next_committee();
    assert!(committee.size() == 20);

    destroy(staking);
    destroy(staked_wals);
    clock.destroy_for_testing();
}
