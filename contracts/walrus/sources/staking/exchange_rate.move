// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A utility module which implements an `ExchangeRate` struct and its methods.
/// It stores a fixed point exchange rate between the Wal token and pool token.
module walrus::pool_exchange_rate;

/// Represents the exchange rate for the staking pool.
public struct PoolExchangeRate has store, copy, drop {
    /// Amount of staked WAL tokens this epoch.
    wal_amount: u128,
    /// Amount of total tokens in the pool this epoch.
    pool_token_amount: u128,
}

/// Create an empty exchange rate.
public(package) fun empty(): PoolExchangeRate {
    PoolExchangeRate {
        wal_amount: 0,
        pool_token_amount: 0,
    }
}

/// Create a new exchange rate with the given amounts.
public(package) fun new(wal_amount: u64, pool_token_amount: u64): PoolExchangeRate {
    PoolExchangeRate {
        wal_amount: (wal_amount as u128),
        pool_token_amount: (pool_token_amount as u128),
    }
}

public(package) fun get_wal_amount(exchange_rate: &PoolExchangeRate, token_amount: u64): u64 {
    // When either amount is 0, that means we have no stakes with this pool.
    // The other amount might be non-zero when there's dust left in the pool.
    if (exchange_rate.wal_amount == 0 || exchange_rate.pool_token_amount == 0) {
        return token_amount
    };

    let token_amount = (token_amount as u128);
    let res = token_amount * exchange_rate.wal_amount / exchange_rate.pool_token_amount;

    res as u64
}

public(package) fun get_token_amount(exchange_rate: &PoolExchangeRate, wal_amount: u64): u64 {
    // When either amount is 0, that means we have no stakes with this pool.
    // The other amount might be non-zero when there's dust left in the pool.
    if (exchange_rate.wal_amount == 0 || exchange_rate.pool_token_amount == 0) {
        return wal_amount
    };

    let wal_amount = (wal_amount as u128);
    let res = wal_amount * exchange_rate.pool_token_amount / exchange_rate.wal_amount;

    res as u64
}
