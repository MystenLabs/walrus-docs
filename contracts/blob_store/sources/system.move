// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::system {
    use sui::coin::Coin;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::bcs;

    use blob_store::committee::{Self, Committee};
    use blob_store::storage_accounting::{Self, FutureAccounting, FutureAccountingRingBuffer};
    use blob_store::storage_resource::{Self, Storage};
    use blob_store::blob_events::emit_invalid_blob_id;

    // Errors
    const EIncorrectCommittee: u64 = 0;
    const ESyncEpochChange: u64 = 1;
    const EInvalidPeriodsAhead: u64 = 2;
    const EStorageExceeded: u64 = 3;
    const EInvalidMsgType: u64 = 4;
    const EInvalidIdEpoch: u64 = 5;

    // Message types:
    const EPOCH_DONE_MSG_TYPE: u8 = 0;
    const INVALID_BLOB_ID_MSG_TYPE: u8 = 2;

    // Epoch status values
    #[allow(unused_const)]
    const EPOCH_STATUS_DONE: u8 = 0;
    #[allow(unused_const)]
    const EPOCH_STATUS_SYNC: u8 = 1;

    /// The maximum number of periods ahead we allow for storage reservations.
    /// This number is a placeholder, and assumes an epoch is a week,
    /// and therefore 2 x 52 weeks = 2 years.
    const MAX_PERIODS_AHEAD: u64 = 104;

    // Keep in sync with the same constant in `crates/walrus-sui/utils.rs`.
    const BYTES_PER_UNIT_SIZE: u64 = 1_024;

    // Event types

    /// Signals an epoch change, and entering the SYNC state for the new epoch.
    public struct EpochChangeSync has copy, drop {
        epoch: u64,
        total_capacity_size: u64,
        used_capacity_size: u64,
    }

    /// Signals that the epoch change is DONE now.
    public struct EpochChangeDone has copy, drop {
        epoch: u64,
    }

    // Object definitions

    #[allow(unused_field)]
    public struct System<phantom WAL> has key, store {
        id: UID,
        /// The current committee, with the current epoch.
        /// The option is always Some, but need it for swap.
        current_committee: Option<Committee>,
        /// When we first enter the current epoch we SYNC,
        /// and then we are DONE after a cert from a quorum.
        epoch_status: u8,
        // Some accounting
        total_capacity_size: u64,
        used_capacity_size: u64,
        /// The price per unit size of storage.
        price_per_unit_size: u64,
        /// Tables about the future and the past.
        past_committees: Table<u64, Committee>,
        future_accounting: FutureAccountingRingBuffer<WAL>,
    }

    /// Get epoch. Uses the committee to get the epoch.
    public fun epoch<WAL>(self: &System<WAL>): u64 {
        committee::epoch(option::borrow(&self.current_committee))
    }

    /// Accessor for total capacity size.
    public fun total_capacity_size<WAL>(self: &System<WAL>): u64 {
        self.total_capacity_size
    }

    /// Accessor for used capacity size.
    public fun used_capacity_size<WAL>(self: &System<WAL>): u64 {
        self.used_capacity_size
    }

    /// A privileged constructor for an initial system object,
    /// at epoch 0 with a given committee, and a given
    /// capacity and price. Here ownership of a committee at time 0
    /// acts as a capability to create a init a new system object.
    public fun new<WAL>(
        first_committee: Committee,
        capacity: u64,
        price: u64,
        ctx: &mut TxContext,
    ): System<WAL> {
        assert!(first_committee.epoch() == 0, EIncorrectCommittee);

        // We emit both sync and done events for the first epoch.
        event::emit(EpochChangeSync {
            epoch: 0,
            total_capacity_size: capacity,
            used_capacity_size: 0,
        });
        event::emit(EpochChangeDone { epoch: 0 });

        System {
            id: object::new(ctx),
            current_committee: option::some(first_committee),
            epoch_status: EPOCH_STATUS_DONE,
            total_capacity_size: capacity,
            used_capacity_size: 0,
            price_per_unit_size: price,
            past_committees: table::new(ctx),
            future_accounting: storage_accounting::ring_new(MAX_PERIODS_AHEAD),
        }
    }

    // We actually create a new objects that does not exist before, so all is good.
    #[allow(lint(share_owned))]
    /// Create and share a new system object, using ownership of a committee
    /// at epoch 0 as a capability to create a new system object.
    public fun share_new<WAL>(
        first_committee: Committee,
        capacity: u64,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let sys: System<WAL> = new(first_committee, capacity, price, ctx);
        transfer::share_object(sys);
    }

    /// An accessor for the current committee.
    public fun current_committee<WAL>(self: &System<WAL>): &Committee {
        self.current_committee.borrow()
    }

    public fun n_shards<WAL>(self: &System<WAL>): u16 {
        current_committee(self).n_shards()
    }

    /// Update epoch to next epoch, and also update the committee, price and capacity.
    public fun next_epoch<WAL>(
        self: &mut System<WAL>,
        new_committee: Committee,
        new_capacity: u64,
        new_price: u64,
    ): FutureAccounting<WAL> {
        // Must be in DONE state to move epochs. This is the way.
        assert!(self.epoch_status == EPOCH_STATUS_DONE, ESyncEpochChange);

        // Check new committee is valid, the existence of a committee for the next epoch
        // is proof that the time has come to move epochs.
        let old_epoch = epoch(self);
        let new_epoch = old_epoch + 1;
        assert!(new_committee.epoch() == new_epoch, EIncorrectCommittee);
        let old_committee = self.current_committee.swap(new_committee);

        // Add the old committee to the past_committees table.
        self.past_committees.add(old_epoch, old_committee);

        // Update the system object.
        self.total_capacity_size = new_capacity;
        self.price_per_unit_size = new_price;
        self.epoch_status = EPOCH_STATUS_SYNC;

        let mut accounts_old_epoch = self.future_accounting.ring_pop_expand();
        assert!(accounts_old_epoch.epoch() == old_epoch, ESyncEpochChange);

        // Update storage based on the accounts data.
        self.used_capacity_size = self.used_capacity_size - accounts_old_epoch.storage_to_reclaim();

        // Emit Sync event.
        event::emit(EpochChangeSync {
            epoch: new_epoch,
            total_capacity_size: self.total_capacity_size,
            used_capacity_size: self.used_capacity_size,
        });

        accounts_old_epoch
    }

    /// Allow buying a storage reservation for a given period of epochs.
    public fun reserve_space<WAL>(
        self: &mut System<WAL>,
        storage_amount: u64,
        periods_ahead: u64,
        mut payment: Coin<WAL>,
        ctx: &mut TxContext,
    ): (Storage, Coin<WAL>) {
        // Check the period is within the allowed range.
        assert!(periods_ahead > 0, EInvalidPeriodsAhead);
        assert!(periods_ahead <= MAX_PERIODS_AHEAD, EInvalidPeriodsAhead);

        // Check capacity is available.
        assert!(
            self.used_capacity_size + storage_amount <= self.total_capacity_size,
            EStorageExceeded,
        );

        // Pay rewards for each future epoch into the future accounting.
        let storage_units = (storage_amount + BYTES_PER_UNIT_SIZE - 1) / BYTES_PER_UNIT_SIZE;
        let period_payment_due = self.price_per_unit_size * storage_units;
        let coin_balance = payment.balance_mut();

        let mut i = 0;
        while (i < periods_ahead) {
            let accounts = self.future_accounting.ring_lookup_mut(i);

            // Distribute rewards
            let rewards_balance = accounts.rewards_to_distribute();
            // Note this will abort if the balance is not enough.
            let epoch_payment = coin_balance.split(period_payment_due);
            rewards_balance.join(epoch_payment);

            i = i + 1;
        };

        // Update the storage accounting.
        self.used_capacity_size = self.used_capacity_size + storage_amount;

        // Account the space to reclaim in the future.
        let final_account = self.future_accounting.ring_lookup_mut(periods_ahead - 1);
        final_account.increase_storage_to_reclaim(storage_amount);

        let self_epoch = epoch(self);
        (
            storage_resource::create_storage(
                self_epoch,
                self_epoch + periods_ahead,
                storage_amount,
                ctx,
            ),
            payment,
        )
    }

    #[test_only]
    public fun set_done_for_testing<WAL>(self: &mut System<WAL>) {
        self.epoch_status = EPOCH_STATUS_DONE;
    }

    // The logic to move epoch from SYNC to DONE.

    /// Define a message type for the SyncDone message.
    /// It may only be constructed when a valid certified message is
    /// passed in.
    public struct CertifiedSyncDone has drop {
        epoch: u64,
    }

    /// Construct the certified sync done message, note that constructing
    /// implies a certified message, that is already checked.
    public fun certify_sync_done_message(message: committee::CertifiedMessage): CertifiedSyncDone {
        // Assert type is correct
        assert!(message.intent_type() == EPOCH_DONE_MSG_TYPE, EInvalidMsgType);

        // The SyncDone message has no payload besides the epoch.
        // Which happens to already be parsed in the header of the
        // certified message.

        CertifiedSyncDone { epoch: message.cert_epoch() }
    }

    // make a test only certified message.
    #[test_only]
    public fun make_sync_done_message_for_testing(epoch: u64): CertifiedSyncDone {
        CertifiedSyncDone { epoch }
    }

    /// Use the certified message to advance the epoch status to DONE.
    public fun sync_done_for_epoch<WAL>(system: &mut System<WAL>, message: CertifiedSyncDone) {
        // Assert the epoch is correct.
        assert!(message.epoch == epoch(system), ESyncEpochChange);

        // Assert we are in the sync state.
        assert!(system.epoch_status == EPOCH_STATUS_SYNC, ESyncEpochChange);

        // Move to done state.
        system.epoch_status = EPOCH_STATUS_DONE;

        event::emit(EpochChangeDone { epoch: message.epoch });
    }

    // The logic to register an invalid Blob ID

    /// Define a message type for the InvalidBlobID message.
    /// It may only be constructed when a valid certified message is
    /// passed in.
    public struct CertifiedInvalidBlobID has drop {
        epoch: u64,
        blob_id: u256,
    }

    // read the blob id
    public fun invalid_blob_id(self: &CertifiedInvalidBlobID): u256 {
        self.blob_id
    }

    /// Construct the certified invalid Blob ID message, note that constructing
    /// implies a certified message, that is already checked.
    public fun invalid_blob_id_message(
        message: committee::CertifiedMessage,
    ): CertifiedInvalidBlobID {
        // Assert type is correct
        assert!(
            message.intent_type() == INVALID_BLOB_ID_MSG_TYPE,
            EInvalidMsgType,
        );

        // The InvalidBlobID message has no payload besides the blob_id.
        // The certified blob message contain a blob_id : u256
        let epoch = message.cert_epoch();
        let message_body = message.into_message();

        let mut bcs_body = bcs::new(message_body);
        let blob_id = bcs_body.peel_u256();

        // This output is provided as a service in case anything else needs to rely on
        // certified invalid blob ID information in the future. But out base design only
        // uses the event emitted here.
        CertifiedInvalidBlobID { epoch, blob_id }
    }

    /// Private System call to process invalid blob id message. This checks that the epoch
    /// in which the message was certified is correct, before emitting an event. Correct
    /// nodes will only certify invalid blob ids within their period of validity, and this
    /// endures we are not flooded with invalid events from past epochs.
    public(package) fun inner_declare_invalid_blob_id<WAL>(
        system: &System<WAL>,
        message: CertifiedInvalidBlobID,
    ) {
        // Assert the epoch is correct.
        let epoch = message.epoch;
        assert!(epoch == epoch(system), EInvalidIdEpoch);

        // Emit the event about a blob id being invalid here.
        emit_invalid_blob_id(
            epoch,
            message.blob_id,
        );
    }

    /// Public system call to process invalid blob id message. Will check the
    /// the certificate in the current committee and ensure that the epoch is
    /// correct as well.
    public fun invalidate_blob_id<WAL>(
        system: &System<WAL>,
        signature: vector<u8>,
        members: vector<u16>,
        message: vector<u8>,
    ): u256 {
        let committee = system.current_committee.borrow();

        let certified_message = committee.verify_quorum_in_epoch(
            signature,
            members,
            message,
        );

        let invalid_blob_message = invalid_blob_id_message(certified_message);
        let blob_id = invalid_blob_message.blob_id;
        inner_declare_invalid_blob_id(system, invalid_blob_message);
        blob_id
    }
}
