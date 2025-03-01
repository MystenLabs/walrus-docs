// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_mut_ref)]
module walrus::e2e_tests;

use std::unit_test::assert_eq;
use walrus::{auth, e2e_runner, staking_pool, test_node::{Self, TestStorageNode}, test_utils};

const COMMISSION_RATE: u16 = 0;
const STORAGE_PRICE: u64 = 5;
const WRITE_PRICE: u64 = 1;
const NODE_CAPACITY: u64 = 1_000_000_000;
const N_SHARDS: u16 = 100;

/// Taken from `walrus::staking`. Must be the same values as there.
const EPOCH_DURATION: u64 = 7 * 24 * 60 * 60 * 1000;
const PARAM_SELECTION_DELTA: u64 = 7 * 24 * 60 * 60 * 1000 / 2;
const EPOCH_ZERO_DURATION: u64 = 100000000;

#[test]
fun test_init_and_first_epoch_change() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidates ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                COMMISSION_RATE,
                STORAGE_PRICE,
                WRITE_PRICE,
                NODE_CAPACITY,
                ctx,
            );
            node.set_storage_node_cap(cap);
        });
    });

    // === stake with each node ===

    nodes.do_ref!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let coin = test_utils::mint_wal(1000, ctx);
            let staked_wal = staking.stake_with_pool(coin, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === advance clock and end voting ===
    // === check if epoch state is changed correctly ==

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 1);
        assert!(system.committee().n_shards() == N_SHARDS);

        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    // === send epoch sync done messages from all nodes ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === perform another epoch change ===
    // === check if epoch state is changed correctly ==

    runner.clock().increment_for_testing(PARAM_SELECTION_DELTA);
    runner.tx!(admin, |staking, _, _| {
        assert!(staking.is_epoch_sync_done());
        staking.voting_end(runner.clock());
    });

    // === advance clock and change epoch ===
    // === check if epoch was changed as expected ===

    runner.clock().increment_for_testing(EPOCH_DURATION - PARAM_SELECTION_DELTA);
    runner.tx!(admin, |staking, system, _| {
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 2);
        assert!(system.committee().n_shards() == N_SHARDS);

        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    // === send epoch sync done messages from all nodes ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === check if epoch state is changed correctly ==

    runner.tx!(admin, |staking, _, _| assert!(staking.is_epoch_sync_done()));

    // === cleanup ===

    nodes.destroy!(|node| node.destroy());
    runner.destroy();
}

#[test]
fun test_stake_after_committee_selection() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidates ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                COMMISSION_RATE,
                STORAGE_PRICE,
                WRITE_PRICE,
                NODE_CAPACITY,
                ctx,
            );
            node.set_storage_node_cap(cap);
        });
    });

    // === stake with each node except one ===

    let excluded_node = nodes.pop_back();

    nodes.do_ref!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let coin = test_utils::mint_wal(1000, ctx);
            let staked_wal = staking.stake_with_pool(coin, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === advance clock and end voting ===

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, _, _| {
        staking.voting_end(runner.clock());
    });

    // === add stake to excluded node ===

    runner.tx!(excluded_node.sui_address(), |staking, _, ctx| {
        let coin = test_utils::mint_wal(1000, ctx);
        let staked_wal = staking.stake_with_pool(coin, excluded_node.node_id(), ctx);
        transfer::public_transfer(staked_wal, ctx.sender());
    });

    // === initiate epoch change ===
    // === check if epoch state is changed correctly ==

    runner.tx!(admin, |staking, system, _| {
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 1);
        assert!(system.committee().n_shards() == N_SHARDS);

        // all nodes initially staked with are in the committee
        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
        // excluded node is not in the committee
        assert!(!system.committee().contains(&excluded_node.node_id()));
    });

    // === send epoch sync done messages from all nodes in the committee ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === advance clock and change epoch ===
    // === check if previously excluded node is now also in the committee ===

    runner.clock().increment_for_testing(EPOCH_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 2);
        assert!(system.committee().n_shards() == N_SHARDS);

        // all nodes initially staked with are in the committee
        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
        // previously excluded node is now also in the committee
        assert!(system.committee().contains(&excluded_node.node_id()));
    });

    // === cleanup ===

    nodes.destroy!(|node| node.destroy());
    excluded_node.destroy();
    runner.destroy();
}

#[test]
fun node_voting_parameters() {
    let mut nodes = test_node::test_nodes();
    let admin = @0xA11CE;
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // 10 storage nodes, we'll set storage price, write_capacity and node_capacity
    // to 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 and equal stake.
    let mut i = 1;
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                COMMISSION_RATE,
                i * 1000,
                i * 1000,
                i * 1000,
                ctx,
            );
            node.set_storage_node_cap(cap);

            i = i + 1;

            // stake in the same tx
            let staked_wal = staking.stake_with_pool(
                test_utils::mint_wal(1000, ctx),
                node.node_id(),
                ctx,
            );
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 1);
        assert!(system.committee().n_shards() == N_SHARDS);

        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    runner.tx!(admin, |staking, _, _| {
        let inner = staking.inner_for_testing();
        let params = inner.next_epoch_params();

        // values are: 1000, 2000, 3000, 4000, 5000, 6000, 7000 (picked), 8000, 9000, 10000
        assert_eq!(params.storage_price(), 7000);
        assert_eq!(params.write_price(), 7000);

        // node capacities are: 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000
        // votes:  10000, 20000, 30000, 40000 (picked), 50000, 60000, 70000, 80000, 90000, 100000
        assert_eq!(params.capacity(), 40000);
    });

    nodes.destroy!(|node| node.destroy());
    runner.destroy();
}

#[test, expected_failure(abort_code = walrus::staking_inner::EWrongEpochState)]
fun test_first_epoch_too_soon_fail() {
    let mut nodes = test_node::test_nodes();
    let admin = @0xA11CE;
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register nodes as storage node + stake for each ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let stake = test_utils::mint_wal(1000, ctx);
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                COMMISSION_RATE,
                STORAGE_PRICE,
                WRITE_PRICE,
                NODE_CAPACITY,
                ctx,
            );
            node.set_storage_node_cap(cap);

            let staked_wal = staking.stake_with_pool(stake, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === advance clock, end voting and initialize epoch change ===

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION - 1);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());
    });

    abort 0
}

#[test]
fun test_epoch_change_with_rewards_and_commission() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidates ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                100_00, // 100.00% commission
                STORAGE_PRICE,
                WRITE_PRICE,
                NODE_CAPACITY,
                ctx,
            );
            node.set_storage_node_cap(cap);
        });
    });

    // === stake with each node ===

    nodes.do_ref!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let coin = test_utils::mint_wal(1, ctx);
            let staked_wal = staking.stake_with_pool(coin, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === advance clock, end voting, and change epoch ===
    // === check if epoch state is changed correctly ==

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());

        assert!(system.epoch() == 1);
        assert!(system.committee().n_shards() == N_SHARDS);

        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    // === send epoch sync done messages from all nodes ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === buy some storage to add rewards ===

    runner.tx!(admin, |_, system, ctx| {
        let mut coin = test_utils::mint_wal(1_000, ctx);
        let storage = system.reserve_space(1_000_000_000, 10, &mut coin, ctx);
        transfer::public_transfer(storage, ctx.sender());
        transfer::public_transfer(coin, ctx.sender());
    });

    // === register deny list update with each node (for tests) ===

    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |_, system, _| {
            system.register_deny_list_update(node.cap_mut(), @1.to_u256(), 1);
        });

        // make sure that the event was emitted
        assert_eq!(runner.last_tx_effects().num_user_events(), 1);
    });

    // === register once more, now with incremented sequence number ===

    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |_, system, _| {
            system.register_deny_list_update(node.cap_mut(), @2.to_u256(), 2);
        });

        // make sure that the event was emitted
        assert_eq!(runner.last_tx_effects().num_user_events(), 1);
    });

    // === sign a message for the first node to update deny list size ===

    let node = &nodes[0];
    let deny_list_node = nodes[0].node_id();
    let certified_message = node.update_deny_list_message(runner.epoch(), 2u256, 10_000_000, 1);
    let (signature, members_bitmap) = nodes.sign(certified_message);

    // === send the message from the first node
    let node = &mut nodes[0];
    runner.tx!(node.sui_address(), |_, system, _| {
        system.update_deny_list(node.cap_mut(), signature, members_bitmap, certified_message);

        // check the VecMap with sizes
        let deny_list_sizes = system.inner().deny_list_sizes();

        assert_eq!(deny_list_sizes.size(), 1);
        assert!(deny_list_sizes.contains(&node.node_id()));
        assert_eq!(*deny_list_sizes.get(&node.node_id()), 10_000_000);
    });

    assert_eq!(runner.last_tx_effects().num_user_events(), 1); // update deny list event emitted
    assert_eq!(node.cap().deny_list_root(), 2u256); // deny list root updated
    assert_eq!(node.cap().deny_list_sequence(), 1); // sequence number incremented

    // === perform another epoch change ===
    // === check if epoch state is changed correctly ==

    runner.clock().increment_for_testing(PARAM_SELECTION_DELTA);
    runner.tx!(admin, |staking, _, _| {
        assert!(staking.is_epoch_sync_done());
        staking.voting_end(runner.clock());
    });

    // === advance clock and change epoch ===
    // === check if epoch was changed as expected ===

    runner.clock().increment_for_testing(EPOCH_DURATION - PARAM_SELECTION_DELTA);
    runner.tx!(admin, |staking, system, _| {
        staking.initiate_epoch_change(system, runner.clock());

        assert_eq!(system.epoch(), 2);
        assert_eq!(system.committee().n_shards(), N_SHARDS);

        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    // === send epoch sync done messages from all nodes ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === check if epoch state is changed correctly ==

    runner.tx!(admin, |staking, _, _| assert!(staking.is_epoch_sync_done()));

    // === check rewards for each node ===

    // each node is getting 470 in rewards, 10% of that is - 47 - commission
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let auth = auth::authenticate_with_object(node.cap());
            let commission = staking.collect_commission(node.node_id(), auth, ctx);

            // deny_list_node has 10% less rewards
            // all nodes claim 100% of their rewards
            if (node.node_id() == deny_list_node) {
                assert_eq!(commission.burn_for_testing(), 472);
            } else {
                assert_eq!(commission.burn_for_testing(), 477);
            };
        });
    });

    // === cleanup ===

    nodes.destroy!(|node| node.destroy());
    runner.destroy();
}

#[test]
fun node_update_metadata() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    let epoch = runner.epoch();
    let node = &mut nodes[0];

    runner.tx!(node.sui_address(), |staking, _, ctx| {
        let cap = staking.register_candidate(
            node.name(),
            node.network_address(),
            node.metadata(),
            node.bls_pk(),
            node.network_key(),
            node.create_proof_of_possession(epoch),
            COMMISSION_RATE,
            STORAGE_PRICE,
            WRITE_PRICE,
            NODE_CAPACITY,
            ctx,
        );
        node.set_storage_node_cap(cap);
    });

    runner.tx!(node.sui_address(), |staking, _, _| {
        let mut metadata = staking.node_metadata(node.node_id());
        metadata.set_description(b"Tusk Crew".to_string());
        metadata.set_project_url(b"https://crew.walrus.site/".to_string());
        staking.set_node_metadata(node.cap(), metadata);
    });

    runner.tx!(node.sui_address(), |staking, _, _| {
        let metadata = staking.node_metadata(node.node_id());
        assert_eq!(metadata.description(), b"Tusk Crew".to_string());
        assert_eq!(metadata.project_url(), b"https://crew.walrus.site/".to_string());
    });

    nodes.destroy!(|node| node.destroy());
    runner.destroy();
}

#[test, expected_failure(abort_code = staking_pool::EInvalidProofOfPossession)]
fun test_register_invalid_pop_epoch() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidate with proof of possession for wrong epoch ===
    let epoch = runner.epoch() + 1;
    let node = &mut nodes[0];
    // Test fails here
    runner.tx!(node.sui_address(), |staking, _, ctx| {
        let cap = staking.register_candidate(
            node.name(),
            node.network_address(),
            node.metadata(),
            node.bls_pk(),
            node.network_key(),
            node.create_proof_of_possession(epoch),
            COMMISSION_RATE,
            STORAGE_PRICE,
            WRITE_PRICE,
            NODE_CAPACITY,
            ctx,
        );
        node.set_storage_node_cap(cap);
    });

    abort 0
}

#[test, expected_failure(abort_code = staking_pool::EInvalidProofOfPossession)]
fun test_register_invalid_pop_signer() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidate with proof of possession for wrong epoch ===
    let epoch = runner.epoch() + 1;
    // wrong signer
    let pop = nodes[1].create_proof_of_possession(epoch);
    let node = &mut nodes[0];
    // Test fails here
    runner.tx!(node.sui_address(), |staking, _, ctx| {
        let cap = staking.register_candidate(
            node.name(),
            node.network_address(),
            node.metadata(),
            node.bls_pk(),
            node.network_key(),
            pop,
            COMMISSION_RATE,
            STORAGE_PRICE,
            WRITE_PRICE,
            NODE_CAPACITY,
            ctx,
        );
        node.set_storage_node_cap(cap);
    });

    abort 0
}

#[test]
fun withdraw_rewards_before_joining_committee() {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = e2e_runner::prepare(admin)
        .epoch_zero_duration(EPOCH_ZERO_DURATION)
        .epoch_duration(EPOCH_DURATION)
        .n_shards(N_SHARDS)
        .build();

    // === register candidates ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node.metadata(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                COMMISSION_RATE,
                STORAGE_PRICE,
                WRITE_PRICE,
                NODE_CAPACITY,
                ctx,
            );
            node.set_storage_node_cap(cap);
        });
    });

    // === stake with each node except one ===

    let excluded_node = nodes.pop_back();

    nodes.do_ref!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let coin = test_utils::mint_wal(1000, ctx);
            let staked_wal = staking.stake_with_pool(coin, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === initiate epoch change ===

    runner.clock().increment_for_testing(EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());
    });

    // === send epoch sync done messages from all nodes in the committee ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === add small amount of stake to excluded node ===

    runner.tx!(excluded_node.sui_address(), |staking, _, ctx| {
        let coin = test_utils::mint_wal(1, ctx);
        let staked_wal = staking.stake_with_pool(coin, excluded_node.node_id(), ctx);
        transfer::public_transfer(staked_wal, ctx.sender());
    });

    // === initiate epoch change ===

    runner.clock().increment_for_testing(EPOCH_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());
    });

    // === send epoch sync done messages from all nodes in the committee ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    // === withdraw stake from excluded node ===

    let staked_wal = runner.scenario().take_from_address(excluded_node.sui_address());
    runner.tx!(excluded_node.sui_address(), |staking, _, ctx| {
        let coin = staking.withdraw_stake(staked_wal, ctx);
        coin.burn_for_testing();
    });

    // === add stake to excluded node again ===

    runner.tx!(excluded_node.sui_address(), |staking, _, ctx| {
        let coin = test_utils::mint_wal(1000, ctx);
        let staked_wal = staking.stake_with_pool(coin, excluded_node.node_id(), ctx);
        transfer::public_transfer(staked_wal, ctx.sender());
    });

    // === advance clock and change epoch ===
    // === check if previously excluded node is now also in the committee ===

    runner.clock().increment_for_testing(EPOCH_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());

        // previously excluded node is now also in the committee
        assert!(system.committee().contains(&excluded_node.node_id()));
    });

    // === cleanup ===

    nodes.destroy!(|node| node.destroy());
    excluded_node.destroy();
    runner.destroy();
}

// local alias for simplicity
use fun sign as vector.sign;

fun sign(nodes: &vector<TestStorageNode>, message: vector<u8>): (vector<u8>, vector<u8>) {
    let signatures = nodes.map_ref!(|node| node.sign_message(message));
    let members_bitmap = test_utils::signers_to_bitmap(
        &vector::tabulate!(nodes.length(), |i| i as u16),
    );
    let signature = test_utils::bls_aggregate_sigs(&signatures);

    (signature, members_bitmap)
}
