// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::pool_rounding_tests;

use walrus::{
    auth,
    test_utils::{
        mint_wal_balance,
        mint_frost_balance,
        frost_per_wal,
        pool,
        context_runner,
        assert_eq
    }
};

#[test, expected_failure(abort_code = ::walrus::staking_pool::EPoolNotEmpty)]
// Failure reason: rewards left in the pool after all stakes are withdrawn
fun split_odd_number_of_rewards_pool_leftovers_failure() {
    let mut test = context_runner();

    // E0: Alice stakes 100 WAL; Bob stakes 100 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(100), &wctx, ctx);
    let mut staked_b = pool.stake(mint_wal_balance(100), &wctx, ctx);
    assert_eq!(pool.wal_balance(), 0);

    // E1: No rewards received yet, pool is expected to join the committee
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    assert_eq!(pool.wal_balance(), 200 * frost_per_wal());

    // E2: Rewards received, Alice withdraws everything, Bob too
    // 200 FROST rewards:
    // Alice gets 201 / 2 = 100
    // Bob   gets 201 / 2 = 100
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_frost_balance(201), &wctx);
    assert_eq!(pool.wal_balance(), 201 + 200 * frost_per_wal());

    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);

    let (wctx, _) = test.next_epoch();

    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);
    let balance_b = pool.withdraw_stake(staked_b, true, false, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 100 + 100 * frost_per_wal());
    assert_eq!(balance_b.destroy_for_testing(), 100 + 100 * frost_per_wal());
    assert_eq!(pool.num_shares(), 200 * frost_per_wal()); // epoch change hasn't happened yet

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    assert_eq!(pool.num_shares(), 0); // 0 pool tokens left

    pool.destroy_empty(); // fails because there's dust in the `staked_wal`

    abort
}

#[test]
// Not failing when mixed with commission.
// Commission seems to not affect rewards calculation in terms for rounding.
fun commission_rounding_success() {
    let mut test = context_runner();

    // E0: Alice stakes 100 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().commission_rate(10_00).build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(100), &wctx, ctx);
    assert_eq!(pool.wal_balance(), 0);

    // E1: No rewards received yet, pool is expected to join the committee
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E2: Rewards received, Alice withdraws everything
    // 202 WAL rewards: Alice gets 100% of the rewards post 10% commission (20)
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_frost_balance(202), &wctx);

    assert_eq!(pool.commission_amount(), 20); // 9%
    assert_eq!(pool.wal_balance(), 182 + 100 * frost_per_wal());

    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);

    let (wctx, ctx) = test.next_epoch();
    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);
    assert_eq!(balance_a.destroy_for_testing(), 182 + 100 * frost_per_wal());

    let auth = auth::authenticate_sender(ctx);
    let commission = pool.collect_commission(auth);
    assert_eq!(commission.destroy_for_testing(), 20);

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    pool.destroy_empty();
}
