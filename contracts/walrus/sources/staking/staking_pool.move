// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: staking_pool
module walrus::staking_pool;

use std::string::String;
use sui::{bag::{Self, Bag}, balance::{Self, Balance}, table::{Self, Table}};
use wal::wal::WAL;
use walrus::{
    auth::{Self, Authenticated, Authorized},
    messages,
    node_metadata::NodeMetadata,
    pending_values::{Self, PendingValues},
    pool_exchange_rate::{Self, PoolExchangeRate},
    staked_wal::{Self, StakedWal},
    storage_node::{Self, StorageNodeInfo},
    walrus_context::WalrusContext
};

// Limit name length to 100 characters. Keep in sync with `MAX_NODE_NAME_LENGTH` in
// `crates/walrus-service/src/common/utils.rs`.
const MAX_NODE_NAME_LENGTH: u64 = 100;

// 253 characters in DNS name + 5 characters for the port + 1 for the delimiter.
const MAX_NETWORK_ADDRESS_LENGTH: u64 = 259;

// The number of basis points in 100%.
const N_BASIS_POINTS: u16 = 100_00;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The epoch of the pool has already been advanced.
const EPoolAlreadyUpdated: u64 = 0;
/// Error in a calculation. Indicates that a sanity check failed.
const ECalculationError: u64 = 1;
/// The state of the pool and the parameters to advance the epoch are not consistent.
const EIncorrectEpochAdvance: u64 = 2;
/// Trying to destroy a non-empty pool.
const EPoolNotEmpty: u64 = 3;
/// Invalid proof of possession during the pool creation.
const EInvalidProofOfPossession: u64 = 4;
/// Trying to set the pool to withdrawing state when it is already withdrawing.
const EPoolAlreadyWithdrawing: u64 = 5;
/// Pool is not in `New` or `Active` state.
const EPoolIsNotActive: u64 = 6;
/// Trying to stake zero amount.
const EZeroStake: u64 = 7;
/// StakedWal is already in `Withdrawing` state.
const ENotStaked: u64 = 8;
/// Trying to withdraw stake from the incorrect pool.
const EIncorrectPoolId: u64 = 9;
/// Trying to withdraw active stake.
const ENotWithdrawing: u64 = 10;
/// Attempt to withdraw before `withdraw_epoch`.
const EWithdrawEpochNotReached: u64 = 11;
/// Attempt to withdraw before `activation_epoch`.
const EActivationEpochNotReached: u64 = 12;
/// Requesting withdrawal for the stake that can be withdrawn directly.
const EWithdrawDirectly: u64 = 13;
/// Incorrect commission rate.
const EIncorrectCommissionRate: u64 = 14;
/// Trying to collect commission or change receiver without authorization.
const EAuthorizationFailure: u64 = 15;
/// Invalid network address length.
const EInvalidNetworkAddressLength: u64 = 16;
/// Invalid name length.
const EInvalidNameLength: u64 = 17;
/// The number of shares for the staked wal are zero.
const EZeroShares: u64 = 18;

/// Represents the state of the staking pool.
public enum PoolState has copy, drop, store {
    // The pool is active and can accept stakes.
    Active,
    // The pool awaits the stake to be withdrawn. The value inside the
    // variant is the epoch in which the pool will be withdrawn.
    Withdrawing(u32),
    // The pool is empty and can be destroyed.
    Withdrawn,
}

/// The parameters for the staking pool. Stored for the next epoch.
public struct VotingParams has copy, drop, store {
    /// Voting: storage price for the next epoch.
    storage_price: u64,
    /// Voting: write price for the next epoch.
    write_price: u64,
    /// Voting: node capacity for the next epoch.
    node_capacity: u64,
}

/// Represents a single staking pool for a token. Even though it is never
/// transferred or shared, the `key` ability is added for discoverability
/// in the `ObjectTable`.
///
/// High level overview of the staking pool:
/// The pool maintains a balance of WAL 'wal_balance' that is increased
/// when stakes/rewards are added to the pool, and is decreased when
/// stakes are withdrawn.
/// To track the users' portion of the pool, we associate shares to the
/// staked WAL. Initially, the share price is 1 WAL per share.
/// When a new stake is added to the pool, the total number of shares
/// increases by an amount that corresponds to the share price at that
/// time. E.g., if the share price is 2 WAL per share, and 10 WAL are
/// added to the pool, the total number of shares is increased by 5
/// shares. The total number of shares is stored in 'num_shares'.
///
/// As stakes are added/withdrawn only in the granularity of epochs, we
/// maintain a share price per epoch in 'exchange_rates'.
/// StakedWal objects only need to store the epoch when they are created,
/// and the amount of WAL they locked. Whenever a settlement is performed
/// for a StakedWal, we calculate the number of shares that correspond to
/// the amount of WAL that was locked using the exchange rate at the time
/// of the lock, and then convert it to the amount of WAL that corresponds
/// to the current share price.
public struct StakingPool has key, store {
    id: UID,
    /// The current state of the pool.
    state: PoolState,
    /// Current epoch's pool parameters.
    voting_params: VotingParams,
    /// The storage node info for the pool.
    node_info: StorageNodeInfo,
    /// The epoch when the pool is / will be activated.
    /// Serves information purposes only, the checks are performed in the `state`
    /// property.
    activation_epoch: u32,
    /// Epoch when the pool was last updated.
    latest_epoch: u32,
    /// Currently staked WAL in the pool + rewards pool.
    wal_balance: u64,
    /// The total number of shares in the current epoch.
    num_shares: u64,
    /// The amount of the shares that will be withdrawn in E+1 or E+2.
    /// We use this amount to calculate the WAL withdrawal in the
    /// `process_pending_stake`.
    pending_shares_withdraw: PendingValues,
    /// The amount of the stake requested for withdrawal for a node that may
    /// part of the next committee. Stores principals of not yet active stakes.
    /// In practice, those tokens are staked for exactly one epoch.
    pre_active_withdrawals: PendingValues,
    /// The pending commission rate for the pool. Commission rate is applied in
    /// E+2, so we store the value for the matching epoch and apply it in the
    /// `advance_epoch` function.
    pending_commission_rate: PendingValues,
    /// The commission rate for the pool, in basis points.
    commission_rate: u16,
    /// Historical exchange rates for the pool. The key is the epoch when the
    /// exchange rate was set, and the value is the exchange rate (the ratio of
    /// the amount of WAL tokens for the pool shares).
    exchange_rates: Table<u32, PoolExchangeRate>,
    /// The amount of stake that will be added to the `wal_balance`. Can hold
    /// up to two keys: E+1 and E+2, due to the differences in the activation
    /// epoch.
    ///
    /// ```
    /// E+1 -> Balance
    /// E+2 -> Balance
    /// ```
    ///
    /// Single key is cleared in the `advance_epoch` function, leaving only the
    /// next epoch's stake.
    pending_stake: PendingValues,
    /// The rewards that the pool has received from being in the committee.
    rewards_pool: Balance<WAL>,
    /// The commission that the pool has received from the rewards.
    commission: Balance<WAL>,
    /// An Object or an address which can claim the commission.
    commission_receiver: Authorized,
    /// An Object or address that can authorize governance actions, such as upgrades.
    governance_authorized: Authorized,
    /// Reserved for future use and migrations.
    extra_fields: Bag,
}

/// Create a new `StakingPool` object.
/// If committee is selected, the pool will be activated in the next epoch.
/// Otherwise, it will be activated in the current epoch.
public(package) fun new(
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
    wctx: &WalrusContext,
    ctx: &mut TxContext,
): StakingPool {
    let id = object::new(ctx);
    let node_id = id.to_inner();

    // Verify proof of possession
    assert!(
        messages::new_proof_of_possession_msg(
            wctx.epoch(),
            ctx.sender(),
            public_key,
        ).verify_proof_of_possession(proof_of_possession),
        // Invalid proof of possession in the `new` function.
        EInvalidProofOfPossession,
    );

    // Verify name length.
    assert!(name.length() <= MAX_NODE_NAME_LENGTH, EInvalidNameLength);

    // Verify network address length.
    assert!(network_address.length() <= MAX_NETWORK_ADDRESS_LENGTH, EInvalidNetworkAddressLength);

    // Verify commission rate.
    assert!(commission_rate <= N_BASIS_POINTS, EIncorrectCommissionRate);

    let activation_epoch = if (wctx.committee_selected()) {
        wctx.epoch() + 1
    } else {
        wctx.epoch()
    };

    let mut exchange_rates = table::new(ctx);
    exchange_rates.add(activation_epoch, pool_exchange_rate::flat());

    StakingPool {
        id,
        state: PoolState::Active,
        exchange_rates,
        voting_params: VotingParams {
            storage_price,
            write_price,
            node_capacity,
        },
        node_info: storage_node::new(
            name,
            node_id,
            network_address,
            public_key,
            network_public_key,
            metadata,
            ctx,
        ),
        commission_rate,
        activation_epoch,
        latest_epoch: wctx.epoch(),
        pending_stake: pending_values::empty(),
        pending_shares_withdraw: pending_values::empty(),
        pre_active_withdrawals: pending_values::empty(),
        pending_commission_rate: pending_values::empty(),
        wal_balance: 0,
        num_shares: 0,
        rewards_pool: balance::zero(),
        commission: balance::zero(),
        commission_receiver: auth::authorized_address(ctx.sender()),
        governance_authorized: auth::authorized_address(ctx.sender()),
        extra_fields: bag::new(ctx),
    }
}

/// Set the state of the pool to `Withdrawing`.
public(package) fun set_withdrawing(pool: &mut StakingPool, wctx: &WalrusContext) {
    assert!(!pool.is_withdrawing(), EPoolAlreadyWithdrawing);
    pool.state = PoolState::Withdrawing(wctx.epoch() + 1);
}

/// Stake the given amount of WAL in the pool.
public(package) fun stake(
    pool: &mut StakingPool,
    to_stake: Balance<WAL>,
    wctx: &WalrusContext,
    ctx: &mut TxContext,
): StakedWal {
    assert!(pool.is_active(), EPoolIsNotActive);
    assert!(to_stake.value() > 0, EZeroStake);

    let current_epoch = wctx.epoch();
    let activation_epoch = if (wctx.committee_selected()) {
        current_epoch + 2
    } else {
        current_epoch + 1
    };

    let staked_amount = to_stake.value();
    let staked_wal = staked_wal::mint(
        pool.id.to_inner(),
        to_stake,
        activation_epoch,
        ctx,
    );

    // Add the stake to the pending stake either for E+1 or E+2.
    pool.pending_stake.insert_or_add(activation_epoch, staked_amount);
    staked_wal
}

/// Request withdrawal of the given amount from the staked WAL.
/// Marks the `StakedWal` as withdrawing and updates the activation epoch.
public(package) fun request_withdraw_stake(
    pool: &mut StakingPool,
    staked_wal: &mut StakedWal,
    in_current_committee: bool,
    in_next_committee: bool,
    wctx: &WalrusContext,
) {
    assert!(staked_wal.value() > 0, EZeroStake);
    assert!(staked_wal.node_id() == pool.id.to_inner(), EIncorrectPoolId);
    assert!(staked_wal.is_staked(), ENotStaked);

    // Only allow requesting if the stake cannot be withdrawn directly.
    assert!(!staked_wal.can_withdraw_early(in_next_committee, wctx), EWithdrawDirectly);

    // Early withdrawal request: only possible if activation epoch has not been
    // reached, and the stake is already counted for the next committee selection.
    if (staked_wal.activation_epoch() == wctx.epoch() + 1) {
        let withdraw_epoch = staked_wal.activation_epoch() + 1;
        // register principal in the early withdrawals, the value will get converted to
        // the token amount in the `process_pending_stake` function
        pool.pre_active_withdrawals.insert_or_add(withdraw_epoch, staked_wal.value());
        staked_wal.set_withdrawing(withdraw_epoch);
        return
    };

    assert!(staked_wal.activation_epoch() <= wctx.epoch(), EActivationEpochNotReached);

    // If the node is in the committee, the stake will be withdrawn in E+2,
    // otherwise in E+1.
    let withdraw_epoch = if (in_next_committee) {
        wctx.epoch() + 2
    } else if (in_current_committee) {
        wctx.epoch() + 1
    } else {
        abort EWithdrawDirectly
    };

    let principal_amount = staked_wal.value();
    let share_amount = pool
        .exchange_rate_at_epoch(staked_wal.activation_epoch())
        .convert_to_share_amount(principal_amount);

    assert!(share_amount != 0, EZeroShares);

    pool.pending_shares_withdraw.insert_or_add(withdraw_epoch, share_amount);
    staked_wal.set_withdrawing(withdraw_epoch);
}

/// Perform the withdrawal of the staked WAL, returning the amount to the caller.
public(package) fun withdraw_stake(
    pool: &mut StakingPool,
    staked_wal: StakedWal,
    in_current_committee: bool,
    in_next_committee: bool,
    wctx: &WalrusContext,
): Balance<WAL> {
    assert!(staked_wal.value() > 0, EZeroStake);
    assert!(staked_wal.node_id() == pool.id.to_inner(), EIncorrectPoolId);

    let activation_epoch = staked_wal.activation_epoch();

    // One step, early withdrawal in the case when committee before
    // activation epoch hasn't been selected. covers both E+1 and E+2 cases.
    if (staked_wal.can_withdraw_early(in_next_committee, wctx)) {
        pool.pending_stake.reduce(activation_epoch, staked_wal.value());
        return staked_wal.into_balance()
    };

    let rewards_amount = if (
        !in_current_committee && !in_next_committee && staked_wal.is_staked()
    ) {
        // One step withdrawal for an inactive node.
        if (activation_epoch > wctx.epoch()) {
            // Not even active stake yet, remove from pending stake.
            pool.pending_stake.reduce(activation_epoch, staked_wal.value());
            0
        } else {
            // Active stake, remove it with the current epoch as the withdraw epoch.
            let share_amount = pool
                .exchange_rate_at_epoch(activation_epoch)
                .convert_to_share_amount(staked_wal.value());
            pool.pending_shares_withdraw.insert_or_add(wctx.epoch(), share_amount);
            pool.calculate_rewards(staked_wal.value(), activation_epoch, wctx.epoch())
        }
        // Note that if the stake is in state Withdrawing, it can either be
        // from a pre-active withdrawal, but then
        // (in_current_committee || in_next_committee) is true since it was
        // an early withdrawal, or from a standard two step withdrawal,
        // which is handled below.
    } else {
        // Normal two-step withdrawals.
        assert!(staked_wal.is_withdrawing(), ENotWithdrawing);
        assert!(staked_wal.withdraw_epoch() <= wctx.epoch(), EWithdrawEpochNotReached);
        assert!(activation_epoch <= wctx.epoch(), EActivationEpochNotReached);
        pool.calculate_rewards(staked_wal.value(), activation_epoch, staked_wal.withdraw_epoch())
    };

    let principal = staked_wal.into_balance();

    // Withdraw rewards. Due to rounding errors, there's a chance that the
    // rewards amount is higher than the rewards pool, in this case, we
    // withdraw the maximum amount possible.
    let rewards_amount = rewards_amount.min(pool.rewards_pool.value());
    let mut to_withdraw = pool.rewards_pool.split(rewards_amount);
    to_withdraw.join(principal);
    to_withdraw
}

/// Advance epoch for the `StakingPool`.
public(package) fun advance_epoch(
    pool: &mut StakingPool,
    mut rewards: Balance<WAL>,
    wctx: &WalrusContext,
) {
    // Process the pending and withdrawal amounts
    let current_epoch = wctx.epoch();

    assert!(current_epoch > pool.latest_epoch, EPoolAlreadyUpdated);
    // Sanity check.
    assert!(rewards.value() == 0 || pool.wal_balance > 0, EIncorrectEpochAdvance);

    // Split the commission from the rewards.
    let total_rewards = rewards.value();
    let commission = rewards.split(
        total_rewards * (pool.commission_rate as u64) / (N_BASIS_POINTS as u64),
    );
    pool.commission.join(commission);

    // Update the commission_rate for the new epoch if there's a pending value.
    // Note that pending commission rates are set 2 epochs ahead, so users are
    // aware of the rate change in advance.
    pool.pending_commission_rate.inner().try_get(&current_epoch).do!(|commission_rate| {
        pool.commission_rate = commission_rate as u16;
        pool.pending_commission_rate.flush(current_epoch);
    });

    // Add rewards to the pool and update the `wal_balance`.
    let rewards_amount = rewards.value();
    pool.rewards_pool.join(rewards);
    pool.wal_balance = pool.wal_balance + rewards_amount;
    pool.latest_epoch = current_epoch;
    pool.node_info.rotate_public_key();

    // Perform stake deduction / addition for the current epoch.
    pool.process_pending_stake(wctx);
}

/// Process the pending stake and withdrawal requests for the pool. Called in the
/// `advance_epoch` function in case the pool is in the committee and receives the
/// rewards. And may be called in user-facing functions to update the pool state,
/// if the pool is not in the committee.
public(package) fun process_pending_stake(pool: &mut StakingPool, wctx: &WalrusContext) {
    let current_epoch = wctx.epoch();

    // Set the exchange rate for the current epoch.
    let exchange_rate = pool_exchange_rate::new(
        pool.wal_balance,
        pool.num_shares,
    );
    pool.exchange_rates.add(current_epoch, exchange_rate);

    // Process additions.
    pool.wal_balance = pool.wal_balance + pool.pending_stake.flush(current_epoch);

    // Process withdrawals.

    // each value in pending withdrawals contains the principal which became
    // active in the previous epoch. so unlike other pending values, we need to
    // flush it one by one, recalculating the exchange rate and pool share amount
    // for each early withdrawal epoch.
    let mut pre_active_shares_withdraw = 0;
    let mut pre_active_withdrawals = pool.pre_active_withdrawals.unwrap();
    pre_active_withdrawals.keys().do!(|epoch| if (epoch <= current_epoch) {
        let (_, epoch_value) = pre_active_withdrawals.remove(&epoch);
        // recall that pre_active_withdrawals contains stakes that were
        // active for exactly 1 epoch.
        let activation_epoch = epoch - 1;
        let shares_for_epoch = pool
            .exchange_rate_at_epoch(activation_epoch)
            .convert_to_share_amount(epoch_value);

        pre_active_shares_withdraw = pre_active_shares_withdraw + shares_for_epoch;
    });
    // don't forget to flush the early withdrawals since we worked on a copy
    let _ = pool.pre_active_withdrawals.flush(current_epoch);

    let shares_withdraw = pool.pending_shares_withdraw.flush(current_epoch);
    let pending_withdrawal = exchange_rate.convert_to_wal_amount(
        shares_withdraw + pre_active_shares_withdraw,
    );

    // Sanity check that the amount is not higher than the pool balance.
    assert!(pool.wal_balance >= pending_withdrawal, ECalculationError);
    pool.wal_balance = pool.wal_balance - pending_withdrawal;

    // Recalculate the total number of shares according to the exchange rate.
    pool.num_shares = exchange_rate.convert_to_share_amount(pool.wal_balance);
}

// === Pool parameters ===

/// Sets the next commission rate for the pool.
public(package) fun set_next_commission(
    pool: &mut StakingPool,
    commission_rate: u16,
    wctx: &WalrusContext,
) {
    assert!(commission_rate <= N_BASIS_POINTS, EIncorrectCommissionRate);
    pool.pending_commission_rate.insert_or_replace(wctx.epoch() + 2, commission_rate as u64);
}

/// Sets the next storage price for the pool.
public(package) fun set_next_storage_price(pool: &mut StakingPool, storage_price: u64) {
    pool.voting_params.storage_price = storage_price;
}

/// Sets the next write price for the pool.
public(package) fun set_next_write_price(pool: &mut StakingPool, write_price: u64) {
    pool.voting_params.write_price = write_price;
}

/// Sets the next node capacity for the pool.
public(package) fun set_next_node_capacity(pool: &mut StakingPool, node_capacity: u64) {
    pool.voting_params.node_capacity = node_capacity;
}

/// Sets the public key to be used starting from the next epoch for which the node is selected.
public(package) fun set_next_public_key(
    self: &mut StakingPool,
    public_key: vector<u8>,
    proof_of_possession: vector<u8>,
    wctx: &WalrusContext,
    ctx: &TxContext,
) {
    // Verify proof of possession
    assert!(
        messages::new_proof_of_possession_msg(
            wctx.epoch(),
            ctx.sender(),
            public_key,
        ).verify_proof_of_possession(proof_of_possession),
        EInvalidProofOfPossession,
    );
    self.node_info.set_next_public_key(public_key);
}

/// Sets the name of the storage node.
public(package) fun set_name(self: &mut StakingPool, name: String) {
    // Verify name length.
    assert!(name.length() <= MAX_NODE_NAME_LENGTH, EInvalidNameLength);

    self.node_info.set_name(name);
}

/// Sets the network address or host of the storage node.
public(package) fun set_network_address(self: &mut StakingPool, network_address: String) {
    // Verify network address length.
    assert!(network_address.length() <= MAX_NETWORK_ADDRESS_LENGTH, EInvalidNetworkAddressLength);

    self.node_info.set_network_address(network_address);
}

/// Sets the public key used for TLS communication.
public(package) fun set_network_public_key(self: &mut StakingPool, network_public_key: vector<u8>) {
    self.node_info.set_network_public_key(network_public_key);
}

/// Sets the node metadata.
public(package) fun set_node_metadata(self: &mut StakingPool, metadata: NodeMetadata) {
    self.node_info.set_node_metadata(metadata);
}

/// Destroy the pool if it is empty.
public(package) fun destroy_empty(pool: StakingPool) {
    assert!(pool.is_empty(), EPoolNotEmpty);

    let StakingPool {
        id,
        exchange_rates,
        rewards_pool,
        commission,
        extra_fields,
        node_info,
        ..,
    } = pool;

    id.delete();
    exchange_rates.drop();
    node_info.destroy();
    commission.destroy_zero();
    rewards_pool.destroy_zero();
    extra_fields.destroy_empty();
}

/// Returns the exchange rate for the given current or future epoch. If there
/// isn't a value for the specified epoch, it will look for the most recent
/// value down to the pool activation epoch.
/// Note that exchange rates are only set for epochs in which the node is in
/// the committee, and otherwise the rate remains static.
public(package) fun exchange_rate_at_epoch(pool: &StakingPool, mut epoch: u32): PoolExchangeRate {
    let activation_epoch = pool.activation_epoch;
    while (epoch >= activation_epoch) {
        if (pool.exchange_rates.contains(epoch)) {
            return pool.exchange_rates[epoch]
        };
        epoch = epoch - 1;
    };

    pool_exchange_rate::flat()
}

/// Returns the expected active stake for current or future epoch `E` for the pool.
/// It processes the pending stake and withdrawal requests from the current epoch
/// to `E`.
///
/// Should be the main function to calculate the active stake for the pool at
/// the given epoch, due to the complexity of the pending stake and withdrawal
/// requests, and lack of immediate updates.
public(package) fun wal_balance_at_epoch(pool: &StakingPool, epoch: u32): u64 {
    let exchange_rate = pool_exchange_rate::new(pool.wal_balance, pool.num_shares);

    let mut pre_active_shares_withdraw = 0;
    let pre_active_withdrawals = pool.pre_active_withdrawals.unwrap();
    pre_active_withdrawals.keys().do_ref!(|old_epoch| if (*old_epoch <= epoch) {
        let wal_value = pre_active_withdrawals.get(old_epoch);
        // recall that pre_active_withdrawals contains stakes that were
        // active for exactly 1 epoch. since the node might have been
        // inactive, this list may contain more than one value
        // (although exchange_rate_at_epoch will return the same value).
        let activation_epoch = *old_epoch - 1;
        let shares_for_epoch = pool
            .exchange_rate_at_epoch(activation_epoch)
            .convert_to_share_amount(*wal_value);

        pre_active_shares_withdraw = pre_active_shares_withdraw + shares_for_epoch;
    });
    let shares_withdraw = pool.pending_shares_withdraw.value_at(epoch);
    let pending_withdrawal = exchange_rate.convert_to_wal_amount(
        shares_withdraw + pre_active_shares_withdraw,
    );

    pool.wal_balance + pool.pending_stake.value_at(epoch) - pending_withdrawal
}

// === Accessors ===

/// Returns the governance authorized object for the pool.
public(package) fun governance_authorized(pool: &StakingPool): &Authorized {
    &pool.governance_authorized
}

/// Sets the governance authorized object for the pool.
public(package) fun set_governance_authorized(
    pool: &mut StakingPool,
    authenticated: Authenticated,
    authorized: Authorized,
) {
    assert!(authenticated.matches(&pool.governance_authorized), EAuthorizationFailure);
    pool.governance_authorized = authorized
}

/// Returns the commission receiver for the pool.
public(package) fun commission_receiver(pool: &StakingPool): &Authorized {
    &pool.commission_receiver
}

/// Sets the commission receiver for the pool.
public(package) fun set_commission_receiver(
    pool: &mut StakingPool,
    auth: Authenticated,
    receiver: Authorized,
) {
    assert!(auth.matches(&pool.commission_receiver), EAuthorizationFailure);
    pool.commission_receiver = receiver
}

/// Returns the commission rate for the pool.
public(package) fun commission_rate(pool: &StakingPool): u16 { pool.commission_rate }

/// Returns the commission amount for the pool.
public(package) fun commission_amount(pool: &StakingPool): u64 { pool.commission.value() }

/// Withdraws the commission from the pool. Amount is optional, if not provided,
/// the full commission is withdrawn.
public(package) fun collect_commission(pool: &mut StakingPool, auth: Authenticated): Balance<WAL> {
    assert!(auth.matches(&pool.commission_receiver), EAuthorizationFailure);
    pool.commission.withdraw_all()
}

/// Returns the rewards amount for the pool.
public(package) fun rewards_amount(pool: &StakingPool): u64 { pool.rewards_pool.value() }

/// Returns the rewards for the pool.
public(package) fun wal_balance(pool: &StakingPool): u64 { pool.wal_balance }

/// Returns the storage price for the pool.
public(package) fun storage_price(pool: &StakingPool): u64 { pool.voting_params.storage_price }

/// Returns the write price for the pool.
public(package) fun write_price(pool: &StakingPool): u64 { pool.voting_params.write_price }

/// Returns the node capacity for the pool.
public(package) fun node_capacity(pool: &StakingPool): u64 { pool.voting_params.node_capacity }

/// Returns the activation epoch for the pool.
public(package) fun activation_epoch(pool: &StakingPool): u32 { pool.activation_epoch }

/// Returns the node info for the pool.
public(package) fun node_info(pool: &StakingPool): &StorageNodeInfo { &pool.node_info }

/// Returns `true` if the pool is active.
public(package) fun is_active(pool: &StakingPool): bool { pool.state == PoolState::Active }

/// Returns `true` if the pool is withdrawing.
public(package) fun is_withdrawing(pool: &StakingPool): bool {
    match (pool.state) {
        PoolState::Withdrawing(_) => true,
        _ => false,
    }
}

/// Returns `true` if the pool is empty.
public(package) fun is_empty(pool: &StakingPool): bool {
    let pending_stake = pool.pending_stake.unwrap();
    let non_empty = pending_stake.keys().count!(|epoch| pending_stake[epoch] != 0);

    pool.rewards_pool.value() == 0 &&
    pool.num_shares == 0 &&
    pool.commission.value() == 0 &&
    pool.wal_balance == 0 &&
    non_empty == 0
}

/// Calculate the rewards for an amount with value `staked_principal`, staked in the pool between
/// `activation_epoch` and `withdraw_epoch`.
public(package) fun calculate_rewards(
    pool: &StakingPool,
    staked_principal: u64,
    activation_epoch: u32,
    withdraw_epoch: u32,
): u64 {
    let shares = pool
        .exchange_rate_at_epoch(activation_epoch)
        .convert_to_share_amount(staked_principal);
    let wal_amount = pool.exchange_rate_at_epoch(withdraw_epoch).convert_to_wal_amount(shares);
    if (wal_amount >= staked_principal) {
        wal_amount - staked_principal
    } else 0
}

#[test_only]
public(package) fun num_shares(pool: &StakingPool): u64 { pool.num_shares }

#[test_only]
public(package) fun latest_epoch(pool: &StakingPool): u32 { pool.latest_epoch }
