// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The WAL token is the native token for the Walrus Protocol.
module wal::wal;

use sui::{coin::{Self, TreasuryCap, Coin}, dynamic_object_field as dof, url};

const TOTAL_WAL_SUPPLY_TO_MINT: u64 = 5_000_000_000; // 5B WAL
const DECIMALS: u8 = 9;
const SYMBOL: vector<u8> = b"WAL";
const NAME: vector<u8> = b"WAL Token";
const DESCRIPTION: vector<u8> = b"The native token for the Walrus Protocol.";
const ICON_URL: vector<u8> = b"https://www.walrus.xyz/wal-icon.svg";

/// The OTW for the `WAL` coin.
public struct WAL has drop {}

public struct ProtectedTreasury has key {
    id: UID,
}

/// The dynamic object field key for the `TreasuryCap`.
/// Storing the `TreasuryCap` as a dynamic object field allows us to easily look-up the
/// `TreasuryCap` from the `ProtectedTreasury` off-chain.
public struct TreasuryCapKey has copy, drop, store {}

/// Initializes the WAL token and mints the total supply to the publisher.
/// This also wraps the `TreasuryCap` in a `ProtectedTreasury` analogous to the SuiNS token.
///
/// After publishing this, the `UpgradeCap` must be burned to ensure that the supply
/// of minted WAL cannot change.
#[allow(lint(share_owned))]
fun init(otw: WAL, ctx: &mut TxContext) {
    let (mut cap, metadata) = coin::create_currency(
        otw,
        DECIMALS,
        SYMBOL,
        NAME,
        DESCRIPTION,
        option::some(url::new_unsafe_from_bytes(ICON_URL)),
        ctx,
    );

    // Mint the total supply of WAL.
    let frost_per_wal = 10u64.pow(DECIMALS);
    let total_supply_to_mint = TOTAL_WAL_SUPPLY_TO_MINT * frost_per_wal;
    let minted_coin = cap.mint(total_supply_to_mint, ctx);

    transfer::public_freeze_object(metadata);

    // Wrap the `TreasuryCap` and share it.
    let mut protected_treasury = ProtectedTreasury {
        id: object::new(ctx),
    };
    dof::add(&mut protected_treasury.id, TreasuryCapKey {}, cap);
    transfer::share_object(protected_treasury);

    // Transfer the minted WAL to the publisher.
    transfer::public_transfer(minted_coin, ctx.sender());
}

/// Get the total supply of the WAL token.
public fun total_supply(treasury: &ProtectedTreasury): u64 {
    treasury.borrow_cap().total_supply()
}

/// Burns a `Coin<WAL>` from the sender.
public fun burn(treasury: &mut ProtectedTreasury, coin: Coin<WAL>) {
    treasury.borrow_cap_mut().burn(coin);
}

// ===== Private Accessors =====

/// Borrows the `TreasuryCap` from the `ProtectedTreasury`.
fun borrow_cap(treasury: &ProtectedTreasury): &TreasuryCap<WAL> {
    dof::borrow(&treasury.id, TreasuryCapKey {})
}

/// Borrows the `TreasuryCap` from the `ProtectedTreasury` as mutable.
fun borrow_cap_mut(treasury: &mut ProtectedTreasury): &mut TreasuryCap<WAL> {
    dof::borrow_mut(&mut treasury.id, TreasuryCapKey {})
}

// ===== Tests =====

#[test_only]
use sui::test_scenario as test;

#[test]
fun test_init() {
    let user = @0xa11ce;
    let mut test = test::begin(user);
    init(WAL {}, test.ctx());
    test.next_tx(user);

    let protected_treasury = test.take_shared<ProtectedTreasury>();
    let frost_per_wal = 10u64.pow(DECIMALS);
    let wal_supply = 5_000_000_000;
    assert!(protected_treasury.total_supply() == wal_supply * frost_per_wal);
    test::return_shared(protected_treasury);

    let coin_metadata = test.take_immutable<coin::CoinMetadata<WAL>>();

    assert!(coin_metadata.get_decimals() == 9);
    assert!(coin_metadata.get_symbol() == b"WAL".to_ascii_string());
    assert!(coin_metadata.get_name() == b"WAL Token".to_string());
    assert!(
        coin_metadata.get_description() ==
            b"The native token for the Walrus Protocol.".to_string(),
    );
    assert!(
        coin_metadata.get_icon_url() == option::some(
            url::new_unsafe_from_bytes(b"https://www.walrus.xyz/wal-icon.svg"),
        ),
    );

    test::return_immutable(coin_metadata);
    test.end();
}

#[test]
fun test_burn() {
    let user = @0xa11ce;
    let mut test = test::begin(user);
    init(WAL {}, test.ctx());
    test.next_tx(user);

    let mut protected_treasury = test.take_shared<ProtectedTreasury>();
    let frost_per_wal = 10u64.pow(DECIMALS);
    let wal_supply = 5_000_000_000;
    assert!(protected_treasury.total_supply() == wal_supply * frost_per_wal);

    let mut coin = test.take_from_sender<Coin<WAL>>();
    let new_coin = coin.split(1000 * frost_per_wal, test.ctx());
    protected_treasury.burn(new_coin);
    assert!(protected_treasury.total_supply() == (wal_supply - 1000) * frost_per_wal);

    test.return_to_sender(coin);
    test::return_shared(protected_treasury);
    test.end();
}
