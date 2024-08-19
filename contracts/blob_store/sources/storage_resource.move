// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::storage_resource {
    const EInvalidEpoch: u64 = 0;
    const EIncompatibleEpochs: u64 = 1;
    const EIncompatibleAmount: u64 = 2;

    /// Reservation for storage for a given period, which is inclusive start, exclusive end.
    public struct Storage has key, store {
        id: UID,
        start_epoch: u64,
        end_epoch: u64,
        storage_size: u64,
    }

    public fun start_epoch(self: &Storage): u64 {
        self.start_epoch
    }

    public fun end_epoch(self: &Storage): u64 {
        self.end_epoch
    }

    public fun storage_size(self: &Storage): u64 {
        self.storage_size
    }

    /// Constructor for [Storage] objects.
    /// Necessary to allow `blob_store::system` to create storage objects.
    /// Cannot be called outside of the current module and [blob_store::system].
    public(package) fun create_storage(
        start_epoch: u64,
        end_epoch: u64,
        storage_size: u64,
        ctx: &mut TxContext,
    ): Storage {
        Storage { id: object::new(ctx), start_epoch, end_epoch, storage_size }
    }

    /// Split the storage object into two based on `split_epoch`
    ///
    /// `storage` is modified to cover the period from `start_epoch` to `split_epoch`
    /// and a new storage object covering `split_epoch` to `end_epoch` is returned.
    public fun split_by_epoch(
        storage: &mut Storage,
        split_epoch: u64,
        ctx: &mut TxContext,
    ): Storage {
        assert!(
            split_epoch >= storage.start_epoch && split_epoch <= storage.end_epoch,
            EInvalidEpoch,
        );
        let end_epoch = storage.end_epoch;
        storage.end_epoch = split_epoch;
        Storage {
            id: object::new(ctx),
            start_epoch: split_epoch,
            end_epoch,
            storage_size: storage.storage_size,
        }
    }

    /// Split the storage object into two based on `split_size`
    ///
    /// `storage` is modified to cover `split_size` and a new object covering
    /// `storage.storage_size - split_size` is created.
    public fun split_by_size(storage: &mut Storage, split_size: u64, ctx: &mut TxContext): Storage {
        let storage_size = storage.storage_size - split_size;
        storage.storage_size = split_size;
        Storage {
            id: object::new(ctx),
            start_epoch: storage.start_epoch,
            end_epoch: storage.end_epoch,
            storage_size,
        }
    }

    /// Fuse two storage objects that cover adjacent periods with the same storage size.
    public fun fuse_periods(first: &mut Storage, second: Storage) {
        let Storage {
            id,
            start_epoch: second_start,
            end_epoch: second_end,
            storage_size: second_size,
        } = second;
        id.delete();
        assert!(first.storage_size == second_size, EIncompatibleAmount);
        if (first.end_epoch == second_start) {
            first.end_epoch = second_end;
        } else {
            assert!(first.start_epoch == second_end, EIncompatibleEpochs);
            first.start_epoch = second_start;
        }
    }

    /// Fuse two storage objects that cover the same period
    public fun fuse_amount(first: &mut Storage, second: Storage) {
        let Storage {
            id,
            start_epoch: second_start,
            end_epoch: second_end,
            storage_size: second_size,
        } = second;
        id.delete();
        assert!(
            first.start_epoch == second_start && first.end_epoch == second_end,
            EIncompatibleEpochs,
        );
        first.storage_size = first.storage_size + second_size;
    }

    /// Fuse two storage objects that either cover the same period
    /// or adjacent periods with the same storage size.
    public fun fuse(first: &mut Storage, second: Storage) {
        if (first.start_epoch == second.start_epoch) {
            // Fuse by storage_size
            fuse_amount(first, second);
        } else {
            // Fuse by period
            fuse_periods(first, second);
        }
    }

    #[test_only]
    /// Constructor for [Storage] objects for tests
    public fun create_for_test(
        start_epoch: u64,
        end_epoch: u64,
        storage_size: u64,
        ctx: &mut TxContext,
    ): Storage {
        Storage { id: object::new(ctx), start_epoch, end_epoch, storage_size }
    }

    /// Destructor for [Storage] objects
    public fun destroy(storage: Storage) {
        let Storage {
            id,
            start_epoch: _,
            end_epoch: _,
            storage_size: _,
        } = storage;
        id.delete();
    }
}
