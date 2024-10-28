// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: wal
module wal::wal;

use sui::coin;

/// The OTW for the `WAL` coin.
public struct WAL has drop {}

#[allow(lint(share_owned))]
fun init(otw: WAL, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = coin::create_currency(
        otw,
        9, // decimals,
        b"WAL", // symbol,
        b"WAL", // name,
        b"WAL Token", // description,
        option::none(), // url (currently, empty)
        ctx,
    );

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_share_object(coin_metadata);
}

#[test_only]
use sui::test_scenario as test;

#[test]
fun test_init() {
    let user = @0xa11ce;
    let mut test = test::begin(user);
    init(WAL {}, test.ctx());
    test.next_tx(user);

    let treasury_cap = test.take_from_address<coin::TreasuryCap<WAL>>(user);
    assert!(treasury_cap.total_supply() == 0);
    test.return_to_sender(treasury_cap);

    let coin_metadata = test.take_shared<coin::CoinMetadata<WAL>>();

    assert!(coin_metadata.get_decimals() == 9);
    assert!(coin_metadata.get_symbol() == b"WAL".to_ascii_string());
    assert!(coin_metadata.get_name() == b"WAL".to_string());
    assert!(coin_metadata.get_description() == b"WAL Token".to_string());
    assert!(coin_metadata.get_icon_url() == option::none());

    test::return_shared(coin_metadata);
    test.end();
}
