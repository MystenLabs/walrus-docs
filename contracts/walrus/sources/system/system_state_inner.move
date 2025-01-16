// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable, unused_mut_parameter, unused_field)]
module walrus::system_state_inner;

use sui::{balance::Balance, coin::Coin, vec_map::{Self, VecMap}};
use wal::wal::WAL;
use walrus::{
    blob::{Self, Blob},
    bls_aggregate::{Self, BlsCommittee},
    encoding::encoded_blob_length,
    epoch_parameters::EpochParams,
    event_blob::{Self, EventBlobCertificationState, new_attestation},
    events,
    extended_field::{Self, ExtendedField},
    messages,
    storage_accounting::{Self, FutureAccountingRingBuffer},
    storage_node::StorageNodeCap,
    storage_resource::{Self, Storage}
};

/// An upper limit for the maximum number of epochs ahead for which a blob can be registered.
/// Needed to bound the size of the `future_accounting`.
const MAX_MAX_EPOCHS_AHEAD: u32 = 1000;

// Keep in sync with the same constant in `crates/walrus-sui/utils.rs`.
const BYTES_PER_UNIT_SIZE: u64 = 1_024 * 1_024; // 1 MiB

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
const EInvalidMaxEpochsAhead: u64 = 0;
const EStorageExceeded: u64 = 1;
const EInvalidEpochsAhead: u64 = 2;
const EInvalidIdEpoch: u64 = 3;
const EIncorrectCommittee: u64 = 4;
const EInvalidAccountingEpoch: u64 = 5;
const EIncorrectAttestation: u64 = 6;
const ERepeatedAttestation: u64 = 7;
const ENotCommitteeMember: u64 = 8;
const EIncorrectDenyListSequence: u64 = 9;
const EIncorrectDenyListNode: u64 = 10;

/// The inner object that is not present in signatures and can be versioned.
#[allow(unused_field)]
public struct SystemStateInnerV1 has store {
    /// The current committee, with the current epoch.
    committee: BlsCommittee,
    // Some accounting
    total_capacity_size: u64,
    used_capacity_size: u64,
    /// The price per unit size of storage.
    storage_price_per_unit_size: u64,
    /// The write price per unit size.
    write_price_per_unit_size: u64,
    /// Accounting ring buffer for future epochs.
    future_accounting: FutureAccountingRingBuffer,
    /// Event blob certification state
    event_blob_certification_state: EventBlobCertificationState,
    /// Sizes of deny lists for storage nodes. Only current committee members
    /// can register their updates in this map. Hence, we don't expect it to bloat.
    ///
    /// Max number of stored entries is ~6500. If there's any concern about the
    /// performance of the map, it can be cleaned up as a side effect of the
    /// updates / registrations.
    deny_list_sizes: ExtendedField<VecMap<ID, u64>>,
}

/// Creates an empty system state with a capacity of zero and an empty
/// committee.
public(package) fun create_empty(max_epochs_ahead: u32, ctx: &mut TxContext): SystemStateInnerV1 {
    let committee = bls_aggregate::new_bls_committee(0, vector[]);
    assert!(max_epochs_ahead <= MAX_MAX_EPOCHS_AHEAD, EInvalidMaxEpochsAhead);
    let future_accounting = storage_accounting::ring_new(max_epochs_ahead);
    let event_blob_certification_state = event_blob::create_with_empty_state();
    SystemStateInnerV1 {
        committee,
        total_capacity_size: 0,
        used_capacity_size: 0,
        storage_price_per_unit_size: 0,
        write_price_per_unit_size: 0,
        future_accounting,
        event_blob_certification_state,
        deny_list_sizes: extended_field::new(vec_map::empty(), ctx),
    }
}

/// Update epoch to next epoch, and update the committee, price and capacity.
///
/// Called by the epoch change function that connects `Staking` and `System`.
/// Returns the mapping of node IDs from the old committee to the rewards they
/// received in the epoch.
///
/// Note: VecMap must contain values only for the nodes from the previous
/// committee, the `staking` part of the system relies on this assumption.
public(package) fun advance_epoch(
    self: &mut SystemStateInnerV1,
    new_committee: BlsCommittee,
    new_epoch_params: &EpochParams,
): VecMap<ID, Balance<WAL>> {
    // Check new committee is valid, the existence of a committee for the next
    // epoch is proof that the time has come to move epochs.
    let old_epoch = self.epoch();
    let new_epoch = old_epoch + 1;
    let old_committee = self.committee;

    assert!(new_committee.epoch() == new_epoch, EIncorrectCommittee);
    self.committee = new_committee;

    // Update the system object.
    self.total_capacity_size = new_epoch_params.capacity().max(self.used_capacity_size);
    self.storage_price_per_unit_size = new_epoch_params.storage_price();
    self.write_price_per_unit_size = new_epoch_params.write_price();

    let accounts_old_epoch = self.future_accounting.ring_pop_expand();

    // Make sure that we have the correct epoch
    assert!(accounts_old_epoch.epoch() == old_epoch, EInvalidAccountingEpoch);

    // Stop tracking all event blobs
    self.event_blob_certification_state.reset();

    // Update storage based on the accounts data.
    self.used_capacity_size = self.used_capacity_size - accounts_old_epoch.storage_to_reclaim();

    // === Rewards distribution ===

    let mut total_rewards = accounts_old_epoch.unwrap_balance();

    // to perform the calculation of rewards, we account for the deny list sizes
    // in comparison to the used capacity size, and the weights of the nodes in
    // the committee.
    //
    // specific reward for a node is calculated as:
    // reward = (weight * (used_capacity_size - deny_list_size)) / total_stored * total_rewards
    // where `total_stored` is the sum of all nodes' values.
    //
    // leftover rewards are added to the next epoch's accounting to avoid rounding errors.

    let deny_list_sizes = self.deny_list_sizes.borrow();
    let (node_ids, weights) = old_committee.to_vec_map().into_keys_values();
    let mut stored_vec = vector[];
    let mut total_stored = 0;

    node_ids.zip_do!(weights, |node_id, weight| {
        let deny_list_size = deny_list_sizes.try_get(&node_id).destroy_or!(0);
        let stored = (weight as u128) * ((self.used_capacity_size - deny_list_size) as u128);

        total_stored = total_stored + stored;
        stored_vec.push_back(stored);
    });

    let total_stored = total_stored.max(1); // avoid division by zero
    let total_rewards_value = total_rewards.value() as u128;
    let reward_values = stored_vec.map!(|stored| {
        total_rewards.split((stored * total_rewards_value / total_stored) as u64)
    });

    // add the leftover rewards to the next epoch
    self.future_accounting.ring_lookup_mut(0).rewards_balance().join(total_rewards);
    vec_map::from_keys_values(node_ids, reward_values)
}

/// Allow buying a storage reservation for a given period of epochs.
public(package) fun reserve_space(
    self: &mut SystemStateInnerV1,
    storage_amount: u64,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Storage {
    // Check the period is within the allowed range.
    assert!(epochs_ahead > 0, EInvalidEpochsAhead);
    assert!(epochs_ahead <= self.future_accounting.max_epochs_ahead(), EInvalidEpochsAhead);

    // Check capacity is available.
    assert!(self.used_capacity_size + storage_amount <= self.total_capacity_size, EStorageExceeded);

    // Pay rewards for each future epoch into the future accounting.
    self.process_storage_payments(storage_amount, 0, epochs_ahead, payment);

    self.reserve_space_without_payment(storage_amount, epochs_ahead, ctx)
}

/// Allow buying a storage reservation for a given period of epochs without
/// payment.
/// Only to be used for event blobs.
fun reserve_space_without_payment(
    self: &mut SystemStateInnerV1,
    storage_amount: u64,
    epochs_ahead: u32,
    ctx: &mut TxContext,
): Storage {
    // Check the period is within the allowed range.
    assert!(epochs_ahead > 0, EInvalidEpochsAhead);
    assert!(epochs_ahead <= self.future_accounting.max_epochs_ahead(), EInvalidEpochsAhead);

    // Update the storage accounting.
    self.used_capacity_size = self.used_capacity_size + storage_amount;

    // Account the space to reclaim in the future.
    self
        .future_accounting
        .ring_lookup_mut(epochs_ahead - 1)
        .increase_storage_to_reclaim(storage_amount);

    let self_epoch = self.epoch();

    storage_resource::create_storage(
        self_epoch,
        self_epoch + epochs_ahead,
        storage_amount,
        ctx,
    )
}

/// Processes invalid blob id message. Checks the certificate in the current
/// committee and ensures
/// that the epoch is correct before emitting an event.
public(package) fun invalidate_blob_id(
    self: &SystemStateInnerV1,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
): u256 {
    let certified_message = self
        .committee
        .verify_one_correct_node_in_epoch(
            signature,
            members_bitmap,
            message,
        );

    let epoch = certified_message.cert_epoch();
    let invalid_blob_message = certified_message.invalid_blob_id_message();
    let blob_id = invalid_blob_message.invalid_blob_id();
    // Assert the epoch is correct.
    assert!(epoch == self.epoch(), EInvalidIdEpoch);

    // Emit the event about a blob id being invalid here.
    events::emit_invalid_blob_id(epoch, blob_id);
    blob_id
}

/// Registers a new blob in the system.
/// `size` is the size of the unencoded blob. The reserved space in `storage`
/// must be at
/// least the size of the encoded blob.
public(package) fun register_blob(
    self: &mut SystemStateInnerV1,
    storage: Storage,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    deletable: bool,
    write_payment_coin: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Blob {
    let blob = blob::new(
        storage,
        blob_id,
        root_hash,
        size,
        encoding_type,
        deletable,
        self.epoch(),
        self.n_shards(),
        ctx,
    );
    let write_price = self.write_price(blob.encoded_size(self.n_shards()));
    let payment = write_payment_coin.balance_mut().split(write_price);
    let accounts = self.future_accounting.ring_lookup_mut(0).rewards_balance().join(payment);
    blob
}

/// Certify that a blob will be available in the storage system until the end
/// epoch of the
/// storage associated with it.
public(package) fun certify_blob(
    self: &SystemStateInnerV1,
    blob: &mut Blob,
    signature: vector<u8>,
    signers_bitmap: vector<u8>,
    message: vector<u8>,
) {
    let certified_msg = self
        .committee()
        .verify_quorum_in_epoch(
            signature,
            signers_bitmap,
            message,
        );
    assert!(certified_msg.cert_epoch() == self.epoch(), EInvalidIdEpoch);

    let certified_blob_msg = certified_msg.certify_blob_message();
    blob.certify_with_certified_msg(self.epoch(), certified_blob_msg);
}

/// Deletes a deletable blob and returns the contained storage resource.
public(package) fun delete_blob(self: &SystemStateInnerV1, blob: Blob): Storage {
    blob.delete(self.epoch())
}

/// Extend the period of validity of a blob with a new storage resource.
/// The new storage resource must be the same size as the storage resource
/// used in the blob, and have a longer period of validity.
public(package) fun extend_blob_with_resource(
    self: &SystemStateInnerV1,
    blob: &mut Blob,
    extension: Storage,
) {
    blob.extend_with_resource(extension, self.epoch());
}

/// Extend the period of validity of a blob by extending its contained storage
/// resource.
public(package) fun extend_blob(
    self: &mut SystemStateInnerV1,
    blob: &mut Blob,
    epochs_ahead: u32,
    payment: &mut Coin<WAL>,
) {
    // Check that the blob is certified and not expired.
    blob.assert_certified_not_expired(self.epoch());

    let start_offset = blob.storage().end_epoch() - self.epoch();
    let end_offset = start_offset + epochs_ahead;

    // Check the period is within the allowed range.
    assert!(epochs_ahead > 0, EInvalidEpochsAhead);
    assert!(end_offset <= self.future_accounting.max_epochs_ahead(), EInvalidEpochsAhead);

    // Pay rewards for each future epoch into the future accounting.
    let storage_size = blob.storage().storage_size();
    self.process_storage_payments(
        storage_size,
        start_offset,
        end_offset,
        payment,
    );

    // Account the space to reclaim in the future.

    // First account for the space not being freed in the original end epoch.
    self
        .future_accounting
        .ring_lookup_mut(start_offset - 1)
        .decrease_storage_to_reclaim(storage_size);

    // Then account for the space being freed in the new end epoch.
    self
        .future_accounting
        .ring_lookup_mut(end_offset - 1)
        .increase_storage_to_reclaim(storage_size);

    blob.storage_mut().extend_end_epoch(epochs_ahead);

    blob.emit_certified(true);
}

fun process_storage_payments(
    self: &mut SystemStateInnerV1,
    storage_size: u64,
    start_offset: u32,
    end_offset: u32,
    payment: &mut Coin<WAL>,
) {
    let storage_units = storage_units_from_size!(storage_size);
    let period_payment_due = self.storage_price_per_unit_size * storage_units;
    let coin_balance = payment.balance_mut();

    start_offset.range_do!(end_offset, |i| {
        // Distribute rewards
        // Note this will abort if the balance is not enough.
        let epoch_payment = coin_balance.split(period_payment_due);
        self.future_accounting.ring_lookup_mut(i).rewards_balance().join(epoch_payment);
    });
}

public(package) fun certify_event_blob(
    self: &mut SystemStateInnerV1,
    cap: &mut StorageNodeCap,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    ending_checkpoint_sequence_num: u64,
    epoch: u32,
    ctx: &mut TxContext,
) {
    assert!(self.committee().contains(&cap.node_id()), ENotCommitteeMember);
    assert!(epoch == self.epoch(), EInvalidIdEpoch);

    cap.last_event_blob_attestation().do!(|attestation| {
        assert!(
            attestation.last_attested_event_blob_epoch() < self.epoch() ||
                ending_checkpoint_sequence_num >
                    attestation.last_attested_event_blob_checkpoint_seq_num(),
            ERepeatedAttestation,
        );
        let latest_certified_checkpoint_seq_num = self
            .event_blob_certification_state
            .get_latest_certified_checkpoint_sequence_number();

        if (latest_certified_checkpoint_seq_num.is_some()) {
            let latest_certified_cp_seq_num = latest_certified_checkpoint_seq_num.destroy_some();
            assert!(
                attestation.last_attested_event_blob_epoch() < self.epoch() ||
                    attestation.last_attested_event_blob_checkpoint_seq_num()
                        <= latest_certified_cp_seq_num,
                EIncorrectAttestation,
            );
        } else {
            assert!(
                attestation.last_attested_event_blob_epoch() < self.epoch(),
                EIncorrectAttestation,
            );
        }
    });

    let attestation = new_attestation(ending_checkpoint_sequence_num, epoch);
    cap.set_last_event_blob_attestation(attestation);

    let blob_certified = self
        .event_blob_certification_state
        .is_blob_already_certified(ending_checkpoint_sequence_num);

    if (blob_certified) {
        return
    };

    self.event_blob_certification_state.start_tracking_blob(blob_id);
    let weight = self.committee().get_member_weight(&cap.node_id());
    let agg_weight = self.event_blob_certification_state.update_aggregate_weight(blob_id, weight);
    let certified = self.committee().is_quorum(agg_weight);
    if (!certified) {
        return
    };

    let num_shards = self.n_shards();
    let epochs_ahead = self.future_accounting.max_epochs_ahead();
    let storage = self.reserve_space_without_payment(
        encoded_blob_length(size, encoding_type, num_shards),
        epochs_ahead,
        ctx,
    );
    let mut blob = blob::new(
        storage,
        blob_id,
        root_hash,
        size,
        encoding_type,
        false,
        self.epoch(),
        self.n_shards(),
        ctx,
    );
    let certified_blob_msg = messages::certified_event_blob_message(blob_id);
    blob.certify_with_certified_msg(self.epoch(), certified_blob_msg);
    self
        .event_blob_certification_state
        .update_latest_certified_event_blob(
            ending_checkpoint_sequence_num,
            blob_id,
        );
    // Stop tracking all event blobs
    // It is safe to reset the event blob certification state here for several reasons:
    // This reset happens after a blob has been certified, so all previous attestations
    // are no longer relevant because:
    //  a. Each node is allowed one outstanding attestation
    //  b. Majority of the nodes attested to the same blob ID at checkpoint X (which got certified)
    //  c. For previous certified blob (before checkpoint X) at checkpoint X' where X' < X:
    //     - Any attestations to blobs at checkpoint Y where X' < Y < X are invalid and can be
    //       ignored
    //  d. For next certified blob (after checkpoint X) at checkpoint X'':
    //     - Attestations at checkpoint Z (Z > X) where Z == X'' are impossible because every event
    //       blob requires a pointer to previous certified blob, and we just certified blob at
    //       checkpoint X
    self.event_blob_certification_state.reset();
    blob.burn();
}

/// Adds rewards to the system for the specified number of epochs ahead.
/// The rewards are split equally across the future accounting ring buffer up to the
/// specified epoch.
public(package) fun add_subsidy(
    self: &mut SystemStateInnerV1,
    subsidy: Coin<WAL>,
    epochs_ahead: u32,
) {
    // Check the period is within the allowed range.
    assert!(epochs_ahead > 0, EInvalidEpochsAhead);
    assert!(epochs_ahead <= self.future_accounting.max_epochs_ahead(), EInvalidEpochsAhead);

    let mut subsidy_balance = subsidy.into_balance();
    let reward_per_epoch = subsidy_balance.value() / (epochs_ahead as u64);
    let leftover_rewards = subsidy_balance.value() % (epochs_ahead as u64);

    epochs_ahead.do!(|i| {
        self
            .future_accounting
            .ring_lookup_mut(i)
            .rewards_balance()
            .join(subsidy_balance.split(reward_per_epoch));
    });

    // Add leftover rewards to the first epoch's accounting.
    self.future_accounting.ring_lookup_mut(0).rewards_balance().join(subsidy_balance);
}

// === Accessors ===

/// Get epoch. Uses the committee to get the epoch.
public(package) fun epoch(self: &SystemStateInnerV1): u32 {
    self.committee.epoch()
}

/// Accessor for total capacity size.
public(package) fun total_capacity_size(self: &SystemStateInnerV1): u64 {
    self.total_capacity_size
}

/// Accessor for used capacity size.
public(package) fun used_capacity_size(self: &SystemStateInnerV1): u64 {
    self.used_capacity_size
}

/// An accessor for the current committee.
public(package) fun committee(self: &SystemStateInnerV1): &BlsCommittee {
    &self.committee
}

#[test_only]
public(package) fun committee_mut(self: &mut SystemStateInnerV1): &mut BlsCommittee {
    &mut self.committee
}

public(package) fun n_shards(self: &SystemStateInnerV1): u16 {
    self.committee.n_shards()
}

public(package) fun write_price(self: &SystemStateInnerV1, write_size: u64): u64 {
    let storage_units = storage_units_from_size!(write_size);
    self.write_price_per_unit_size * storage_units
}

#[test_only]
public(package) fun deny_list_sizes(self: &SystemStateInnerV1): &VecMap<ID, u64> {
    self.deny_list_sizes.borrow()
}

#[test_only]
public(package) fun deny_list_sizes_mut(self: &mut SystemStateInnerV1): &mut VecMap<ID, u64> {
    self.deny_list_sizes.borrow_mut()
}

macro fun storage_units_from_size($size: u64): u64 {
    let size = $size;
    size.divide_and_round_up(BYTES_PER_UNIT_SIZE)
}

// === DenyList ===

/// Announce a deny list update for a storage node.
public(package) fun register_deny_list_update(
    self: &SystemStateInnerV1,
    cap: &StorageNodeCap,
    deny_list_root: u256,
    deny_list_sequence: u64,
) {
    assert!(self.committee().contains(&cap.node_id()), ENotCommitteeMember);
    assert!(deny_list_sequence > cap.deny_list_sequence(), EIncorrectDenyListSequence);

    events::emit_register_deny_list_update(
        self.epoch(),
        deny_list_root,
        deny_list_sequence,
        cap.node_id(),
    );
}

/// Perform the update of the deny list; register updated root and sequence in
/// the `StorageNodeCap`.
public(package) fun update_deny_list(
    self: &mut SystemStateInnerV1,
    cap: &mut StorageNodeCap,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
) {
    assert!(self.committee().contains(&cap.node_id()), ENotCommitteeMember);

    let certified_message = self
        .committee
        .verify_quorum_in_epoch(signature, members_bitmap, message);

    let epoch = certified_message.cert_epoch();
    let message = certified_message.deny_list_update_message();
    let node_id = message.storage_node_id();
    let size = message.size();

    assert!(epoch == self.epoch(), EInvalidIdEpoch);
    assert!(node_id == cap.node_id(), EIncorrectDenyListNode);
    assert!(cap.deny_list_sequence() < message.sequence_number(), EIncorrectDenyListSequence);

    let deny_list_root = message.root();
    let sequence_number = message.sequence_number();

    // update deny_list properties in the cap
    cap.set_deny_list_properties(deny_list_root, sequence_number, size);

    // then register the update in the system storage
    let sizes = self.deny_list_sizes.borrow_mut();
    if (sizes.contains(&node_id)) {
        *&mut sizes[&node_id] = message.size();
    } else {
        sizes.insert(node_id, message.size());
    };

    events::emit_deny_list_update(
        self.epoch(),
        deny_list_root,
        sequence_number,
        cap.node_id(),
    );
}

/// Certify that a blob is on the deny list for at least one honest node. Emit
/// an event to mark it for deletion.
public(package) fun delete_deny_listed_blob(
    self: &SystemStateInnerV1,
    signature: vector<u8>,
    members_bitmap: vector<u8>,
    message: vector<u8>,
) {
    let certified_message = self
        .committee
        .verify_one_correct_node_in_epoch(signature, members_bitmap, message);

    let epoch = certified_message.cert_epoch();
    let message = certified_message.deny_list_blob_deleted_message();

    assert!(epoch == self.epoch(), EInvalidIdEpoch);

    events::emit_deny_listed_blob_deleted(epoch, message.blob_id());
}

// === Testing ===

#[test_only]
use walrus::test_utils;

#[test_only]
public(package) fun new_for_testing(): SystemStateInnerV1 {
    let committee = test_utils::new_bls_committee_for_testing(0);
    let ctx = &mut tx_context::dummy();
    SystemStateInnerV1 {
        committee,
        total_capacity_size: 1_000_000_000,
        used_capacity_size: 0,
        storage_price_per_unit_size: 5,
        write_price_per_unit_size: 1,
        future_accounting: storage_accounting::ring_new(104),
        event_blob_certification_state: event_blob::create_with_empty_state(),
        deny_list_sizes: extended_field::new(vec_map::empty(), ctx),
    }
}

#[test_only]
public(package) fun new_for_testing_with_multiple_members(ctx: &mut TxContext): SystemStateInnerV1 {
    let committee = test_utils::new_bls_committee_with_multiple_members_for_testing(0, ctx);
    SystemStateInnerV1 {
        committee,
        total_capacity_size: 1_000_000_000,
        used_capacity_size: 0,
        storage_price_per_unit_size: 5,
        write_price_per_unit_size: 1,
        future_accounting: storage_accounting::ring_new(104),
        event_blob_certification_state: event_blob::create_with_empty_state(),
        deny_list_sizes: extended_field::new(vec_map::empty(), ctx),
    }
}

#[test_only]
public(package) fun event_blob_certification_state(
    system: &SystemStateInnerV1,
): &EventBlobCertificationState {
    &system.event_blob_certification_state
}

#[test_only]
public(package) fun future_accounting_mut(
    self: &mut SystemStateInnerV1,
): &mut FutureAccountingRingBuffer {
    &mut self.future_accounting
}
