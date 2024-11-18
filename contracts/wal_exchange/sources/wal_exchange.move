// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: wal_exchange
module wal_exchange::wal_exchange;

use sui::{balance::{Self, Balance}, coin::Coin, sui::SUI};
use wal::wal::WAL;

// Keep errors in `walrus-sui/types/move_errors.rs` up to date with changes here.
const EInsufficientFundsInExchange: u64 = 0;
const EInsufficientInputBalance: u64 = 1;
const EUnauthorizedAdminCap: u64 = 2;
const EInvalidExchangeRate: u64 = 3;

/// A public exchange that allows exchanging SUI for WAL at a fixed exchange rate.
public struct Exchange has key, store {
    id: UID,
    wal: Balance<WAL>,
    sui: Balance<SUI>,
    rate: ExchangeRate,
    admin: ID,
}

/// Capability that allows the holder to modify an `Exchange`'s exchange rate and withdraw funds.
public struct AdminCap has key, store {
    id: UID,
}

/// Represents an exchange rate: `wal` WAL = `sui` SUI.
public struct ExchangeRate has copy, drop, store {
    wal: u64,
    sui: u64,
}

// === Functions for `ExchangeRate` ===

/// Creates a new exchange rate, making sure it is valid.
public fun new_exchange_rate(wal: u64, sui: u64): ExchangeRate {
    assert!(wal != 0 && sui != 0, EInvalidExchangeRate);
    ExchangeRate { wal, sui }
}

fun wal_to_sui(self: &ExchangeRate, amount: u64): u64 {
    amount * self.sui / self.wal
}

fun sui_to_wal(self: &ExchangeRate, amount: u64): u64 {
    amount * self.wal / self.sui
}

// === Functions for `Exchange` ===

// Creation functions

/// Creates a new shared exchange with a 1:1 exchange rate and returns the associated `AdminCap`.
public fun new(ctx: &mut TxContext): AdminCap {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::share_object(Exchange {
        id: object::new(ctx),
        wal: balance::zero(),
        sui: balance::zero(),
        rate: ExchangeRate { wal: 1, sui: 1 },
        admin: object::id(&admin_cap),
    });
    admin_cap
}

/// Creates a new shared exchange with a 1:1 exchange rate, funds it with WAL, and returns the
/// associated `AdminCap`.
public fun new_funded(wal: &mut Coin<WAL>, amount: u64, ctx: &mut TxContext): AdminCap {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    let mut exchange = Exchange {
        id: object::new(ctx),
        wal: balance::zero(),
        sui: balance::zero(),
        rate: ExchangeRate { wal: 1, sui: 1 },
        admin: object::id(&admin_cap),
    };
    exchange.add_wal(wal, amount);

    transfer::share_object(exchange);
    admin_cap
}

/// Adds WAL to the balance stored in the exchange.
public fun add_wal(self: &mut Exchange, wal: &mut Coin<WAL>, amount: u64) {
    self.wal.join(wal.balance_mut().split(amount));
}

/// Adds SUI to the balance stored in the exchange.
public fun add_sui(self: &mut Exchange, sui: &mut Coin<SUI>, amount: u64) {
    self.sui.join(sui.balance_mut().split(amount));
}

/// Adds WAL to the balance stored in the exchange.
public fun add_all_wal(self: &mut Exchange, wal: Coin<WAL>) {
    self.wal.join(wal.into_balance());
}

/// Adds SUI to the balance stored in the exchange.
public fun add_all_sui(self: &mut Exchange, sui: Coin<SUI>) {
    self.sui.join(sui.into_balance());
}

// Admin functions

fun check_admin(self: &Exchange, admin_cap: &AdminCap) {
    assert!(self.admin == object::id(admin_cap), EUnauthorizedAdminCap);
}

/// Withdraws WAL from the balance stored in the exchange.
public fun withdraw_wal(
    self: &mut Exchange,
    amount: u64,
    admin_cap: &AdminCap,
    ctx: &mut TxContext,
): Coin<WAL> {
    self.check_admin(admin_cap);
    assert!(self.wal.value() >= amount, EInsufficientFundsInExchange);
    self.wal.split(amount).into_coin(ctx)
}

/// Withdraws SUI from the balance stored in the exchange.
public fun withdraw_sui(
    self: &mut Exchange,
    amount: u64,
    admin_cap: &AdminCap,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.check_admin(admin_cap);
    assert!(self.sui.value() >= amount, EInsufficientFundsInExchange);
    self.sui.split(amount).into_coin(ctx)
}

/// Sets the exchange rate of the exchange to `wal` WAL = `sui` SUI.
public fun set_exchange_rate(self: &mut Exchange, wal: u64, sui: u64, admin_cap: &AdminCap) {
    self.check_admin(admin_cap);
    self.rate = new_exchange_rate(wal, sui);
}

// User functions

/// Exchanges the provided SUI coin for WAL at the exchange's rate.
public fun exchange_all_for_wal(
    self: &mut Exchange,
    sui: Coin<SUI>,
    ctx: &mut TxContext,
): Coin<WAL> {
    let value_wal = self.rate.sui_to_wal(sui.value());
    assert!(self.wal.value() >= value_wal, EInsufficientFundsInExchange);
    self.sui.join(sui.into_balance());
    self.wal.split(value_wal).into_coin(ctx)
}

/// Exchanges `amount_sui` out of the provided SUI coin for WAL at the exchange's rate.
public fun exchange_for_wal(
    self: &mut Exchange,
    sui: &mut Coin<SUI>,
    amount_sui: u64,
    ctx: &mut TxContext,
): Coin<WAL> {
    assert!(sui.value() >= amount_sui, EInsufficientInputBalance);
    self.exchange_all_for_wal(sui.split(amount_sui, ctx), ctx)
}

/// Exchanges the provided WAL coin for SUI at the exchange's rate.
public fun exchange_all_for_sui(
    self: &mut Exchange,
    wal: Coin<WAL>,
    ctx: &mut TxContext,
): Coin<SUI> {
    let value_sui = self.rate.wal_to_sui(wal.value());
    assert!(self.sui.value() >= value_sui, EInsufficientFundsInExchange);
    self.wal.join(wal.into_balance());
    self.sui.split(value_sui).into_coin(ctx)
}

/// Exchanges `amount_wal` out of the provided WAL coin for SUI at the exchange's rate.
public fun exchange_for_sui(
    self: &mut Exchange,
    wal: &mut Coin<WAL>,
    amount_wal: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(wal.value() >= amount_wal, EInsufficientInputBalance);
    self.exchange_all_for_sui(wal.split(amount_wal, ctx), ctx)
}

// === Tests ===

#[test_only]
use sui::coin;
#[test_only]
use sui::test_utils::destroy;

#[test_only]
fun new_for_testing(wal_per_sui: u64, ctx: &mut TxContext): (Exchange, AdminCap) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    (
        Exchange {
            id: object::new(ctx),
            wal: balance::zero(),
            sui: balance::zero(),
            rate: ExchangeRate { wal: wal_per_sui, sui: 1 },
            admin: object::id(&admin_cap),
        },
        admin_cap,
    )
}

#[test]
fun test_standard_flow() {
    let ctx = &mut tx_context::dummy();
    let (mut exchange, admin_cap) = new_for_testing(1, ctx);

    exchange.set_exchange_rate(4, 2, &admin_cap);
    exchange.add_all_wal(coin::mint_for_testing(1_000_000, ctx));
    exchange.add_all_sui(coin::mint_for_testing(1_000_000, ctx));

    let mut wal_coin = exchange.exchange_all_for_wal(coin::mint_for_testing(42, ctx), ctx);
    assert!(wal_coin.value() == 84);
    assert!(exchange.sui.value() == 1_000_042);
    assert!(exchange.wal.value() == 999_916);

    let mut sui_coin = exchange.exchange_for_sui(&mut wal_coin, 9, ctx);
    assert!(sui_coin.value() == 4);
    assert!(wal_coin.value() == 75);

    let wal_coin_2 = exchange.exchange_for_wal(&mut sui_coin, 2, ctx);
    assert!(wal_coin_2.value() == 4);
    assert!(sui_coin.value() == 2);

    let withdraw_wal_coin = exchange.withdraw_wal(13, &admin_cap, ctx);
    assert!(withdraw_wal_coin.value() == 13);

    let withdraw_sui_coin = exchange.withdraw_sui(42, &admin_cap, ctx);
    assert!(withdraw_sui_coin.value() == 42);

    destroy(wal_coin);
    destroy(wal_coin_2);
    destroy(sui_coin);
    destroy(withdraw_wal_coin);
    destroy(withdraw_sui_coin);
    destroy(exchange);
    destroy(admin_cap);
}

#[test]
#[expected_failure(abort_code = EInsufficientFundsInExchange)]
fun test_insufficient_funds_in_exchange() {
    let ctx = &mut tx_context::dummy();
    let (mut exchange, _admin_cap) = new_for_testing(2, ctx);

    exchange.add_all_sui(coin::mint_for_testing(1_000_000, ctx));
    let wal_coin = exchange.exchange_all_for_wal(coin::mint_for_testing(1, ctx), ctx);

    destroy(wal_coin);
    destroy(exchange);
    destroy(_admin_cap);
}

#[test]
#[expected_failure(abort_code = EInsufficientInputBalance)]
fun test_insufficient_coin() {
    let ctx = &mut tx_context::dummy();
    let (mut exchange, _admin_cap) = new_for_testing(2, ctx);

    exchange.add_all_sui(coin::mint_for_testing(1_000_000, ctx));
    let mut sui_coin = coin::mint_for_testing(1, ctx);
    let wal_coin = exchange.exchange_for_wal(&mut sui_coin, 2, ctx);

    destroy(sui_coin);
    destroy(wal_coin);
    destroy(exchange);
    destroy(_admin_cap);
}

#[test]
#[expected_failure(abort_code = EUnauthorizedAdminCap)]
fun test_unauthorized() {
    let ctx = &mut tx_context::dummy();
    let (mut exchange_1, _admin_cap_1) = new_for_testing(2, ctx);
    let (mut _exchange_2, admin_cap_2) = new_for_testing(2, ctx);

    exchange_1.set_exchange_rate(1, 1, &admin_cap_2);

    destroy(exchange_1);
    destroy(_admin_cap_1);
    destroy(_exchange_2);
    destroy(admin_cap_2);
}

#[test]
fun test_creation() {
    let ctx = &mut tx_context::dummy();
    let mut coin = coin::mint_for_testing(1_000_000, ctx);
    let _admin_cap_1 = new(ctx);
    let _admin_cap_2 = new_funded(&mut coin, 100, ctx);
    (ctx);

    destroy(coin);
    destroy(_admin_cap_1);
    destroy(_admin_cap_2);
}
