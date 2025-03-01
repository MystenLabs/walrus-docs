// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::system_state_inner_tests;

use std::unit_test::assert_eq;
use walrus::{storage_accounting as sa, system_state_inner, test_utils::mint_frost};

#[test]
fun test_add_subsidy_zero_rewards() {
    add_subsidy_test(0, 2);
}

#[test]
fun test_add_subsidy_one_epoch_ahead() {
    add_subsidy_test(1000, 1);
}

#[test]
fun test_add_subsidy_multiple_epochs_ahead() {
    add_subsidy_test(1000, 4);
}

#[test]
fun test_add_subsidy_uneven_distribution() {
    let ctx = &mut tx_context::dummy();
    let mut system = system_state_inner::new_for_testing();
    let rewards = 1001u64;
    let epochs_ahead = 3;
    let reward_per_epoch = rewards / (epochs_ahead as u64);

    // Test adding rewards 1,001 WAL for 3 epochs ahead.
    let subsidy = mint_frost(rewards, ctx);
    system.add_subsidy(subsidy, epochs_ahead);

    // Check rewards for the epochs ahead
    // The first epoch should get 2 more rewards than the others. They are the leftover_rewards.
    let first_epoch_rewards = reward_per_epoch + 2;

    let rb0 = sa::rewards_balance(sa::ring_lookup_mut(system.future_accounting_mut(), 0));
    assert!(rb0.value() == first_epoch_rewards);
    let rb1 = sa::rewards_balance(sa::ring_lookup_mut(system.future_accounting_mut(), 1));
    assert!(rb1.value() == reward_per_epoch);
    let rb2 = sa::rewards_balance(sa::ring_lookup_mut(system.future_accounting_mut(), 2));
    assert!(rb2.value() == reward_per_epoch);
    system.destroy_for_testing()
}

#[test, expected_failure(abort_code = system_state_inner::EInvalidEpochsAhead)]
fun test_add_subsidy_zero_epochs_ahead_fail() {
    let ctx = &mut tx_context::dummy();
    let mut system = system_state_inner::new_for_testing();

    let subsidy = mint_frost(1000, ctx);

    // Test adding rewards for 0 epochs ahead (should fail)
    system.add_subsidy(subsidy, 0);

    abort
}

fun add_subsidy_test(rewards: u64, epochs_ahead: u32) {
    let ctx = &mut tx_context::dummy();
    let mut system = system_state_inner::new_for_testing();
    let base_reward = rewards / (epochs_ahead as u64);
    let leftovers = rewards % (epochs_ahead as u64);

    // Mint the subsidy and add it to the system.
    let subsidy = mint_frost(rewards, ctx);
    system.add_subsidy(subsidy, epochs_ahead);

    // Distribute the rewards across epochs.
    epochs_ahead.do!(|i| {
        let expected_reward = base_reward + if ((i as u64) < leftovers) { 1 } else { 0 };
        let rb = sa::rewards_balance(sa::ring_lookup_mut(system.future_accounting_mut(), i));
        assert_eq!(rb.value(), expected_reward);
    });

    system.destroy_for_testing()
}
