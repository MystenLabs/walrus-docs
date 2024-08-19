// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module blob_store::blob_tests {
    use sui::coin;
    use sui::bcs;

    use std::string;

    use blob_store::committee;
    use blob_store::system;
    use blob_store::storage_accounting as sa;
    use blob_store::blob;
    use blob_store::storage_node;

    use blob_store::storage_resource::{split_by_epoch, destroy};

    const RED_STUFF: u8 = 0;
    const NETWORK_PUBLIC_KEY: vector<u8> =
        x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677";

    public struct TESTWAL has store, drop {}

    #[test]
    public fun test_blob_register_happy_path(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test, expected_failure(abort_code=blob::EResourceSize)]
    public fun test_blob_insufficient_space(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs - TOO LITTLE SPACE
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            5000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test]
    public fun test_blob_certify_happy_path(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        let certify_message = blob::certified_blob_message_for_testing(0, blob_id);

        // Set certify
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        // Assert certified
        assert!(option::is_some(blob::certified_epoch(&blob1)), 0);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test]
    public fun test_blob_certify_single_function(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // Derive blob ID and root_hash from bytes
        let root_hash_vec = vector[
            1, 2, 3, 4, 5, 6, 7, 8,
            1, 2, 3, 4, 5, 6, 7, 8,
            1, 2, 3, 4, 5, 6, 7, 8,
            1, 2, 3, 4, 5, 6, 7, 8,
        ];

        let mut encode = bcs::new(root_hash_vec);
        let root_hash = bcs::peel_u256(&mut encode);

        let blob_id_vec = vector[
            119, 174, 25, 167, 128, 57, 96, 1,
            163, 56, 61, 132, 191, 35, 44, 18,
            231, 224, 79, 178, 85, 51, 69, 53,
            214, 95, 198, 203, 56, 221, 111, 83
        ];

        let mut encode = bcs::new(blob_id_vec);
        let blob_id = bcs::peel_u256(&mut encode);

        // Derive and check blob ID
        let blob_id_bis = blob::derive_blob_id(root_hash, RED_STUFF, 10000);
        assert!(blob_id == blob_id_bis, 0);

        // BCS confirmation message for epoch 0 and blob id `blob_id` with intents
        let confirmation = vector[
            1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0,
            119, 174, 25, 167, 128, 57, 96, 1, 163, 56, 61, 132,
            191, 35, 44, 18, 231, 224, 79, 178, 85, 51, 69, 53, 214,
            95, 198, 203, 56, 221, 111, 83
        ];
        // Signature from private key scalar(117) on `confirmation`
        let signature = vector[
            184, 138, 78, 92, 221, 170, 180, 107, 75, 249, 222, 177, 183, 25, 107, 214, 237,
            214, 213, 12, 239, 65, 88, 112, 65, 229, 225, 23, 62, 158, 144, 67, 206, 37, 148,
            1, 69, 64, 190, 180, 121, 153, 39, 149, 41, 2, 112, 69, 23, 68, 69, 159, 192, 116,
            41, 113, 21, 116, 123, 169, 204, 165, 232, 70, 146, 1, 175, 70, 126, 14, 20, 206,
            113, 234, 141, 195, 218, 52, 172, 56, 78, 168, 114, 213, 241, 83, 188, 215, 123,
            191, 111, 136, 26, 193, 60, 246
        ];

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create storage node
        // Pk corresponding to secret key scalar(117)
        let public_key = vector[
            149, 234, 204, 58, 220, 9, 200, 39, 89, 63, 88, 30, 142, 45,
            224, 104, 191, 76, 245, 208, 192, 235, 41, 229, 55, 47, 13, 35, 54, 71, 136, 238, 15,
            155, 235, 17, 44, 138, 126, 156, 47, 12, 114, 4, 51, 112, 92, 240
        ];
        let storage_node = storage_node::create_storage_node_info(
            string::utf8(b"node"),
            string::utf8(b"127.0.0.1"),
            public_key,
            NETWORK_PUBLIC_KEY,
            vector[0, 1, 2, 3, 4, 5],
        );

        // Create a new committee
        let cap = committee::create_committee_cap_for_tests();
        let committee = committee::create_committee(&cap, 0, vector[storage_node]);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let mut blob1 = blob::register(
            &system,
            storage,
            blob_id,
            root_hash,
            10000,
            RED_STUFF,
            &mut ctx,
        );

        // Set certify
        blob::certify(&system, &mut blob1, signature, vector[0], confirmation);

        // Assert certified
        assert!(option::is_some(blob::certified_epoch(&blob1)), 0);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test, expected_failure(abort_code=blob::EWrongEpoch)]
    public fun test_blob_certify_bad_epoch(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // Set INCORRECT EPOCH TO 1
        let certify_message = blob::certified_blob_message_for_testing(1, blob_id);

        // Set certify
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test, expected_failure(abort_code=blob::EInvalidBlobId)]
    public fun test_blob_certify_bad_blob_id(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // DIFFERENT blob id
        let certify_message = blob::certified_blob_message_for_testing(0, 0xFFF);

        // Set certify
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test, expected_failure(abort_code=blob::EResourceBounds)]
    public fun test_blob_certify_past_epoch(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 2
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(2);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 3
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(3);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Set certify -- EPOCH BEYOND RESOURCE BOUND
        let certify_message = blob::certified_blob_message_for_testing(3, blob_id);
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test]
    public fun test_blob_happy_destroy(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // Set certify
        let certify_message = blob::certified_blob_message_for_testing(0, blob_id);
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 2
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(2);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 3
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(3);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Destroy the blob
        blob::destroy_blob(&system, blob1);

        coin::burn_for_testing(fake_coin);
        system
    }

    #[test, expected_failure(abort_code=blob::EResourceBounds)]
    public fun test_blob_unhappy_destroy(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // Destroy the blob
        blob::destroy_blob(&system, blob1);

        coin::burn_for_testing(fake_coin);
        system
    }

    #[test]
    public fun test_certified_blob_message() {
        let msg = committee::certified_message_for_testing(
            1, 0, 10, 100, vector[
                0xAA, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
            ]
        );

        let message = blob::certify_blob_message(msg);
        assert!(blob::message_blob_id(&message) == 0xAA, 0);
    }

    #[test, expected_failure]
    public fun test_certified_blob_message_too_short() {
        let msg = committee::certified_message_for_testing(
            1, 0, 10, 100, vector[
                0xAA, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0,
            ],
        );

        let message = blob::certify_blob_message(msg);
        assert!(blob::message_blob_id(&message) == 0xAA, 0);
    }

    #[test]
    public fun test_blob_extend_happy_path(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Get a longer storage period
        let (mut storage_long, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            5,
            fake_coin,
            &mut ctx,
        );

        // Split by period
        let trailing_storage = split_by_epoch(&mut storage_long, 3, &mut ctx);

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);
        let certify_message = blob::certified_blob_message_for_testing(0, blob_id);

        // Set certify
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        // Now extend the blob
        blob::extend(&system, &mut blob1, trailing_storage);

        // Assert certified
        assert!(option::is_some(blob::certified_epoch(&blob1)), 0);

        destroy(storage_long);
        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test, expected_failure]
    public fun test_blob_extend_bad_period(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Get a longer storage period
        let (mut storage_long, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            5,
            fake_coin,
            &mut ctx,
        );

        // Split by period
        let trailing_storage = split_by_epoch(&mut storage_long, 4, &mut ctx);

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);
        let certify_message = blob::certified_blob_message_for_testing(0, 0xABC);

        // Set certify
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        // Now extend the blob // ITS THE WRONG PERIOD
        blob::extend(&system, &mut blob1, trailing_storage);

        destroy(storage_long);
        coin::burn_for_testing(fake_coin);
        blob::drop_for_testing(blob1);
        system
    }

    #[test,expected_failure(abort_code=blob::EResourceBounds)]
    public fun test_blob_unhappy_extend(): system::System<TESTWAL> {
        let mut ctx = tx_context::dummy();

        // A test coin.
        let fake_coin = coin::mint_for_testing<TESTWAL>(100000000, &mut ctx);

        // Create a new committee
        let committee = committee::committee_for_testing(0);

        // Create a new system object
        let mut system: system::System<TESTWAL> = system::new(committee, 1000000000, 5, &mut ctx);

        // Get some space for a few epochs
        let (storage, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            3,
            fake_coin,
            &mut ctx,
        );

        // Get a longer storage period
        let (mut storage_long, fake_coin) = system::reserve_space(
            &mut system,
            1_000_000,
            5,
            fake_coin,
            &mut ctx,
        );

        // Split by period
        let trailing_storage = split_by_epoch(&mut storage_long, 3, &mut ctx);

        // Register a Blob
        let blob_id = blob::derive_blob_id(0xABC, RED_STUFF, 5000);
        let mut blob1 = blob::register(&system, storage, blob_id, 0xABC, 5000, RED_STUFF, &mut ctx);

        // Set certify
        let certify_message = blob::certified_blob_message_for_testing(0, blob_id);
        blob::certify_with_certified_msg(&system, certify_message, &mut blob1);

        // Advance epoch -- to epoch 1
        let committee = committee::committee_for_testing(1);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 2
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(2);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Advance epoch -- to epoch 3
        system::set_done_for_testing(&mut system);
        let committee = committee::committee_for_testing(3);
        let epoch_accounts = system::next_epoch(&mut system, committee, 1000, 3);
        sa::burn_for_testing(epoch_accounts);

        // Try to extend after expiry.

        // Now extend the blo
        blob::extend(&system, &mut blob1, trailing_storage);

        // Destroy the blob
        blob::destroy_blob(&system, blob1);

        destroy(storage_long);
        coin::burn_for_testing(fake_coin);
        system
    }
}
