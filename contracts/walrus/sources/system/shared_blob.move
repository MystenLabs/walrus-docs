// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::shared_blob;

use sui::{balance::{Self, Balance}, coin::Coin};
use wal::wal::WAL;
use walrus::{blob::Blob, system::System};

/// A wrapper around `Blob` that acts as a "tip jar" that can be funded by anyone and allows
/// keeping the wrapped `Blob` alive indefinitely.
public struct SharedBlob has key, store {
    id: UID,
    blob: Blob,
    funds: Balance<WAL>,
}

/// Shares the provided `blob` as a `SharedBlob` with zero funds.
public fun new(blob: Blob, ctx: &mut TxContext) {
    transfer::share_object(SharedBlob {
        id: object::new(ctx),
        blob,
        funds: balance::zero(),
    })
}

/// Adds the provided `Coin` to the stored funds.
public fun fund(self: &mut SharedBlob, added_funds: Coin<WAL>) {
    self.funds.join(added_funds.into_balance());
}

/// Extends the lifetime of the wrapped `Blob` by `epochs_ahead` epochs if the stored funds are
/// sufficient and the new lifetime does not exceed the maximum lifetime.
public fun extend(
    self: &mut SharedBlob,
    system: &mut System,
    epochs_ahead: u32,
    ctx: &mut TxContext,
) {
    let mut coin = self.funds.withdraw_all().into_coin(ctx);
    system.extend_blob(&mut self.blob, epochs_ahead, &mut coin);
    self.funds.join(coin.into_balance());
}
