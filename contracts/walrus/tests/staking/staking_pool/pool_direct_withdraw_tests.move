// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_use, unused_const)]
module walrus::pool_direct_withdraw_tests;

use sui::test_utils::destroy;
use walrus::test_utils::{mint_wal_balance, frost_per_wal, pool, context_runner, assert_eq, dbg};

const E0: u32 = 0;
const E1: u32 = 1;
const E2: u32 = 2;
const E3: u32 = 3;

#[test]
fun withdraw_same_epoch() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes before committee selection, stake applied E+1
    // And she performs the withdrawal right away
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let balance = pool.withdraw_stake(sw1, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());
    assert_eq!(pool.wal_balance_at_epoch(E1), 0);

    destroy(pool);
}

#[test]
// Scenario:
// 1. Alice stakes before committee selection, committee selected, node is not
//    in the committee (epoch not advanced)
// 2. Alice performs immediate withdrawal from inactive pool.
fun withdraw_after_committee_selection() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes after committee selection, stake applied E+1
    // And she performs the withdrawal right away
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let (_, _) = test.next_epoch(); // E1
    let (wctx, _) = test.next_epoch(); // E2

    let balance = pool.withdraw_stake(sw1, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());
    assert_eq!(pool.wal_balance_at_epoch(E3), 0); // ERROR: balance not zero

    destroy(pool);
}

#[test]
// Scenario:
// 1. Alice stakes before committee selection, so does Bob.
// 2. Pool is in the committee and selects rewards, then Bob requests withdrawal.
// 3. Pool is not in the committee, Bob withdraws his stake in a regular way.
// 4. Alice performs immediate withdrawal from inactive pool.
fun withdraw_after_the_pool_became_inactive() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes before committee selection, stake applied E+1
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    // Bob stakes before committee selection, stake applied E+1
    let mut sw2 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw2.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 2000 * frost_per_wal());

    let (wctx, _) = test.next_epoch(); // E1
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    let (wctx, _) = test.next_epoch(); // E2
    pool.advance_epoch(mint_wal_balance(2000), &wctx);

    // Bob requests withdrawal (E2)
    pool.request_withdraw_stake(&mut sw2, true, false, &wctx);
    assert_eq!(pool.wal_balance_at_epoch(E2), 4000 * frost_per_wal()); // same epoch
    assert_eq!(pool.wal_balance_at_epoch(E3), 2000 * frost_per_wal()); // next, after request

    let (wctx, _) = test.next_epoch(); // E3 (Bob's withdrawal)
    pool.advance_epoch(mint_wal_balance(2000), &wctx);

    // Bob withdraws his stake (E3)
    let balance = pool.withdraw_stake(sw2, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 3000 * frost_per_wal());

    // Pool is inactive, Alice performs immediate withdrawal
    // Alice performs immediate withdrawal
    let balance = pool.withdraw_stake(sw1, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 3000 * frost_per_wal());
    assert_eq!(pool.wal_balance_at_epoch(E3), 0);

    destroy(pool);
}

#[test]
// Scenario:
// - same as above, but Bob directly withdraws once the pool is inactive;
fun withdraw_after_the_pool_became_inactive_alternative() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes before committee selection, stake applied E+1
    // Bob stakes before committee selection, stake applied E+1
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    let mut sw2 = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    let (wctx, _) = test.next_epoch(); // E1
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    let (wctx, _) = test.next_epoch(); // E2
    pool.advance_epoch(mint_wal_balance(2000), &wctx);

    // Bob requests withdrawal (E2)
    pool.request_withdraw_stake(&mut sw2, true, false, &wctx);

    let (wctx, _) = test.next_epoch(); // E3 (Bob's withdrawal)
    pool.advance_epoch(mint_wal_balance(2000), &wctx);

    // Bob directly withdraws his stake (E3)
    let balance = pool.withdraw_stake(sw2, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 3000 * frost_per_wal());

    // Alice directly withdraws her stake (E3)
    let balance = pool.withdraw_stake(sw1, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 3000 * frost_per_wal());
    assert_eq!(pool.wal_balance_at_epoch(E3), 0);

    destroy(pool);
}

#[test, expected_failure(abort_code = walrus::staking_pool::EWithdrawDirectly)]
// Scenario:
// - try to request withdrawal for an inactive pool
fun try_to_request_withdrawal_for_inactive_pool() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes after committee selection, stake applied E+1
    // And she performs the withdrawal right away
    let mut sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let (_, _) = test.next_epoch(); // E1
    let (wctx, _) = test.next_epoch(); // E2

    pool.request_withdraw_stake(&mut sw1, false, false, &wctx);

    abort
}

#[test]
// Scenario:
// - withdraw pre-active stake from inactive pool
fun direct_withdraw_for_inactive_pool_pre_active_stake() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    let balance = pool.withdraw_stake(sw1, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());

    let (_, _) = test.next_epoch(); // E1
    assert_eq!(pool.wal_balance_at_epoch(E1), 0);

    destroy(pool);
}

#[test]
// Scenario:
// - withdraw active stake from inactive pool
fun direct_withdraw_for_inactive_pool_active_stake() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(sw1.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let (_, _) = test.next_epoch(); // E1
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let balance = pool.withdraw_stake(sw1, false, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());

    destroy(pool);
}
