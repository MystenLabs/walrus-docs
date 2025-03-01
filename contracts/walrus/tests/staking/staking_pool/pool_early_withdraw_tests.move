// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Early withdrawal mechanics (for E0, E0', E1, E1', E2, E2'):
// ```
// - stake(E0,  AE=E1) -> immediate withdrawal(E0)              // no rewards
// - stake(E0,  AE=E1) -> request_withdraw(E0') -> withdraw(E2) // rewards for E1
// - stake(E0', AE=E2) -> immediate withdrawal(E0', E1)         // no rewards
// - stake(E0', AE=E2) -> request_withdraw(E1') -> withdraw(E3) // rewards for E2

#[allow(unused_use, unused_const)]
module walrus::pool_early_withdraw_tests;

use sui::test_utils::destroy;
use walrus::test_utils::{mint_wal_balance, frost_per_wal, pool, context_runner, assert_eq, dbg};

const E0: u32 = 0;
const E1: u32 = 1;
const E2: u32 = 2;
const E3: u32 = 3;

#[test]
// Scenario:
// 1. Alice stakes in E0,
// 2. Alice withdraws in E0 before committee selection
fun withdraw_before_activation_before_committee_selection() {
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
// 1. Alice stakes in E0 and immediately withdraws in E0
// 2. Bob stakes in E0 (and then requests after committee selection)
// 3. Charlie stakes in E0' (after committee selection) and withdraws in E1
// 4. Dave stakes in E0' (after committee selection) and requests in E1' and withdraws in E2
fun withdraw_processing_at_different_epochs() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes before committee selection, stake applied E+1
    // And she performs the withdrawal right away
    let alice = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(alice.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    let balance = pool.withdraw_stake(alice, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());
    assert_eq!(pool.wal_balance_at_epoch(E1), 0);

    // Bob stakes before committee selection, stake applied E+1
    let mut bob = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(bob.activation_epoch(), E1);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());

    let (wctx, ctx) = test.select_committee();

    // Bob requests withdrawal after committee selection
    pool.request_withdraw_stake(&mut bob, true, true, &wctx);
    assert!(bob.activation_epoch() > wctx.epoch());
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    assert_eq!(bob.withdraw_epoch(), E2);

    // Charlie stakes after committee selection, stake applied E+2
    let charlie = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(charlie.activation_epoch(), E2);

    // Dave stakes after committee selection, stake applied E+2
    let mut dave = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(dave.activation_epoch(), E2);

    // E1: Charlie withdraws his stake directly, without requesting
    let (wctx, _ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance = pool.withdraw_stake(charlie, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());

    // E1': Dave requests withdrawal
    let (wctx, _ctx) = test.select_committee();
    pool.request_withdraw_stake(&mut dave, true, true, &wctx);
    assert_eq!(dave.activation_epoch(), E2);
    assert_eq!(dave.withdraw_epoch(), E3);

    // E2: Bob withdraws his stake
    let (wctx, _ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    let balance = pool.withdraw_stake(bob, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 2000 * frost_per_wal()); // 1000 + rewards

    // E3: Dave withdraws his stake
    let (wctx, _ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    let balance = pool.withdraw_stake(dave, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 2000 * frost_per_wal()); // 1000 + rewards

    // empty wal balance but not empty pool tokens
    // because we haven't registered the pool token withdrawal
    assert_eq!(pool.wal_balance(), 0);

    pool.destroy_empty();
}

#[test, expected_failure(abort_code = walrus::staking_pool::ENotWithdrawing)]
// Scenario:
// 1. Alice stakes in E0,
// 2. Committee selected
// 3. Alice tries to withdraw and fails - need to request withdrawal first
fun request_withdraw_after_committee_selection() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes in E0, tries to withdraw after committee selection
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    assert_eq!(sw1.activation_epoch(), E1);

    let (wctx, _ctx) = test.select_committee();
    let _ = pool.withdraw_stake(sw1, true, true, &wctx).destroy_for_testing();

    abort
}

#[test, expected_failure(abort_code = walrus::staking_pool::EWithdrawDirectly)]
// Scenario (see `request_withdraw_can_withdraw_directly` for symmetrical successful case)
// 1. Alice stakes in E0 before committee selection
// 2. Alice requests withdrawal (even though it's not needed)
// 3. Failure
fun request_withdraw_when_can_withdraw_directly() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes in E0 before committee selection
    let mut sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    assert_eq!(sw1.activation_epoch(), E1);

    pool.request_withdraw_stake(&mut sw1, true, false, &wctx);

    abort
}

#[test]
// Scenario (see `request_withdraw_when_can_withdraw_directly` for symmetrical failure case)
// 1. Alice stakes in E0 before committee selection
// 2. Alice withdraws directly
fun request_withdraw_can_withdraw_directly() {
    let mut test = context_runner();
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    // Alice stakes in E0 before committee selection
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
    assert_eq!(sw1.activation_epoch(), E1);

    let balance = pool.withdraw_stake(sw1, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 1000 * frost_per_wal());

    destroy(pool);
}
