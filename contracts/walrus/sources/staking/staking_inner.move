// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::staking_inner;

use std::string::String;
use sui::{
    balance::{Self, Balance},
    bls12381::UncompressedG1,
    clock::Clock,
    coin::Coin,
    group_ops::Element,
    object_table::{Self, ObjectTable},
    priority_queue::{Self, PriorityQueue},
    vec_map::{Self, VecMap}
};
use wal::wal::WAL;
use walrus::{
    active_set::{Self, ActiveSet},
    auth::{Authenticated, Authorized},
    bls_aggregate::{Self, BlsCommittee},
    committee::{Self, Committee},
    epoch_parameters::{Self, EpochParams},
    events,
    extended_field::{Self, ExtendedField},
    node_metadata::NodeMetadata,
    staked_wal::StakedWal,
    staking_pool::{Self, StakingPool},
    storage_node::StorageNodeCap,
    walrus_context::{Self, WalrusContext}
};

/// The minimum amount of staked WAL required to be included in the active set.
const MIN_STAKE: u64 = 0;

/// Temporary upper limit for the number of storage nodes.
/// TODO: Remove once solutions are in place to prevent hitting move execution limits (#935).
const TEMP_ACTIVE_SET_SIZE_LIMIT: u16 = 111;

/// The number of nodes from which a flat shards limit is applied.
const MIN_NODES_FOR_SHARDS_LIMIT: u8 = 20;

/// The maximum number of shards per node as a denominator of the total number of shards.
/// When the number of nodes is smaller than MIN_NODES_FOR_SHARDS_LIMIT, the shards limit
/// is multiplied by MIN_NODES_FOR_SHARDS_LIMIT / number of nodes.
const SHARDS_LIMIT_DENOMINATOR: u8 = 10; // 10%

// The delta between the epoch change finishing and selecting the next epoch parameters in ms.
// Currently half of an epoch.
// TODO: currently replaced by the epoch duration / 2. Consider making this a separate system
// parameter.
// const PARAM_SELECTION_DELTA: u64 = 7 * 24 * 60 * 60 * 1000 / 2;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The system is in the wrong epoch state for the operation.
const EWrongEpochState: u64 = 0;
/// Trying to signal that the sync is done for the wrong Epoch.
const EInvalidSyncEpoch: u64 = 1;
/// The node already signaled that the sync is done for the current Epoch.
const EDuplicateSyncDone: u64 = 2;
/// There is no stake in the system, no apportionment can be performed.
const ENoStake: u64 = 3;
/// The node is not in the committee.
const ENotInCommittee: u64 = 4;
/// The committee for the next epoch has already been selected.
const ECommitteeSelected: u64 = 5;
/// The committee for the next epoch has not been set yet.
const ENextCommitteeIsEmpty: u64 = 6;
/// The number of shards assigned to a node is invalid.
const EInvalidNodeWeight: u64 = 7;
/// The staking pool with the provided ID was not found.
const EPoolNotFound: u64 = 8;
/// A node in the committee has no shards assigned.
const EZeroNodeWeight: u64 = 9;
/// The list of nodes is not sorted.
const EIncorrectNodeOrder: u64 = 10;

/// The epoch state.
public enum EpochState has copy, drop, store {
    // Epoch change is currently in progress. Contains the weight of the nodes that
    // have already attested that they finished the sync.
    EpochChangeSync(u16),
    // Epoch change has been completed at the contained timestamp.
    EpochChangeDone(u64),
    // The parameters for the next epoch have been selected.
    // The contained timestamp is the start of the current epoch.
    NextParamsSelected(u64),
}

/// The inner object for the staking part of the system.
public struct StakingInnerV1 has store {
    /// The number of shards in the system.
    n_shards: u16,
    /// The duration of an epoch in ms. Does not affect the first (zero) epoch.
    epoch_duration: u64,
    /// Special parameter, used only for the first epoch. The timestamp when the
    /// first epoch can be started.
    first_epoch_start: u64,
    /// Stored staking pools, each identified by a unique `ID` and contains
    /// the `StakingPool` object. Uses `ObjectTable` to make the pool discovery
    /// easier by avoiding wrapping.
    ///
    /// The key is the ID of the staking pool.
    pools: ObjectTable<ID, StakingPool>,
    /// The current epoch of the Walrus system. The epochs are not the same as
    /// the Sui epochs, not to be mistaken with `ctx.epoch()`.
    epoch: u32,
    /// Stores the active set of storage nodes. Tracks the total amount of staked WAL.
    active_set: ExtendedField<ActiveSet>,
    /// The next committee in the system.
    next_committee: Option<Committee>,
    /// The current committee in the system.
    committee: Committee,
    /// The previous committee in the system.
    previous_committee: Committee,
    /// The next epoch parameters.
    next_epoch_params: Option<EpochParams>,
    /// The state of the current epoch.
    epoch_state: EpochState,
    /// The public keys for the next epoch. The keys are stored in a sorted `VecMap`, and mirror
    /// the order of the nodes in the `next_committee`. The value is set in the `select_committee`
    /// function and consumed in the `next_bls_committee` function.
    next_epoch_public_keys: ExtendedField<VecMap<ID, Element<UncompressedG1>>>,
}

/// Creates a new `StakingInnerV1` object with default values.
public(package) fun new(
    epoch_zero_duration: u64,
    epoch_duration: u64,
    n_shards: u16,
    clock: &Clock,
    ctx: &mut TxContext,
): StakingInnerV1 {
    StakingInnerV1 {
        n_shards,
        epoch_duration,
        first_epoch_start: epoch_zero_duration + clock.timestamp_ms(),
        pools: object_table::new(ctx),
        epoch: 0,
        active_set: extended_field::new(
            active_set::new(TEMP_ACTIVE_SET_SIZE_LIMIT, MIN_STAKE),
            ctx,
        ),
        next_committee: option::none(),
        committee: committee::empty(),
        previous_committee: committee::empty(),
        next_epoch_params: option::none(),
        epoch_state: EpochState::EpochChangeDone(clock.timestamp_ms()),
        next_epoch_public_keys: extended_field::new(vec_map::empty(), ctx),
    }
}

// === Staking Pool / Storage Node ===

/// Creates a new staking pool with the given `commission_rate`.
public(package) fun create_pool(
    self: &mut StakingInnerV1,
    name: String,
    network_address: String,
    metadata: NodeMetadata,
    public_key: vector<u8>,
    network_public_key: vector<u8>,
    proof_of_possession: vector<u8>,
    commission_rate: u16,
    storage_price: u64,
    write_price: u64,
    node_capacity: u64,
    ctx: &mut TxContext,
): ID {
    let pool = staking_pool::new(
        name,
        network_address,
        metadata,
        public_key,
        network_public_key,
        proof_of_possession,
        commission_rate,
        storage_price,
        write_price,
        node_capacity,
        &self.new_walrus_context(),
        ctx,
    );

    let node_id = object::id(&pool);
    self.pools.add(node_id, pool);
    node_id
}

/// Sets the commission receiver for the pool.
public(package) fun set_commission_receiver(
    self: &mut StakingInnerV1,
    node_id: ID,
    auth: Authenticated,
    receiver: Authorized,
) {
    self.pools[node_id].set_commission_receiver(auth, receiver)
}

/// Collect commission for the pool using the `StorageNodeCap`.
public(package) fun collect_commission(
    self: &mut StakingInnerV1,
    node_id: ID,
    auth: Authenticated,
): Balance<WAL> {
    self.pools[node_id].collect_commission(auth)
}

public(package) fun voting_end(self: &mut StakingInnerV1, clock: &Clock) {
    // Check if it's time to end the voting.
    let last_epoch_change = match (self.epoch_state) {
        EpochState::EpochChangeDone(last_epoch_change) => last_epoch_change,
        _ => abort EWrongEpochState,
    };

    let now = clock.timestamp_ms();
    let param_selection_delta = self.epoch_duration / 2;

    // We don't need a delay for the epoch zero.
    if (self.epoch != 0) {
        assert!(now >= last_epoch_change + param_selection_delta, EWrongEpochState);
    } else {
        assert!(now >= self.first_epoch_start, EWrongEpochState);
    };

    // Assign the next epoch committee.
    self.select_committee_and_calculate_votes();

    // Set the new epoch state.
    self.epoch_state = EpochState::NextParamsSelected(last_epoch_change);

    // Emit event that parameters have been selected.
    events::emit_epoch_parameters_selected(self.epoch + 1);
}

/// Selects the committee for the next epoch.
public(package) fun select_committee_and_calculate_votes(self: &mut StakingInnerV1) {
    assert!(self.next_committee.is_none(), ECommitteeSelected);

    // Prepare the next epoch public keys collection.
    let committee = self.compute_next_committee();
    let mut public_keys = vector[];
    let (node_ids, shard_assignments) = (*committee.inner()).into_keys_values();

    // Prepare voting parameters.
    let mut write_prices = priority_queue::new(vector[]);
    let mut storage_prices = priority_queue::new(vector[]);
    let mut capacity_votes = priority_queue::new(vector[]);

    // Iterate over the next committee to do the following:
    // - store the next epoch public keys for the nodes
    // - calculate the votes for the next epoch parameters
    node_ids.length().do!(|idx| {
        let id = node_ids[idx];
        let pool = &self.pools[id];
        let weight = shard_assignments[idx].length();

        // Sanity check, every committee member must have at least 1 shard.
        assert!(weight > 0, EZeroNodeWeight);

        // Store the public key for the node.
        public_keys.push_back(*pool.node_info().next_epoch_public_key());

        // Perform calculation of the votes.
        write_prices.insert(pool.write_price(), weight);
        storage_prices.insert(pool.storage_price(), weight);
        // Perform calculation for the capacity vote on u128 to prevent overflows.
        let capacity_vote =
            (pool.node_capacity() as u128 * (self.n_shards as u128)) / (weight as u128);
        let capacity_vote = capacity_vote.min(std::u64::max_value!() as u128) as u64;
        capacity_votes.insert(capacity_vote, weight);
    });

    // Public keys are inherently sorted by the Node ID.
    let public_keys = vec_map::from_keys_values(node_ids, public_keys);

    self.next_epoch_public_keys.swap(public_keys);
    self.next_committee = option::some(committee);

    let epoch_params = epoch_parameters::new(
        quorum_above(&mut capacity_votes, self.n_shards),
        quorum_below(&mut storage_prices, self.n_shards),
        quorum_below(&mut write_prices, self.n_shards),
    );

    self.next_epoch_params = option::some(epoch_params);
}

/// Take the highest value, s.t. a quorum (2f + 1) voted for a value larger or equal to this.
fun quorum_above(vote_queue: &mut PriorityQueue<u64>, n_shards: u16): u64 {
    let mut sum_weight = 0;
    loop {
        let (value, weight) = vote_queue.pop_max();
        sum_weight = sum_weight + weight;
        if (is_quorum_for_n_shards(sum_weight, n_shards as u64)) {
            return value
        };
    }
}

/// Take the lowest value, s.t. a quorum  (2f + 1) voted for a value lower or equal to this.
fun quorum_below(vote_queue: &mut PriorityQueue<u64>, n_shards: u16): u64 {
    let mut sum_weight = n_shards as u64;
    // We have a quorum initially, so we remove nodes until doing so breaks the quorum.
    // The value at that point is the minimum value with support from a quorum.
    loop {
        let (value, weight) = vote_queue.pop_max();
        sum_weight = sum_weight - weight;
        if (!is_quorum_for_n_shards(sum_weight, n_shards as u64)) {
            return value
        };
    }
}

// === Governance ===

/// Sets the governance authorized object for the pool.
public(package) fun set_governance_authorized(
    self: &mut StakingInnerV1,
    node_id: ID,
    auth: Authenticated,
    authorized: Authorized,
) {
    self.pools[node_id].set_governance_authorized(auth, authorized)
}

/// Checks if the governance authorized object matches the authenticated object.
public(package) fun check_governance_authorization(
    self: &StakingInnerV1,
    node_id: ID,
    auth: Authenticated,
): bool {
    auth.matches(self.pools[node_id].governance_authorized())
}

/// Returns the current node weight for the given node id.
public(package) fun get_current_node_weight(self: &StakingInnerV1, node_id: ID): u16 {
    // Check if the node is in the committee.
    assert!(self.committee.inner().contains(&node_id), ENotInCommittee);
    let weight = self.committee.shards(&node_id).length();
    assert!(weight <= std::u16::max_value!() as u64, EInvalidNodeWeight);
    weight as u16
}

// === Voting ===

/// Sets the next commission rate for the pool.
public(package) fun set_next_commission(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    commission_rate: u16,
) {
    let wctx = &self.new_walrus_context();
    self.pools[cap.node_id()].set_next_commission(commission_rate, wctx);
}

/// Sets the storage price vote for the pool.
public(package) fun set_storage_price_vote(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    storage_price: u64,
) {
    self.pools[cap.node_id()].set_next_storage_price(storage_price);
}

/// Sets the write price vote for the pool.
public(package) fun set_write_price_vote(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    write_price: u64,
) {
    self.pools[cap.node_id()].set_next_write_price(write_price);
}

/// Sets the node capacity vote for the pool.
public(package) fun set_node_capacity_vote(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    node_capacity: u64,
) {
    self.pools[cap.node_id()].set_next_node_capacity(node_capacity);
}

// === Update Node Parameters ===

/// Sets the public key of a node to be used starting from the next epoch for which the node is
/// selected.
public(package) fun set_next_public_key(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    public_key: vector<u8>,
    proof_of_possession: vector<u8>,
    ctx: &TxContext,
) {
    let wctx = &self.new_walrus_context();
    self.pools[cap.node_id()].set_next_public_key(public_key, proof_of_possession, wctx, ctx);
}

/// Sets the name of a storage node.
public(package) fun set_name(self: &mut StakingInnerV1, cap: &StorageNodeCap, name: String) {
    self.pools[cap.node_id()].set_name(name);
}

/// Sets the network address or host of a storage node.
public(package) fun set_network_address(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    network_address: String,
) {
    self.pools[cap.node_id()].set_network_address(network_address);
}

/// Sets the public key used for TLS communication for a node.
public(package) fun set_network_public_key(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    network_public_key: vector<u8>,
) {
    self.pools[cap.node_id()].set_network_public_key(network_public_key);
}

/// Sets the metadata of a storage node.
public(package) fun set_node_metadata(
    self: &mut StakingInnerV1,
    cap: &StorageNodeCap,
    metadata: NodeMetadata,
) {
    self.pools[cap.node_id()].set_node_metadata(metadata);
}

// === Staking ===

/// Destroys the pool if it is empty, after the last stake has been withdrawn.
public(package) fun destroy_empty_pool(
    self: &mut StakingInnerV1,
    node_id: ID,
    _ctx: &mut TxContext,
) {
    self.pools.remove(node_id).destroy_empty()
}

/// Stakes the given amount of `T` with the pool, returning the `StakedWal`.
public(package) fun stake_with_pool(
    self: &mut StakingInnerV1,
    to_stake: Coin<WAL>,
    node_id: ID,
    ctx: &mut TxContext,
): StakedWal {
    let wctx = &self.new_walrus_context();
    let pool = &mut self.pools[node_id];
    let staked_wal = pool.stake(to_stake.into_balance(), wctx, ctx);

    // Active set only tracks the stake for the next vote, which either happens for the committee
    // in wctx.epoch() + 1, or in wctx.epoch() + 2, depending on whether the vote already happened.
    let balance = match (self.epoch_state) {
        EpochState::NextParamsSelected(_) => pool.wal_balance_at_epoch(wctx.epoch() + 2),
        _ => pool.wal_balance_at_epoch(wctx.epoch() + 1),
    };
    self.active_set.borrow_mut().insert_or_update(node_id, balance);
    staked_wal
}

/// Requests withdrawal of the given amount from the `StakedWAL`, marking it as
/// `Withdrawing`. Once the epoch is greater than the `withdraw_epoch`, the
/// withdrawal can be performed.
public(package) fun request_withdraw_stake(
    self: &mut StakingInnerV1,
    staked_wal: &mut StakedWal,
    _ctx: &mut TxContext,
) {
    let wctx = &self.new_walrus_context();
    let node_id = staked_wal.node_id();
    let pool = &mut self.pools[node_id];

    pool.request_withdraw_stake(
        staked_wal,
        self.committee.contains(&node_id),
        self.next_committee.is_some_and!(|cmt| cmt.contains(&node_id)),
        wctx,
    );

    let balance = match (self.epoch_state) {
        EpochState::NextParamsSelected(_) => pool.wal_balance_at_epoch(wctx.epoch() + 2),
        _ => pool.wal_balance_at_epoch(wctx.epoch() + 1),
    };
    self.active_set.borrow_mut().insert_or_update(node_id, balance);
}

/// Perform the withdrawal of the staked WAL, returning the amount to the caller.
/// The `StakedWal` must be in the `Withdrawing` state, and the epoch must be
/// greater than the `withdraw_epoch`.
public(package) fun withdraw_stake(
    self: &mut StakingInnerV1,
    staked_wal: StakedWal,
    ctx: &mut TxContext,
): Coin<WAL> {
    let wctx = &self.new_walrus_context();
    let node_id = staked_wal.node_id();
    let pool = &mut self.pools[node_id];
    let wal_balance = pool.withdraw_stake(
        staked_wal,
        self.committee.contains(&node_id),
        self.next_committee.is_some_and!(|cmt| cmt.contains(&node_id)),
        wctx,
    );

    let balance = match (self.epoch_state) {
        EpochState::NextParamsSelected(_) => pool.wal_balance_at_epoch(wctx.epoch() + 2),
        _ => pool.wal_balance_at_epoch(wctx.epoch() + 1),
    };
    self.active_set.borrow_mut().insert_or_update(node_id, balance);
    wal_balance.into_coin(ctx)
}

public(package) fun try_join_active_set(self: &mut StakingInnerV1, cap: &StorageNodeCap) {
    let node_id = cap.node_id();
    let wctx = &self.new_walrus_context();
    let pool = &self.pools[node_id];

    // Active set only tracks the stake for the next vote, which either happens for the committee
    // in wctx.epoch() + 1, or in wctx.epoch() + 2, depending on whether the vote already happened.
    let balance = match (self.epoch_state) {
        EpochState::NextParamsSelected(_) => pool.wal_balance_at_epoch(wctx.epoch() + 2),
        _ => pool.wal_balance_at_epoch(wctx.epoch() + 1),
    };
    self.active_set.borrow_mut().insert_or_update(node_id, balance);
}

// === System ===

/// Computes the committee for the next epoch.
public(package) fun compute_next_committee(self: &StakingInnerV1): Committee {
    let distribution = self.apportionment();

    // if we are dealing with the first epoch, we need to assign the shards to the
    // nodes in a sequential manner. Assuming there is at least 1 node in the set.
    if (self.committee.size() == 0) committee::initialize(distribution)
    else self.committee.transition(distribution)
}

fun apportionment(self: &StakingInnerV1): VecMap<ID, u16> {
    let (active_ids, stake) = self.active_set.borrow().active_ids_and_stake();
    let n_nodes = stake.length();
    // TODO better ranking (#943)
    let priorities = vector::tabulate!(n_nodes, |i| n_nodes - i);
    let shards = dhondt(priorities, self.n_shards, stake);
    let mut distribution = vec_map::empty();
    // Filter out nodes with 0 shards.
    active_ids.zip_do!(shards, |id, shards| if (shards > 0) distribution.insert(id, shards));
    distribution
}

// Implementation of the D'Hondt method (aka Jefferson method) for apportionment.
fun dhondt(
    // Priorities for the nodes for tie-breaking. Nodes with a higher priority value
    // have a higher precedence.
    node_priorities: vector<u64>,
    n_shards: u16,
    stake: vector<u64>,
): vector<u16> {
    use std::uq64_64;
    use walrus::apportionment_queue;

    let total_stake = stake.fold!(0, |acc, x| acc + x);

    let n_nodes = stake.length();
    let n_shards = n_shards as u64;
    assert!(total_stake > 0, ENoStake);

    // Limit the number of shards per node if there are enough nodes.
    let max_shards = max_shards_per_node(n_nodes, n_shards);

    // Initial assignment following Hagenbach-Bischoff.
    // This assigns an initial number of shards to each node, s.t. this does not exceed the final
    // assignment.
    // The denominator (`total_stake/(n_shards + 1) + 1`) is called "distribution number" and
    // is the amount of stake that guarantees receiving a shard with the d'Hondt method. By
    // dividing the stake per node by this distribution number and rounding down (integer
    // division), we therefore get a lower bound for the number of shards assigned to the node.
    let mut shards = stake.map_ref!(|s| (*s / (total_stake / (n_shards + 1) + 1)).min(max_shards));
    // Set up quotients priority queue.
    let mut quotients = apportionment_queue::new();
    n_nodes.do!(|index| {
        if (shards[index] != max_shards) {
            let quotient = uq64_64::from_quotient(stake[index] as u128, shards[index] as u128 + 1);
            quotients.insert(quotient, node_priorities[index], index);
        };
    });

    if (n_nodes == 0) return vector[];
    let mut n_shards_distributed = shards.fold!(0, |acc, x| acc + x);
    // Loop until all shards are distributed.
    while (n_shards_distributed != n_shards) {
        // Get the node with the highest quotient, assign an additional shard and adjust the
        // quotient.
        // quotients is non-empty since SHARDS_LIMIT_DENOMINATOR <= MIN_NODES_FOR_SHARDS_LIMIT.
        let (_quotient, tie_breaker, index) = quotients.pop_max();
        *&mut shards[index] = shards[index] + 1;
        if (shards[index] != max_shards) {
            let quotient = uq64_64::from_quotient(stake[index] as u128, shards[index] as u128 + 1);
            quotients.insert(quotient, tie_breaker, index);
        };
        n_shards_distributed = n_shards_distributed + 1;
    };
    shards.map!(|s| s as u16)
}

/// Returns the maximum number of shards per node.
fun max_shards_per_node(n_nodes: u64, n_shards: u64): u64 {
    if (n_nodes >= (MIN_NODES_FOR_SHARDS_LIMIT as u64)) {
        n_shards / (SHARDS_LIMIT_DENOMINATOR as u64)
    } else {
        (n_shards * (MIN_NODES_FOR_SHARDS_LIMIT as u64)).divide_and_round_up(
            n_nodes * (SHARDS_LIMIT_DENOMINATOR as u64),
        )
    }
}

/// Initiates the epoch change if the current time allows.
public(package) fun initiate_epoch_change(
    self: &mut StakingInnerV1,
    clock: &Clock,
    rewards: VecMap<ID, Balance<WAL>>,
) {
    let last_epoch_change = match (self.epoch_state) {
        EpochState::NextParamsSelected(last_epoch_change) => last_epoch_change,
        _ => abort EWrongEpochState,
    };

    let now = clock.timestamp_ms();

    if (self.epoch == 0) assert!(now >= self.first_epoch_start, EWrongEpochState)
    else assert!(now >= last_epoch_change + self.epoch_duration, EWrongEpochState);

    self.advance_epoch(rewards);
}

/// Sets the next epoch of the system and emits the epoch change start event.
public(package) fun advance_epoch(self: &mut StakingInnerV1, rewards: VecMap<ID, Balance<WAL>>) {
    assert!(self.next_committee.is_some(), EWrongEpochState);

    self.epoch = self.epoch + 1;
    self.previous_committee = self.committee;
    self.committee = self.next_committee.extract(); // overwrites the current committee
    self.epoch_state = EpochState::EpochChangeSync(0);

    // Wctx is already for the new epoch.
    let wctx = &self.new_walrus_context();

    // Take the `ActiveSet` into the function scope just once.
    let active_set = self.active_set.borrow_mut();

    // Find nodes that just joined, and advance their epoch.
    let (_, new_ids) = committee::diff(&self.previous_committee, &self.committee);

    let (node_ids, rewards) = rewards.into_keys_values();
    rewards.zip_do!(node_ids, |node_reward, node_id| {
        let pool = &mut self.pools[node_id];
        pool.advance_epoch(node_reward, wctx);
        active_set.insert_or_update(node_id, pool.wal_balance_at_epoch(wctx.epoch() + 1));
    });

    // fill-in the nodes that just joined and don't have rewards yet
    new_ids.do!(|node_id| {
        let pool = &mut self.pools[node_id];
        pool.advance_epoch(balance::zero(), wctx);
        active_set.insert_or_update(node_id, pool.wal_balance_at_epoch(wctx.epoch() + 1));
    });

    // Emit epoch change start event.
    events::emit_epoch_change_start(self.epoch);
}

/// Signals to the contract that the node has received all its shards for the new epoch.
public(package) fun epoch_sync_done(
    self: &mut StakingInnerV1,
    cap: &mut StorageNodeCap,
    epoch: u32,
    clock: &Clock,
) {
    // Make sure the node hasn't attested yet, and set the new epoch as the last sync done epoch.
    assert!(epoch == self.epoch, EInvalidSyncEpoch);
    assert!(cap.last_epoch_sync_done() < self.epoch, EDuplicateSyncDone);
    cap.set_last_epoch_sync_done(self.epoch);

    assert!(self.committee.inner().contains(&cap.node_id()), ENotInCommittee);
    let node_shards = self.committee.shards(&cap.node_id());
    match (self.epoch_state) {
        EpochState::EpochChangeSync(weight) => {
            let weight = weight + (node_shards.length() as u16);
            if (self.is_quorum(weight)) {
                self.epoch_state = EpochState::EpochChangeDone(clock.timestamp_ms());
                events::emit_epoch_change_done(self.epoch);
            } else {
                self.epoch_state = EpochState::EpochChangeSync(weight);
            }
        },
        _ => {},
    };
    // Emit the event that the node has received all shards.
    events::emit_shards_received(self.epoch, *node_shards);
}

// === Accessors ===

/// Returns the metadata of the node with the given `ID`.
public(package) fun node_metadata(self: &StakingInnerV1, node_id: ID): NodeMetadata {
    self.pools[node_id].node_info().metadata()
}

/// Returns the Option with next committee.
public(package) fun next_committee(self: &StakingInnerV1): &Option<Committee> {
    &self.next_committee
}

/// Returns the next epoch parameters if set, otherwise aborts with an error.
public(package) fun next_epoch_params(self: &StakingInnerV1): &EpochParams {
    self.next_epoch_params.borrow()
}

/// Get the current epoch.
public(package) fun epoch(self: &StakingInnerV1): u32 {
    self.epoch
}

/// Get the current committee.
public(package) fun committee(self: &StakingInnerV1): &Committee {
    &self.committee
}

/// Get the previous committee.
public(package) fun previous_committee(self: &StakingInnerV1): &Committee {
    &self.previous_committee
}

/// Construct the BLS committee for the next epoch.
public(package) fun next_bls_committee(self: &mut StakingInnerV1): BlsCommittee {
    assert!(self.next_committee.is_some(), ENextCommitteeIsEmpty);

    let public_keys = self.next_epoch_public_keys.swap(vec_map::empty());
    let (pk_ids, public_keys) = public_keys.into_keys_values();
    let (ids, shard_assignments) = (*self.next_committee.borrow().inner()).into_keys_values();

    // All of the sets are guaranteed to be sorted and of the same length.
    // Therefore, we can safely iterate over them in parallel.
    let members = vector::tabulate!(ids.length(), |i| {
        let node_id = &ids[i];
        let shards = shard_assignments[i].length() as u16;
        let pk_node_id = &pk_ids[i];
        let pk = public_keys[i];

        // sanity check that the keys are in the same order
        assert!(node_id == pk_node_id, EIncorrectNodeOrder);
        bls_aggregate::new_bls_committee_member(pk, shards, *node_id)
    });

    bls_aggregate::new_bls_committee(self.epoch + 1, members)
}

/// Check if a node with the given `ID` exists in the staking pools.
public(package) fun has_pool(self: &StakingInnerV1, node_id: ID): bool {
    self.pools.contains(node_id)
}

/// Returns the total number of shards.
public(package) fun n_shards(self: &StakingInnerV1): u16 {
    self.n_shards
}

// === Utility functions ===

/// Calculate the rewards for an amount with value `staked_principal`, staked in the pool with
/// the given `node_id` between `activation_epoch` and `withdraw_epoch`.
public(package) fun calculate_rewards(
    self: &StakingInnerV1,
    node_id: ID,
    staked_principal: u64,
    activation_epoch: u32,
    withdraw_epoch: u32,
): u64 {
    assert!(self.pools.contains(node_id), EPoolNotFound);
    self.pools[node_id].calculate_rewards(staked_principal, activation_epoch, withdraw_epoch)
}

// === Internal ===

fun new_walrus_context(self: &StakingInnerV1): WalrusContext {
    walrus_context::new(
        self.epoch,
        self.next_committee.is_some(),
        self.committee.to_inner(),
    )
}

public(package) fun is_quorum(self: &StakingInnerV1, weight: u16): bool {
    is_quorum_for_n_shards(weight as u64, self.n_shards as u64)
}

fun is_quorum_for_n_shards(weight: u64, n_shards: u64): bool {
    3 * weight >= 2 * n_shards + 1
}

// ==== Tests ===
#[test_only]
use walrus::test_utils::assert_eq;

#[test_only]
public(package) fun is_epoch_sync_done(self: &StakingInnerV1): bool {
    match (self.epoch_state) {
        EpochState::EpochChangeDone(_) => true,
        _ => false,
    }
}

#[test_only]
public(package) fun active_set(self: &mut StakingInnerV1): &mut ActiveSet {
    self.active_set.borrow_mut()
}

#[test_only]
#[syntax(index)]
/// Get the pool with the given `ID`.
public(package) fun borrow(self: &StakingInnerV1, node_id: ID): &StakingPool {
    &self.pools[node_id]
}

#[test_only]
#[syntax(index)]
/// Get mutable reference to the pool with the given `ID`.
public(package) fun borrow_mut(self: &mut StakingInnerV1, node_id: ID): &mut StakingPool {
    &mut self.pools[node_id]
}

#[test_only]
public(package) fun pub_dhondt(n_shards: u16, stake: vector<u64>): vector<u16> {
    let n_nodes = stake.length();
    // TODO better ranking (#943)
    let priorities = vector::tabulate!(n_nodes, |i| n_nodes - i);
    dhondt(priorities, n_shards, stake)
}

#[test]
fun test_quorum_above() {
    let mut queue = priority_queue::new(vector[]);
    let votes = vector[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let weights = vector[5, 5, 4, 6, 3, 7, 2, 8, 1, 9];
    votes.zip_do!(weights, |vote, weight| queue.insert(vote, weight));
    assert_eq!(quorum_above(&mut queue, 50), 4);
}

#[test]
fun test_quorum_above_all_above() {
    let mut queue = priority_queue::new(vector[]);
    let votes = vector[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let weights = vector[17, 1, 1, 1, 3, 7, 2, 8, 1, 9];
    votes.zip_do!(weights, |vote, weight| queue.insert(vote, weight));
    assert_eq!(quorum_above(&mut queue, 50), 1);
}

#[test]
fun test_quorum_above_one_value() {
    let mut queue = priority_queue::new(vector[]);
    queue.insert(1, 50);
    assert_eq!(quorum_above(&mut queue, 50), 1);
}

#[test]
fun test_quorum_below() {
    let mut queue = priority_queue::new(vector[]);
    let votes = vector[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let weights = vector[5, 5, 4, 6, 3, 7, 4, 6, 1, 9];
    votes.zip_do!(weights, |vote, weight| queue.insert(vote, weight));
    assert_eq!(quorum_below(&mut queue, 50), 7);
}

#[test]
fun test_quorum_below_all_below() {
    let mut queue = priority_queue::new(vector[]);
    let votes = vector[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let weights = vector[5, 5, 4, 6, 3, 7, 1, 1, 1, 17];
    votes.zip_do!(weights, |vote, weight| queue.insert(vote, weight));
    assert_eq!(quorum_below(&mut queue, 50), 10);
}

#[test]
fun test_quorum_below_one_value() {
    let mut queue = priority_queue::new(vector[]);
    queue.insert(1, 50);
    assert_eq!(quorum_below(&mut queue, 50), 1);
}
