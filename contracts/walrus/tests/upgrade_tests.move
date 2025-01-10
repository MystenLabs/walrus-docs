// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// SPDX-License-Identifier: Apache-2.0

#[allow(unused_mut_ref)]
module walrus::upgrade_tests;

use std::unit_test::assert_eq;
use sui::{package, test_scenario};
use walrus::{auth, e2e_runner, upgrade};

#[test]
public fun test_emergency_upgrade() {
    use walrus::upgrade::EmergencyUpgradeCap;

    let admin = @0xA11CE;
    let mut runner = e2e_runner::prepare(admin).build();

    let emergency_cap: EmergencyUpgradeCap = runner.scenario().take_from_address(admin);
    runner.tx_with_upgrade_manager!(admin, |staking, system, upgrade_manager, _| {
        // Check that the new package id is not set before the upgrade
        assert!(system.new_package_id().is_none() && staking.new_package_id().is_none());

        let upgrade_ticket = upgrade_manager.authorize_emergency_upgrade(
            &emergency_cap,
            vector<u8>[],
        );
        let receipt = package::test_upgrade(upgrade_ticket);
        upgrade_manager.commit_upgrade(staking, system, receipt);

        // Check that the new package id is set after the upgrade and is the same for both the
        // system and staking objects.
        assert!(system.new_package_id().is_some());
        assert_eq!(system.new_package_id(), staking.new_package_id());
    });
    test_scenario::return_to_address(admin, emergency_cap);
    runner.destroy();
}

#[test]
public fun test_quorum_upgrade() {
    let (mut runner, nodes) = e2e_runner::setup_committee_for_epoch_one();

    // === vote for upgrade ===
    // minimum number of votes needed since stake is equally distributed
    let n_votes = nodes.length() * 2 / 3 + 1;
    let digest = upgrade::digest_for_testing(runner.scenario().ctx());
    n_votes.do!(|idx| {
        let node = &nodes[idx];
        runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
            let auth = auth::authenticate_sender(ctx);
            upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest)
        });
    });

    // === commit upgrade ===

    runner.tx_with_upgrade_manager!(nodes[0].sui_address(), |staking, system, upgrade_manager, _| {
        // Check that the new package id is not set before the upgrade
        assert!(system.new_package_id().is_none() && staking.new_package_id().is_none());

        let upgrade_ticket = upgrade_manager.authorize_upgrade(staking, digest);
        let receipt = package::test_upgrade(upgrade_ticket);
        upgrade_manager.commit_upgrade(staking, system, receipt);

        // Check that the new package id is set after the upgrade and is the same for both the
        // system and staking objects.
        assert!(system.new_package_id().is_some());
        assert_eq!(system.new_package_id(), staking.new_package_id());
    });

    // === cleanup ===

    runner.destroy();
    nodes.destroy!(|node| node.destroy());
}

#[test, expected_failure(abort_code = upgrade::ENotEnoughVotes)]
public fun test_upgrade_insufficient_votes() {
    let (mut runner, nodes) = e2e_runner::setup_committee_for_epoch_one();

    // === vote for upgrade ===
    // just shy of a quorum since stake is equally distributed
    let n_votes = nodes.length() * 2 / 3;

    let digest = upgrade::digest_for_testing(runner.scenario().ctx());
    n_votes.do!(|idx| {
        let node = &nodes[idx];
        runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
            let auth = auth::authenticate_sender(ctx);
            upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest)
        });
    });

    // === try to commit upgrade ===

    runner.tx_with_upgrade_manager!(nodes[0].sui_address(), |staking, _, upgrade_manager, _| {
        // Test should fail here.
        let _upgrade_ticket = upgrade_manager.authorize_upgrade(staking, digest);
    });

    // Unreachable
    abort
}

#[test, expected_failure(abort_code = upgrade::EWrongEpoch)]
public fun test_upgrade_wrong_epoch() {
    let (mut runner, nodes) = e2e_runner::setup_committee_for_epoch_one();

    // === vote for upgrade ===

    let digest = upgrade::digest_for_testing(runner.scenario().ctx());
    nodes.do_ref!(|node| {
        runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
            let auth = auth::authenticate_sender(ctx);
            upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest)
        });
    });

    // === advance clock and change epoch ===

    runner.clock().increment_for_testing(e2e_runner::default_epoch_duration());
    runner.tx!(nodes[0].sui_address(), |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());
        assert_eq!(system.epoch(), 2);
    });

    // === try to commit upgrade with the package voted for in the previous epoch ===

    runner.tx_with_upgrade_manager!(nodes[0].sui_address(), |staking, _, upgrade_manager, _| {
        // Test should fail here.
        let _upgrade_ticket = upgrade_manager.authorize_upgrade(staking, digest);
    });

    // Unreachable
    abort
}

#[test, expected_failure(abort_code = upgrade::EWrongVersion)]
public fun test_upgrade_wrong_version() {
    let (mut runner, nodes) = e2e_runner::setup_committee_for_epoch_one();

    // === vote for upgrade 1 ===

    let digest_1 = upgrade::digest_for_testing(runner.scenario().ctx());
    nodes.do_ref!(|node| {
        runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
            let auth = auth::authenticate_sender(ctx);
            upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest_1)
        });
    });

    // === vote for upgrade 2 ===

    let digest_2 = upgrade::digest_for_testing(runner.scenario().ctx());
    nodes.do_ref!(|node| {
        runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
            let auth = auth::authenticate_sender(ctx);
            upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest_2)
        });
    });
    // === upgrade to digest 1 ===

    runner.tx_with_upgrade_manager!(nodes[0].sui_address(), |staking, system, upgrade_manager, _| {
        let upgrade_ticket = upgrade_manager.authorize_upgrade(staking, digest_1);
        let receipt = package::test_upgrade(upgrade_ticket);
        upgrade_manager.commit_upgrade(staking, system, receipt);
    });

    // === try to upgrade to digest 2 ===

    runner.tx_with_upgrade_manager!(nodes[0].sui_address(), |staking, _, upgrade_manager, _| {
        // Test should fail here.
        let _upgrade_ticket = upgrade_manager.authorize_upgrade(staking, digest_2);
    });

    // Unreachable
    abort
}

#[test, expected_failure(abort_code = upgrade::EDuplicateVote)]
public fun test_upgrade_duplicate_vote() {
    let (mut runner, nodes) = e2e_runner::setup_committee_for_epoch_one();

    // === vote for upgrade 1 ===

    let digest = upgrade::digest_for_testing(runner.scenario().ctx());
    let node = &nodes[0];
    runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
        let auth = auth::authenticate_sender(ctx);
        upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest)
    });

    // === vote for upgrade 2 ===

    runner.tx_with_upgrade_manager!(node.sui_address(), |staking, _, upgrade_manager, ctx| {
        let auth = auth::authenticate_sender(ctx);
        // Test should fail here
        upgrade_manager.vote_for_upgrade(staking, auth, node.node_id(), digest)
    });

    // Unreachable
    abort
}
