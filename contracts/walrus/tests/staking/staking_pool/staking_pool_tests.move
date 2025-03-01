// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::staking_pool_tests;

use sui::test_utils::destroy;
use walrus::test_utils::{mint_wal_balance, pool, context_runner, assert_eq, frost_per_wal};

#[test]
// Scenario: Alice stakes, pool receives rewards, Alice withdraws everything
fun stake_and_receive_rewards() {
    let mut test = context_runner();

    // E0: Alice stakes 1000 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    assert_eq!(pool.wal_balance(), 0);

    // E1: No rewards received, stake is active an rewards will be claimable in
    //  the future
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    assert_eq!(pool.wal_balance(), 1000 * frost_per_wal());

    // E2: Rewards received, Alice withdraws everything
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);

    assert_eq!(pool.wal_balance(), 2000 * frost_per_wal());
    assert!(staked_a.is_withdrawing());

    // E3: Alice withdraws everything
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 2000 * frost_per_wal());
    assert_eq!(pool.wal_balance(), 0);

    pool.destroy_empty()
}

#[test]
// Scenario:
// Epoch 0: Alice stakes 1000
// Epoch 1: Bob stakes 1000
// Epoch 2: No rewards; Alice requests withdrawal before committee selection
// Epoch 3: No rewards, Bob requests withdrawal before committee selection, Alice withdraws
// Epoch 4: Bob withdraws, pool is empty
fun stake_no_rewards_different_epochs() {
    let mut test = context_runner();

    // E0: Alice stakes 1000 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    assert_eq!(pool.wal_balance(), 0);

    // E1: Bob stakes 1000 WAL
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let mut staked_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    assert_eq!(pool.wal_balance(), 1000 * frost_per_wal());

    // E2: Alice requests withdrawal, expecting to withdraw 1000 WAL + 100 rewards.
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);

    assert_eq!(pool.wal_balance(), 2000 * frost_per_wal());
    assert!(staked_a.is_withdrawing());

    // E3: Bob requests withdrawal
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);
    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);

    assert_eq!(pool.wal_balance(), 1000 * frost_per_wal());
    assert_eq!(balance_a.destroy_for_testing(), 1000 * frost_per_wal());
    assert!(staked_b.is_withdrawing());

    // E5: Bob withdraws
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance_b = pool.withdraw_stake(staked_b, true, false, &wctx);
    assert_eq!(balance_b.destroy_for_testing(), 1000 * frost_per_wal());

    pool.destroy_empty()
}

#[test]
// Scenario: Alice stakes, Bob stakes, pool receives rewards, Alice withdraws, Bob withdraws
fun stake_and_receive_partial_rewards() {
    let mut test = context_runner();

    // E0: Alice stakes 1000 WAL, Bob stakes 1000 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    let mut staked_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // E1: No rewards received, stake is active an rewards will be claimable in
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E1: Rewards received, Alice requests withdrawal of 1000 WAL + rewards
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);

    // E2: Alice withdraws 500 WAL + rewards
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);
    // Check that we're within a small rounding error
    assert!(balance_a.destroy_for_testing().diff(1500 * frost_per_wal()) < 10);

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E3: Bob a little late to withdraw
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance_b = pool.withdraw_stake(staked_b, true, false, &wctx);
    // Check that we're within a small rounding error
    assert!(balance_b.destroy_for_testing().diff(1500 * frost_per_wal()) < 10);

    pool.destroy_empty()
}

#[test]
// Scenario:
// E0: Alice stakes 1000
// E1: No rewards, Alice splits stake
// E2: 1000 rewards received, Alice requests half of the stake (500)
// E3: 1000 rewards received, Alice requests the rest of the stake, withdraws first half (500 + 500)
// E4: Alice withdraws (500 + 1000), pool is empty
fun stake_split_stake() {
    let mut test = context_runner();

    // E0
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // E1
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let mut staked_b = staked_a.split(500 * frost_per_wal(), ctx);

    // E2
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);

    // E3
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);
    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 1500 * frost_per_wal());

    // E4
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let balance_b = pool.withdraw_stake(staked_b, true, false, &wctx);

    assert_eq!(balance_b.destroy_for_testing(), 1500 * frost_per_wal());

    pool.destroy_empty()
}

#[test]
// Scenario:
// E0: Alice stakes: 1000 WAL;
// E1: Bob stakes: 2000 WAL;
// E2: +1000 Rewards; Alice requests withdrawal;
// E3: +1000 Rewards; Alice withdraws (1000 + 1500);  Bob requests withdrawal;
// E4: Bob withdraws (2000 + 1000); pool is empty
fun stake_maintain_ratio() {
    let mut test = context_runner();

    // E0: Alice stakes 1000 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // E1: Bob stakes 2000 WAL
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let mut staked_b = pool.stake(mint_wal_balance(2000), &wctx, ctx);

    // E2: +1000 Rewards; Alice requests withdrawal
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);
    assert!(staked_a.is_withdrawing());

    // E3: +1000 Rewards; Alice withdraws (1000 + 1000); Bob requests withdrawal
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);
    assert!(staked_b.is_withdrawing());

    let balance_a = pool.withdraw_stake(staked_a, true, false, &wctx);
    assert_eq!(balance_a.destroy_for_testing(), 2500 * frost_per_wal());

    // E4: Bob withdraws (1000 + 1000); pool is empty
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    let balance_b = pool.withdraw_stake(staked_b, true, false, &wctx);
    assert_eq!(balance_b.destroy_for_testing(), 2500 * frost_per_wal());

    pool.destroy_empty()
}

const E0: u32 = 0;
const E1: u32 = 1;
const E2: u32 = 2;
const E3: u32 = 3;
const E4: u32 = 4;
const E5: u32 = 5;
const E6: u32 = 5;

#[test]
// This test focuses on maintaining correct staked_wal state throughout the
// staking process. Alice and Bob add stake,
fun wal_balance_at_epoch() {
    let mut test = context_runner();

    // E0:
    // A stakes 1000 (E1)
    // B stakes 1000 (E2)
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    assert_eq!(pool.wal_balance(), 0);

    let mut staked_wal_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    {
        assert_eq!(pool.wal_balance(), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
    };

    // E0+: committee has been selected, another stake applied in E+2
    let (wctx, ctx) = test.select_committee();
    let mut staked_wal_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E0), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 2000 * frost_per_wal());
    };

    // === E1 ===

    // E1:
    // A - active 1000 (E1)
    // B - inactive 1000 (E2)
    // C - stakes 2000 (E2)
    // D - stakes 2000 (E3)
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 2000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 2000 * frost_per_wal());
    };

    // add stake
    let mut staked_wal_c = pool.stake(mint_wal_balance(2000), &wctx, ctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 4000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 4000 * frost_per_wal());
    };

    // E1+: committee selected, another stake applied in E+3
    let (wctx, ctx) = test.select_committee();
    let mut staked_wal_d = pool.stake(mint_wal_balance(2000), &wctx, ctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E1), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 4000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 6000 * frost_per_wal());
    };

    // === E2 ===

    // E2:
    // A - active 1000 + 1000 (E1)
    // B - active 1000 (E2)
    // C - active 2000 (E2)
    // D - inactive 2000 (E3)
    //
    // A requests withdrawal in E3
    // B requests withdrawal in E4
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E2), 5000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 7000 * frost_per_wal()); // D stake applied
        assert_eq!(pool.wal_balance_at_epoch(E4), 7000 * frost_per_wal()); // D stake applied
    };

    pool.request_withdraw_stake(&mut staked_wal_a, true, false, &wctx); // -2000 E+1

    {
        assert_eq!(pool.wal_balance_at_epoch(E2), 5000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 5000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E4), 5000 * frost_per_wal());
    };

    // E2+: committee selected, another stake applied in E+2
    let (wctx, _) = test.select_committee();
    pool.request_withdraw_stake(&mut staked_wal_b, true, true, &wctx); // -1000 E+2

    {
        assert_eq!(pool.wal_balance_at_epoch(E2), 5000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 5000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E4), 4000 * frost_per_wal());
    };

    // === E3 ===

    // E3:
    // A - inactive 2000 + 2000 (W in E3)
    // B - active 1000 + 1000 (W in E4)
    // C - active 2000 + 2000
    // D - active 2000
    //
    // C requests withdrawal in E4
    // D requests withdrawal in E5
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(5000), &wctx);

    // Stake A will withdraw an epoch later to test the behavior

    {
        assert_eq!(pool.wal_balance_at_epoch(E3), 8000 * frost_per_wal()); // A (-4000) D (+2000)
        assert_eq!(pool.wal_balance_at_epoch(E4), 6000 * frost_per_wal()); // B (-2000)
        assert_eq!(pool.wal_balance_at_epoch(E5), 6000 * frost_per_wal());
    };

    pool.request_withdraw_stake(&mut staked_wal_c, true, false, &wctx); // C (-4000)

    {
        assert_eq!(pool.wal_balance_at_epoch(E3), 8000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E4), 2000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E5), 2000 * frost_per_wal());
    };

    // E3+: committee selected, D requests withdrawal
    let (wctx, _) = test.select_committee();
    pool.request_withdraw_stake(&mut staked_wal_d, true, true, &wctx); // D (-2000)

    {
        assert_eq!(pool.wal_balance_at_epoch(E3), 8000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E4), 2000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E5), 0);
    };

    // === E4 ===

    // E3: B, C and D receive rewards (4000)
    // A is excluded
    // B - inactive 2000 + 1000
    // C - inactive 4000 + 2000
    // D - active 2000 + 1000 (W in E5)
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(4000), &wctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E4), 3000 * frost_per_wal()); // only D active
        assert_eq!(pool.wal_balance_at_epoch(E5), 0); // D withdrawn
        assert_eq!(pool.wal_balance_at_epoch(E6), 0);
    };

    // === E5 ===

    // E5:
    // A - inactive 6000
    // B - inactive 3000
    // C - inactive 6000
    // D - inactive 3000
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    assert_eq!(pool.wal_balance_at_epoch(E5), 0);

    let balance_a = pool.withdraw_stake(staked_wal_a, true, false, &wctx);
    let balance_b = pool.withdraw_stake(staked_wal_b, true, false, &wctx);
    let balance_c = pool.withdraw_stake(staked_wal_c, true, false, &wctx);
    let balance_d = pool.withdraw_stake(staked_wal_d, true, false, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 4000 * frost_per_wal());
    assert_eq!(balance_b.destroy_for_testing(), 3000 * frost_per_wal());
    assert_eq!(balance_c.destroy_for_testing(), 6000 * frost_per_wal());
    assert_eq!(balance_d.destroy_for_testing(), 3000 * frost_per_wal());

    pool.destroy_empty()
}

#[test]
// Check that wal_balance_at_epoch correctly updates after a pre-active stake
// withdrawal.
fun wal_balance_after_pre_active_withdrawal() {
    let mut test = context_runner();

    // E0:
    // A stakes 1000 (E1)
    // B stakes 500 (E1)
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);

    assert_eq!(pool.wal_balance(), 0);

    let mut staked_wal_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    let mut staked_wal_b = pool.stake(mint_wal_balance(500), &wctx, ctx);

    {
        assert_eq!(pool.wal_balance(), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 1500 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 1500 * frost_per_wal());
    };

    // E0+: committee has been selected, B unstakes pre-active stake, C stakes 1000 (E2)
    let (wctx, ctx) = test.select_committee();
    pool.request_withdraw_stake(&mut staked_wal_b, true, true, &wctx); // -1000 E+1
    let staked_wal_c = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    {
        assert_eq!(pool.wal_balance_at_epoch(E0), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 1500 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 2000 * frost_per_wal());
    };

    // Since we are still in E0, the stake is not active yet
    // and can be withdrawn immediately.
    let balance_c = pool.withdraw_stake(staked_wal_c, true, false, &wctx);

    {
        assert_eq!(pool.wal_balance_at_epoch(E0), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 1500 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
    };

    // Clean up the pool
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    pool.request_withdraw_stake(&mut staked_wal_a, true, false, &wctx);

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    let balance_a = pool.withdraw_stake(staked_wal_a, true, false, &wctx);
    let balance_b = pool.withdraw_stake(staked_wal_b, true, false, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 1000 * frost_per_wal());
    assert_eq!(balance_b.destroy_for_testing(), 500 * frost_per_wal());
    assert_eq!(balance_c.destroy_for_testing(), 1000 * frost_per_wal());

    pool.destroy_empty()
}

#[test]
// Check that wal_balance_at_epoch correctly updates if a stake is withdrawn
// after two epochs.
fun wal_balance_with_withdrawal_after_two_epochs() {
    let mut test = context_runner();

    let (wctx, ctx) = test.select_committee();
    let mut pool = pool().build(&wctx, ctx);
    assert_eq!(pool.wal_balance(), 0);
    {
        assert_eq!(pool.wal_balance(), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 0);
        assert_eq!(pool.wal_balance_at_epoch(E2), 0);
    };

    // E0:
    // A stakes 1000
    let mut staked_wal_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    {
        assert_eq!(pool.wal_balance(), 0);
        assert_eq!(pool.wal_balance_at_epoch(E1), 0);
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
    };
    test.next_epoch();
    let (wctx, _) = test.select_committee();

    // E1:
    {
        assert_eq!(pool.wal_balance_at_epoch(E1), 0);
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 1000 * frost_per_wal());
    };

    pool.request_withdraw_stake(&mut staked_wal_a, true, true, &wctx);
    {
        assert_eq!(pool.wal_balance_at_epoch(E1), 0);
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 0);
    };
    test.next_epoch();
    let (wctx, _) = test.select_committee();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E2:
    {
        assert_eq!(pool.wal_balance_at_epoch(E2), 1000 * frost_per_wal());
        assert_eq!(pool.wal_balance_at_epoch(E3), 0);
    };
    let (_, _) = test.next_epoch();
    let (wctx, _) = test.select_committee();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E3:
    {
        assert_eq!(pool.wal_balance_at_epoch(E3), 0);
    };

    let balance_a = pool.withdraw_stake(staked_wal_a, true, true, &wctx);

    assert_eq!(balance_a.destroy_for_testing(), 1000 * frost_per_wal());
    pool.destroy_empty()
}

#[test]
// Scenario:
// E0: Alice stakes: 1000 WAL;
// E1: Bob stakes: 1000 WAL; Chalie stakes: 1000 WAL;
// E2: +1000 Rewards for E1; Alice requests withdrawal;
// E3: +1000 Rewards for E2; Bob requests withdrawal;
// E4: +1000 Rewards for E3;
// E5: +1000 Rewards for E4;
fun correct_stake_with_withdrawals() {
    let mut test = context_runner();

    // E0: Alice stakes 1000 WAL
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // No rewards yet, stake for next committee selection is 1000
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 1000 * frost_per_wal());

    // E1: Bob stakes 1000 WAL; Chalie stakes 1000 WAL;
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let mut staked_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    let staked_c = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // No rewards yet, stake for next committee selection is 3000
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 3000 * frost_per_wal());

    // E2: +1000 Rewards for E1; Alice requests withdrawal
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_a, true, false, &wctx);

    // All rewards for the previous epoch go to Alice, Alice's stake does not count anymore.
    // Stake is 2000 (Bob + Chalie)
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 2000 * frost_per_wal());

    // E3: +1000 Rewards for E2; Bob requests withdrawal
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);
    pool.request_withdraw_stake(&mut staked_b, true, false, &wctx);

    // Half of the rewards for the previous epoch go to Alice, a quarter to Bob and Charlie each.
    // Alice's and Bob's stakes does not count anymore.
    // Stake is 1250 (Chalie + rewards on his stake)
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 1250 * frost_per_wal());

    // E4: +1000 Rewards for E3;
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    // Half of the rewards for the previous epoch go to Bob and Charlie each.
    // Alice's and Bob's stakes does not count anymore.
    // Stake is 1750 (Chalie + rewards on his stake)
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 1750 * frost_per_wal());

    // E5: +1000 Rewards for E4;
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    // All rewards go to Charlie
    // Stake is 2750 (Chalie + rewards on his stake)
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 2750 * frost_per_wal());

    destroy(pool);
    destroy(vector[staked_a, staked_b, staked_c]);
}

#[test]
// Alice stakes 1000 in E0, Bob stakes 1000 in E1, Alice withdraws in E2, Bob withdraws in E3
// We expect Alice to withdraw 1000 in E3 + rewards, Bob to withdraw 1000 in E4 without rewards
fun pool_token_with_rewards_at_epochs() {
    let mut test = context_runner();

    // E0: stake applied in E+1
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_wal_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E1: node is in the committee, rewards are distributed, 1000 WAL received
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    // 1000 + 1000 rewards
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch()), 2000 * frost_per_wal());

    // bob stakes in E+1, stake applied in E+2
    let mut staked_wal_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 3000 * frost_per_wal());

    // E+1, request withdraw stake A (to withdraw in E+2)
    pool.request_withdraw_stake(&mut staked_wal_a, true, false, &wctx);

    assert!(staked_wal_a.is_withdrawing());
    assert_eq!(staked_wal_a.withdraw_epoch(), wctx.epoch() + 1);
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch() + 1), 1000 * frost_per_wal());

    // E+2, withdraw stake A
    let (wctx, _) = test.next_epoch();

    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E+2, withdraw stake A, request withdraw stake B
    let balance = pool.withdraw_stake(staked_wal_a, true, false, &wctx);
    assert_eq!(balance.destroy_for_testing(), 2000 * frost_per_wal()); // 1000 + 1000 rewards

    pool.request_withdraw_stake(&mut staked_wal_b, true, false, &wctx);

    // E+3, withdraw stake B
    let (wctx, _) = test.next_epoch();

    pool.advance_epoch(mint_wal_balance(0), &wctx);

    let coin = pool.withdraw_stake(staked_wal_b, true, false, &wctx);
    assert_eq!(coin.destroy_for_testing(), 1000 * frost_per_wal());

    destroy(pool);
}

#[test]
// Alice stakes 1000 in E0, Bob stakes 1000 in E0, Pool receives 1000 rewards in E1
// Alice withdraws in E2, Bob withdraws in E2, rewards are split between Alice and Bob
fun pool_token_split_rewards() {
    let mut test = context_runner();

    // E0: stake applied in E+1
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut staked_wal_a = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    let mut staked_wal_b = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E1: node is in the committee, rewards are distributed, 1000 WAL received
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(1000), &wctx);

    // 1000 + 1000 rewards
    assert_eq!(pool.wal_balance_at_epoch(wctx.epoch()), 3000 * frost_per_wal());

    // E+1, request withdraw stake A and B (to withdraw in E+2)
    pool.request_withdraw_stake(&mut staked_wal_a, true, false, &wctx);
    pool.request_withdraw_stake(&mut staked_wal_b, true, false, &wctx);

    let (wctx, _) = test.next_epoch();

    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // E+2, withdraw stake A and B
    let balance_a = pool.withdraw_stake(staked_wal_a, true, false, &wctx);
    let balance_b = pool.withdraw_stake(staked_wal_b, true, false, &wctx);

    // Due to rounding on low values, we cannot check the exact value, but
    // we check that the difference is small
    // 1000 + 500 rewards
    assert!(balance_a.destroy_for_testing().diff(1500 * frost_per_wal()) < 10);
    // 1000 + 500 rewards
    assert!(balance_b.destroy_for_testing().diff(1500 * frost_per_wal()) < 10);

    destroy(pool);
}

#[test]
fun test_advance_pool_epoch() {
    let mut test = context_runner();

    // create pool with commission rate 1000.
    let (wctx, ctx) = test.current();
    let mut pool = pool()
        .commission_rate(1_00)
        .write_price(1)
        .storage_price(1)
        .node_capacity(1)
        .build(&wctx, ctx);

    assert_eq!(pool.wal_balance(), 0);
    assert_eq!(pool.commission_rate(), 1_00);
    assert_eq!(pool.write_price(), 1);
    assert_eq!(pool.storage_price(), 1);
    assert_eq!(pool.node_capacity(), 1);

    pool.set_next_node_capacity(1000);
    pool.set_next_storage_price(100);
    pool.set_next_write_price(100);

    // pool changes commission rate to 10% in epoch E+2
    pool.set_next_commission(10_00, &wctx);

    // TODO: commission rate should be applied in E+2
    // eq assert!(pool.commission_rate(), 1000);
    // other voting parameters are applied instantly,
    // given that they are only counted in the committee selection.
    assert_eq!(pool.node_capacity(), 1000);
    assert_eq!(pool.write_price(), 100);
    assert_eq!(pool.storage_price(), 100);

    // Alice stakes before committee selection, stake applied E+1
    // Bob stakes after committee selection, stake applied in E+2
    let sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    let (wctx, ctx) = test.select_committee();
    let sw2 = pool.stake(mint_wal_balance(1000), &wctx, ctx);
    assert_eq!(pool.wal_balance(), 0);

    // advance epoch to 2
    // we expect Alice's stake to be applied already, Bob's not yet
    // and parameters to be updated
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    assert_eq!(pool.wal_balance(), 1000 * frost_per_wal());
    assert_eq!(pool.commission_rate(), 1_00); // still the old value
    assert_eq!(pool.node_capacity(), 1000);
    assert_eq!(pool.write_price(), 100);
    assert_eq!(pool.storage_price(), 100);

    // update just one parameter
    pool.set_next_write_price(1000);
    assert_eq!(pool.write_price(), 1000);

    // advance epoch to 3
    // we expect Bob's stake to be applied
    // and commission rate to be updated
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    assert_eq!(pool.wal_balance(), 2000 * frost_per_wal());
    assert_eq!(pool.write_price(), 1000);
    assert_eq!(pool.commission_rate(), 10_00);

    destroy(pool);
    destroy(sw1);
    destroy(sw2);
}

#[test]
// Scenario:
// - E0: Alice stakes
// - E1: Bob stakes
// - E2: Nothing
// - E3: Alice requests withdrawal, so does Bob
// - E4+: Join staked wal, withdraw
fun staked_wal_join_different_activation_epochs() {
    let mut test = context_runner();

    // E0
    let (wctx, ctx) = test.current();
    let mut pool = pool().build(&wctx, ctx);
    let mut sw1 = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // E1
    let (wctx, ctx) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let mut sw2 = pool.stake(mint_wal_balance(1000), &wctx, ctx);

    // E2, then E3
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    pool.request_withdraw_stake(&mut sw1, true, false, &wctx);
    pool.request_withdraw_stake(&mut sw2, true, false, &wctx);

    // E4
    let (wctx, _) = test.next_epoch();
    pool.advance_epoch(mint_wal_balance(0), &wctx);

    // Two different activation epochs, but the same withdraw epoch
    assert!(sw1.activation_epoch() != sw2.activation_epoch());
    assert_eq!(sw1.withdraw_epoch(), sw2.withdraw_epoch());
    sw1.join(sw2);

    // Make sure `join` works correctly
    assert_eq!(sw1.value(), 2000 * frost_per_wal());
    assert!(sw1.is_withdrawing());
    assert_eq!(
        pool.withdraw_stake(sw1, true, false, &wctx).destroy_for_testing(),
        2000 * frost_per_wal(),
    );

    destroy(pool);
}
