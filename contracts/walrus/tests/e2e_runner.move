// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::e2e_runner;

use sui::{clock::{Self, Clock}, test_scenario::{Self, Scenario}, test_utils};
use walrus::{
    init,
    node_metadata,
    staking::Staking,
    system::System,
    test_node::{Self, TestStorageNode},
    test_utils as walrus_test_utils,
    upgrade::UpgradeManager
};

const MAX_EPOCHS_AHEAD: u32 = 104;
const DEFAULT_EPOCH_ZERO_DURATION: u64 = 100000000;
const DEFAULT_EPOCH_DURATION: u64 = 7 * 24 * 60 * 60 * 1000 / 2;
const DEFAULT_N_SHARDS: u16 = 100;

// === Tests Runner ===

/// The test runner for end-to-end tests.
public struct TestRunner {
    scenario: Scenario,
    clock: Clock,
    admin: address,
}

/// Add any parameters to the initialization, such as epoch zero duration and number of shards.
/// They will be used by the e2e runner admin during the initialization.
public struct InitBuilder {
    epoch_zero_duration: Option<u64>,
    epoch_duration: Option<u64>,
    n_shards: Option<u16>,
    admin: address,
}

/// Prepare the test runner with the given admin address. Returns a builder to
/// set optional parameters: `epoch_zero_duration` and `n_shards`.
///
/// Example:
/// ```move
/// let admin = 0xA11CE;
/// let mut runner = e2e_runner::prepare(admin)
///    .epoch_zero_duration(100000000)
///    .n_shards(100)
///    .build();
///
/// runner.tx!(admin, |staking, system, ctx| { /* ... */ });
/// ```
public fun prepare(admin: address): InitBuilder {
    InitBuilder {
        epoch_zero_duration: option::none(),
        epoch_duration: option::none(),
        n_shards: option::none(),
        admin,
    }
}

/// Change the epoch zero duration.
public fun epoch_zero_duration(mut self: InitBuilder, duration: u64): InitBuilder {
    self.epoch_zero_duration = option::some(duration);
    self
}

/// Change the regular (non-zero) epoch duration.
public fun epoch_duration(mut self: InitBuilder, duration: u64): InitBuilder {
    self.epoch_duration = option::some(duration);
    self
}

/// Change the number of shards in the system.
public fun n_shards(mut self: InitBuilder, n: u16): InitBuilder {
    self.n_shards = option::some(n);
    self
}

/// Build the test runner with the given parameters.
public fun build(self: InitBuilder): TestRunner {
    let InitBuilder { admin, epoch_duration, epoch_zero_duration, n_shards } = self;
    let epoch_zero_duration = epoch_zero_duration.destroy_or!(DEFAULT_EPOCH_ZERO_DURATION);
    let epoch_duration = epoch_duration.destroy_or!(DEFAULT_EPOCH_DURATION);
    let n_shards = n_shards.destroy_or!(DEFAULT_N_SHARDS);

    let mut scenario = test_scenario::begin(admin);
    let clock = clock::create_for_testing(scenario.ctx());
    let ctx = scenario.ctx();

    init::init_for_testing(ctx);

    // We need an upgrade cap for package with address 0x0
    let upgrade_cap = sui::package::test_publish(ctx.fresh_object_address().to_id(), ctx);

    scenario.next_tx(admin);
    let cap = scenario.take_from_sender<init::InitCap>();
    let ctx = scenario.ctx();
    let emergency_upgrade_cap = init::initialize_for_testing(
        cap,
        upgrade_cap,
        epoch_zero_duration,
        epoch_duration,
        n_shards,
        MAX_EPOCHS_AHEAD,
        &clock,
        ctx,
    );

    transfer::public_transfer(emergency_upgrade_cap, admin);
    scenario.next_tx(admin);

    TestRunner { scenario, clock, admin }
}

/// Get the admin address that published Walrus System and Staking.
public fun admin(self: &TestRunner): address { self.admin }

/// Access runner's `Scenario`.
public fun scenario(self: &mut TestRunner): &mut Scenario { &mut self.scenario }

/// Access runner's `Clock`.
public fun clock(self: &mut TestRunner): &mut Clock { &mut self.clock }

/// Access the current epoch of the system.
public fun epoch(self: &mut TestRunner): u32 {
    self.scenario.next_tx(self.admin);
    let system = self.scenario.take_shared<System>();
    let epoch = system.epoch();
    test_scenario::return_shared(system);
    epoch
}

/// Returns the default epoch duration.
public fun default_epoch_duration(): u64 { DEFAULT_EPOCH_DURATION }

/// Run a transaction as a `sender`, and call the function `f` with the `Staking`,
/// `System`, and `TxContext` as arguments.
public macro fun tx(
    $runner: &mut TestRunner,
    $sender: address,
    $f: |&mut Staking, &mut System, &mut TxContext|,
) {
    let runner = $runner;
    let scenario = runner.scenario();
    scenario.next_tx($sender);
    let mut staking = scenario.take_shared<Staking>();
    let mut system = scenario.take_shared<System>();
    let ctx = scenario.ctx();

    $f(&mut staking, &mut system, ctx);

    test_scenario::return_shared(staking);
    test_scenario::return_shared(system);
}

/// Returns TransactionEffects of the last transaction.
public fun last_tx_effects(runner: &mut TestRunner): test_scenario::TransactionEffects {
    runner.scenario().next_tx(@1)
}

/// Run a transaction as a `sender`, and call the function `f` with the `Staking`,
/// `System`, `UpgradeManager`, and `TxContext` as arguments.
public macro fun tx_with_upgrade_manager(
    $runner: &mut TestRunner,
    $sender: address,
    $f: |&mut Staking, &mut System, &mut UpgradeManager, &mut TxContext|,
) {
    let runner = $runner;
    let scenario = runner.scenario();
    scenario.next_tx($sender);
    let mut staking = scenario.take_shared<Staking>();
    let mut system = scenario.take_shared<System>();
    let mut upgrade_manager = scenario.take_shared<UpgradeManager>();
    let ctx = scenario.ctx();

    $f(&mut staking, &mut system, &mut upgrade_manager, ctx);

    test_scenario::return_shared(upgrade_manager);
    test_scenario::return_shared(staking);
    test_scenario::return_shared(system);
}

/// Destroy the test runner and all resources.
public fun destroy(self: TestRunner) {
    test_utils::destroy(self)
}

#[allow(lint(self_transfer), unused_mut_ref)]
public fun setup_committee_for_epoch_one(): (TestRunner, vector<TestStorageNode>) {
    let admin = @0xA11CE;
    let mut nodes = test_node::test_nodes();
    let mut runner = prepare(admin).build();
    let commission_rate: u16 = 0;
    let storage_price: u64 = 5;
    let write_price: u64 = 1;
    let node_capacity: u64 = 1_000_000_000;

    // === register candidates ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let cap = staking.register_candidate(
                node.name(),
                node.network_address(),
                node_metadata::default(),
                node.bls_pk(),
                node.network_key(),
                node.create_proof_of_possession(epoch),
                commission_rate,
                storage_price,
                write_price,
                node_capacity,
                ctx,
            );
            node.set_storage_node_cap(cap);
        });
    });

    // === stake with each node ===

    nodes.do_ref!(|node| {
        runner.tx!(node.sui_address(), |staking, _, ctx| {
            let coin = walrus_test_utils::mint_wal(1000, ctx);
            let staked_wal = staking.stake_with_pool(coin, node.node_id(), ctx);
            transfer::public_transfer(staked_wal, ctx.sender());
        });
    });

    // === advance clock and end voting ===
    // === check if epoch state is changed correctly ==

    runner.clock().increment_for_testing(DEFAULT_EPOCH_ZERO_DURATION);
    runner.tx!(admin, |staking, system, _| {
        staking.voting_end(runner.clock());
        staking.initiate_epoch_change(system, runner.clock());
        nodes.do_ref!(|node| assert!(system.committee().contains(&node.node_id())));
    });

    // === send epoch sync done messages from all nodes ===
    let epoch = runner.epoch();
    nodes.do_mut!(|node| {
        runner.tx!(node.sui_address(), |staking, _, _| {
            staking.epoch_sync_done(node.cap_mut(), epoch, runner.clock());
        });
    });

    (runner, nodes)
}
