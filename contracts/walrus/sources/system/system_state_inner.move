// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_variable, unused_mut_parameter, unused_field)]
module walrus::system_state_inner;

use sui::{balance::Balance, coin::Coin};
use wal::wal::WAL;
use walrus::{
    blob::{Self, Blob},
    bls_aggregate::{Self, BlsCommittee},
    encoding::encoded_blob_length,
    epoch_parameters::EpochParams,
    event_blob::{Self, EventBlobCertificationState, new_attestation},
    events::emit_invalid_blob_id,
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

// Errors
// Keep errors in `walrus-sui/types/move_errors.rs` up to date with changes here.
const EInvalidMaxEpochsAhead: u64 = 0;
const EStorageExceeded: u64 = 1;
const EInvalidEpochsAhead: u64 = 2;
const EInvalidIdEpoch: u64 = 3;
const EIncorrectCommittee: u64 = 4;
const EInvalidAccountingEpoch: u64 = 5;
const EIncorrectAttestation: u64 = 6;
const ERepeatedAttestation: u64 = 7;
const ENotCommitteeMember: u64 = 8;

/// The inner object that is not present in signatures and can be versioned.
#[allow(unused_field)]
public struct SystemStateInnerV1 has key, store {
    id: UID,
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
}

/// Creates an empty system state with a capacity of zero and an empty
/// committee.
public(package) fun create_empty(max_epochs_ahead: u32, ctx: &mut TxContext): SystemStateInnerV1 {
    let committee = bls_aggregate::new_bls_committee(0, vector[]);
    assert!(max_epochs_ahead <= MAX_MAX_EPOCHS_AHEAD, EInvalidMaxEpochsAhead);
    let future_accounting = storage_accounting::ring_new(max_epochs_ahead);
    let event_blob_certification_state = event_blob::create_with_empty_state(
        ctx,
    );
    let id = object::new(ctx);
    SystemStateInnerV1 {
        id,
        committee,
        total_capacity_size: 0,
        used_capacity_size: 0,
        storage_price_per_unit_size: 0,
        write_price_per_unit_size: 0,
        future_accounting,
        event_blob_certification_state,
    }
}

/// Update epoch to next epoch, and update the committee, price and capacity.
///
/// Called by the epoch change function that connects `Staking` and `System`.
/// Returns
/// the balance of the rewards from the previous epoch.
public(package) fun advance_epoch(
    self: &mut SystemStateInnerV1,
    new_committee: BlsCommittee,
    new_epoch_params: EpochParams,
): Balance<WAL> {
    // Check new committee is valid, the existence of a committee for the next
    // epoch
    // is proof that the time has come to move epochs.
    let old_epoch = self.epoch();
    let new_epoch = old_epoch + 1;

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
    accounts_old_epoch.unwrap_balance()
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
    let final_account = self.future_accounting.ring_lookup_mut(epochs_ahead - 1);
    final_account.increase_storage_to_reclaim(storage_amount);

    let self_epoch = epoch(self);

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
    members: vector<u16>,
    message: vector<u8>,
): u256 {
    let certified_message = self
        .committee
        .verify_quorum_in_epoch(
            signature,
            members,
            message,
        );

    let invalid_blob_message = certified_message.invalid_blob_id_message();
    let blob_id = invalid_blob_message.invalid_blob_id();
    // Assert the epoch is correct.
    let epoch = invalid_blob_message.certified_invalid_epoch();
    assert!(epoch == self.epoch(), EInvalidIdEpoch);

    // Emit the event about a blob id being invalid here.
    emit_invalid_blob_id(
        epoch,
        blob_id,
    );
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
    let payment = write_payment_coin.split(write_price, ctx).into_balance();
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
    signers: vector<u16>,
    message: vector<u8>,
) {
    let certified_msg = self
        .committee()
        .verify_quorum_in_epoch(
            signature,
            signers,
            message,
        );
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
    let storage_units = storage_units_from_size(storage_size);
    let period_payment_due = self.storage_price_per_unit_size * storage_units;
    let coin_balance = payment.balance_mut();

    start_offset.range_do!(end_offset, |i| {
        let accounts = self.future_accounting.ring_lookup_mut(i);

        // Distribute rewards
        let rewards_balance = accounts.rewards_balance();
        // Note this will abort if the balance is not enough.
        let epoch_payment = coin_balance.split(period_payment_due);
        rewards_balance.join(epoch_payment);
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

    let cap_attestion = cap.last_event_blob_attestation();
    if (cap_attestion.is_some()) {
        let attestation = cap_attestion.destroy_some();
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
            let certified_checkpoint_seq_num = latest_certified_checkpoint_seq_num.destroy_some();
            assert!(
                attestation.last_attested_event_blob_epoch() < self.epoch() ||
                    attestation.last_attested_event_blob_checkpoint_seq_num()
                        <= certified_checkpoint_seq_num,
                EIncorrectAttestation,
            );
        } else {
            assert!(
                attestation.last_attested_event_blob_epoch() < self.epoch(),
                EIncorrectAttestation,
            );
        }
    };

    let attestation = new_attestation(ending_checkpoint_sequence_num, epoch);
    cap.set_last_event_blob_attestation(attestation);

    let blob_certified = self
        .event_blob_certification_state
        .is_blob_already_certified(
            ending_checkpoint_sequence_num,
        );
    if (blob_certified) {
        return
    };

    self.event_blob_certification_state.start_tracking_blob(blob_id);
    let weight = self.committee().get_member_weight(&cap.node_id());
    let agg_weight = self.event_blob_certification_state.update_aggregate_weight(blob_id, weight);
    let certified = self.committee().verify_quorum(agg_weight);
    if (!certified) {
        return
    };

    let num_shards = self.n_shards();
    let epochs_ahead = self.future_accounting.max_epochs_ahead();
    let storage = self.reserve_space_without_payment(
        encoded_blob_length(
            size,
            encoding_type,
            num_shards,
        ),
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
    let certified_blob_msg = messages::certified_event_blob_message(
        self.epoch(),
        blob_id,
    );
    blob.certify_with_certified_msg(self.epoch(), certified_blob_msg);
    self
        .event_blob_certification_state
        .update_latest_certified_event_blob(
            ending_checkpoint_sequence_num,
            blob_id,
        );
    self.event_blob_certification_state.stop_tracking_blob(blob_id);
    blob.burn();
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
    let storage_units = storage_units_from_size(write_size);
    self.write_price_per_unit_size * storage_units
}

fun storage_units_from_size(size: u64): u64 {
    (size + BYTES_PER_UNIT_SIZE - 1) / BYTES_PER_UNIT_SIZE
}

// === Testing ===

#[test_only]
use walrus::{test_utils};

#[test_only]
public(package) fun new_for_testing(): SystemStateInnerV1 {
    let committee = test_utils::new_bls_committee_for_testing(0);
    let ctx = &mut tx_context::dummy();
    let id = object::new(ctx);
    SystemStateInnerV1 {
        id,
        committee,
        total_capacity_size: 1_000_000_000,
        used_capacity_size: 0,
        storage_price_per_unit_size: 5,
        write_price_per_unit_size: 1,
        future_accounting: storage_accounting::ring_new(104),
        event_blob_certification_state: event_blob::create_with_empty_state(
            ctx,
        ),
    }
}

#[test_only]
public(package) fun new_for_testing_with_multiple_members(ctx: &mut TxContext): SystemStateInnerV1 {
    let committee = test_utils::new_bls_committee_with_multiple_members_for_testing(
        0,
        ctx,
    );

    let id = object::new(ctx);
    SystemStateInnerV1 {
        id,
        committee,
        total_capacity_size: 1_000_000_000,
        used_capacity_size: 0,
        storage_price_per_unit_size: 5,
        write_price_per_unit_size: 1,
        future_accounting: storage_accounting::ring_new(104),
        event_blob_certification_state: event_blob::create_with_empty_state(
            ctx,
        ),
    }
}

#[test_only]
public(package) fun get_event_blob_certification_state(
    system: &SystemStateInnerV1,
): &EventBlobCertificationState {
    &system.event_blob_certification_state
}
