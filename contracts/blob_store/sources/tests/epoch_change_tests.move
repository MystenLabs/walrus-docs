// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module blob_store::epoch_change_tests {
    use sui::coin;
    use sui::balance;

    use blob_store::committee;
    use blob_store::system;
    use blob_store::storage_accounting as sa;
    use blob_store::storage_resource as sr;

    // Keep in sync with the same constant in `blob_store::system`
    const BYTES_PER_UNIT_SIZE: u64 = 1_024;

    public struct TESTWAL has store, drop {}

    // ------------- TESTS --------------------

    #[test]
    public fun test_use_system(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(
            committee,
            1_000 * BYTES_PER_UNIT_SIZE,
            2,
            &mut ctx,
        );

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            10 * BYTES_PER_UNIT_SIZE,
            3,
            fake_coin,
            &mut ctx,
        );
        sr::destroy(storage);

        // Check things about the system
        assert!(system::epoch(&system) == 0, 0);

        // The value of the coin should be 100 - 60
        assert!(coin::value(&fake_coin) == 40, 0);

        // Space is reduced by 10
        assert!(system::used_capacity_size(&system) == 10 * BYTES_PER_UNIT_SIZE, 0);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let mut epoch_accounts = system::next_epoch(
            &mut system,
            committee,
            1_000 * BYTES_PER_UNIT_SIZE,
            3,
        );
        assert!(balance::value(sa::rewards_to_distribute(&mut epoch_accounts)) == 20, 0);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            5 * BYTES_PER_UNIT_SIZE,
            1,
            fake_coin,
            &mut ctx,
        );
        sr::destroy(storage);
        // The value of the coin should be 40 - 3 x 5
        assert!(coin::value(&fake_coin) == 25, 0);
        sa::burn_for_testing(epoch_accounts);

        assert!(system::used_capacity_size(&system) == 15 * BYTES_PER_UNIT_SIZE, 0);

        // Advance epoch -- to epoch 2
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(2);
        let mut epoch_accounts = system::next_epoch(
            &mut system,
            committee,
            1_000 * BYTES_PER_UNIT_SIZE,
            3,
        );
        assert!(balance::value(sa::rewards_to_distribute(&mut epoch_accounts)) == 35, 0);
        sa::burn_for_testing(epoch_accounts);

        assert!(system::used_capacity_size(&system) == 10 * BYTES_PER_UNIT_SIZE, 0);

        // Advance epoch -- to epoch 3
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(3);
        let mut epoch_accounts = system::next_epoch(
            &mut system,
            committee,
            1_000 * BYTES_PER_UNIT_SIZE,
            3,
        );
        assert!(balance::value(sa::rewards_to_distribute(&mut epoch_accounts)) == 20, 0);
        sa::burn_for_testing(epoch_accounts);

        // check all space is reclaimed
        assert!(system::used_capacity_size(&system) == 0, 0);

        // Advance epoch -- to epoch 4
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(4);
        let mut epoch_accounts = system::next_epoch(
            &mut system,
            committee,
            1_000 * BYTES_PER_UNIT_SIZE,
            3,
        );
        assert!(balance::value(sa::rewards_to_distribute(&mut epoch_accounts)) == 0, 0);
        sa::burn_for_testing(epoch_accounts);

        // check all space is reclaimed
        assert!(system::used_capacity_size(&system) == 0, 0);

        coin::burn_for_testing(fake_coin);

        system
    }

    #[test, expected_failure(abort_code=system::ESyncEpochChange)]
    public fun test_move_sync_err_system(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000, 2, &mut ctx);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts1 = system::next_epoch(&mut system, committee, 1000, 3);

        // Advance epoch -- to epoch 2
        let committee = committee::committee_for_testing(2);
        // FAIL HERE BECAUSE WE ARE IN SYNC MODE NOT DONE!
        let epoch_accounts2 = system::next_epoch(&mut system, committee, 1000, 3);

        coin::burn_for_testing(fake_coin);
        sa::burn_for_testing(epoch_accounts1);
        sa::burn_for_testing(epoch_accounts2);

        system
    }

    #[test, expected_failure(abort_code=system::EStorageExceeded)]
    public fun test_fail_capacity_system(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000, 2, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(&mut system, 10, 3, fake_coin, &mut ctx);
        sr::destroy(storage);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(&mut system, 995, 1, fake_coin, &mut ctx);
        sr::destroy(storage);
        // The value of the coin should be 40 - 3 x 5
        sa::burn_for_testing(epoch_accounts);

        coin::burn_for_testing(fake_coin);

        system
    }

    #[test]
    public fun test_sync_done_happy(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000, 2, &mut ctx);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts1 = system::next_epoch(&mut system, committee, 1000, 3);

        // Construct a test sync_done test message
        let test_sync_done_msg = system::make_sync_done_message_for_testing(1);

        // Feed it into the logic to advance state
        system::sync_done_for_epoch(&mut system, test_sync_done_msg);

        // Advance epoch -- to epoch 2
        let committee = committee::committee_for_testing(2);
        // We are in done state and this works
        let epoch_accounts2 = system::next_epoch(&mut system, committee, 1000, 3);

        coin::burn_for_testing(fake_coin);
        sa::burn_for_testing(epoch_accounts1);
        sa::burn_for_testing(epoch_accounts2);

        system
    }

    #[test, expected_failure(abort_code=system::ESyncEpochChange)]
    public fun test_sync_done_unhappy(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000, 2, &mut ctx);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts1 = system::next_epoch(&mut system, committee, 1000, 3);

        // Construct a test sync_done test message -- INCORRECT EPOCH
        let test_sync_done_msg = system::make_sync_done_message_for_testing(4);

        // Feed it into the logic to advance state
        system::sync_done_for_epoch(&mut system, test_sync_done_msg);

        coin::burn_for_testing(fake_coin);
        sa::burn_for_testing(epoch_accounts1);

        system
    }

    #[test, expected_failure(abort_code=system::ESyncEpochChange)]
    public fun test_twice_unhappy(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000, 2, &mut ctx);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts1 = system::next_epoch(&mut system, committee, 1000, 3);

        // Construct a test sync_done test message
        // Feed it into the logic to advance state
        let test_sync_done_msg = system::make_sync_done_message_for_testing(1);
        system::sync_done_for_epoch(&mut system, test_sync_done_msg);

        // SECOND TIME -- FAILS
        let test_sync_done_msg = system::make_sync_done_message_for_testing(1);
        system::sync_done_for_epoch(&mut system, test_sync_done_msg);

        coin::burn_for_testing(fake_coin);
        sa::burn_for_testing(epoch_accounts1);

        system
    }
}
