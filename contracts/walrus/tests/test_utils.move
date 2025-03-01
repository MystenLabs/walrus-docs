// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
// editorconfig-checker-disable-file

/// Common test utilities for the tests.
module walrus::test_utils;

use std::string::String;
use sui::{
    balance::{Self, Balance},
    bls12381::{Self, bls12381_min_pk_verify, g1_to_uncompressed_g1},
    coin::{Self, Coin},
    vec_map
};
use wal::wal::WAL;
use walrus::{
    bls_aggregate,
    messages,
    node_metadata::{Self, NodeMetadata},
    staking_inner::StakingInnerV1,
    staking_pool::{Self, StakingPool},
    walrus_context::{Self, WalrusContext}
};

/// Debug macro for pretty printing values.
/// The value must have a `.to_string()` method.
public macro fun dbg<$T: drop>($note: vector<u8>, $value: $T) {
    use std::debug::print;
    let note = $note;
    let value = $value;
    print(&note.to_string());
    print(&value)
}

/// Helper macro to assert equality of two values. Both values must be copyable
/// and have a `.to_string()` method.
public macro fun assert_eq<$T: copy>($left: $T, $right: $T) {
    let left = $left;
    let right = $right;
    if (left != right) {
        let mut str = b"assertion failed: ".to_string();
        str.append(left.to_string());
        str.append(b" != ".to_string());
        str.append(right.to_string());
        std::debug::print(&str);
        assert!(false);
    }
}

// === Coins and Context ===

public fun wctx(epoch: u32, committee_selected: bool): WalrusContext {
    walrus_context::new(epoch, committee_selected, vec_map::empty())
}

/// Mints `amount` denominated in `FROST`.
public fun mint_frost(amount: u64, ctx: &mut TxContext): Coin<WAL> {
    coin::mint_for_testing(amount, ctx)
}

/// Mints `amount` denominated in `FROST` as balance.
public fun mint_frost_balance(amount: u64): Balance<WAL> {
    balance::create_for_testing(amount)
}

/// Mints `amount` denominated in `WAL`.
public fun mint_wal(amount: u64, ctx: &mut TxContext): Coin<WAL> {
    mint_frost(amount * frost_per_wal(), ctx)
}

/// Mints `amount` denominated in `WAL` as balance.
public fun mint_wal_balance(amount: u64): Balance<WAL> {
    mint_frost_balance(amount * frost_per_wal())
}

// === Context Runner ===

public struct ContextRunner has drop {
    epoch: u32,
    ctx: TxContext,
    committee_selected: bool,
}

/// Creates a new context runner with default values.
public fun context_runner(): ContextRunner {
    ContextRunner {
        epoch: 0,
        ctx: tx_context::dummy(),
        committee_selected: false,
    }
}

public fun epoch(self: &ContextRunner): u32 { self.epoch }

public fun is_committee_selected(self: &ContextRunner): bool { self.committee_selected }

/// Returns the current context and the transaction context.
public fun current(self: &mut ContextRunner): (WalrusContext, &mut TxContext) {
    (wctx(self.epoch, self.committee_selected), &mut self.ctx)
}

/// Selects committee
public fun select_committee(self: &mut ContextRunner): (WalrusContext, &mut TxContext) {
    self.committee_selected = true;
    (wctx(self.epoch, self.committee_selected), &mut self.ctx)
}

/// Advances the epoch by one.
public fun next_epoch(self: &mut ContextRunner): (WalrusContext, &mut TxContext) {
    self.committee_selected = false;
    self.epoch = self.epoch + 1;
    (wctx(self.epoch, self.committee_selected), &mut self.ctx)
}

/// Macro to run `next_epoch` in a lambda.
public macro fun next_epoch_tx($self: &mut ContextRunner, $f: |&WalrusContext, &mut TxContext|) {
    let (wctx, ctx) = next_epoch($self);
    $f(&wctx, ctx)
}

// === Pool Builder ===

/// Struct to support building a staking pool in tests with variable parameters.
public struct PoolBuilder has copy, drop {
    name: Option<String>,
    network_address: Option<String>,
    metadata: Option<NodeMetadata>,
    bls_sk: Option<vector<u8>>,
    network_public_key: Option<vector<u8>>,
    commission_rate: Option<u16>,
    storage_price: Option<u64>,
    write_price: Option<u64>,
    node_capacity: Option<u64>,
}

/// Test Utility: Creates a new `PoolBuilder` with default values.
///
/// ```rust
/// // Example usage:
/// let pool_a = pool().commission_rate(1000).build(&wctx, ctx);
/// let pool_b = pool().write_price(1000).storage_price(1000).build(&wctx, ctx);
/// let pool_c = pool()
///     .name(b"my node".to_string())
///     .network_address(b"0.0.0.0".to_string())
///     .bls_sk(x"75")
///     .network_public_key(x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677ab")
///     .commission_rate(1000)
///     .storage_price(1000)
///     .write_price(1000)
///     .node_capacity(1000)
///     .build(&wctx, ctx);
/// ```
public fun pool(): PoolBuilder {
    PoolBuilder {
        name: option::none(),
        network_address: option::none(),
        metadata: option::none(),
        bls_sk: option::none(),
        network_public_key: option::none(),
        commission_rate: option::none(),
        storage_price: option::none(),
        write_price: option::none(),
        node_capacity: option::none(),
    }
}

/// Sets the commission rate for the pool.
public fun commission_rate(mut self: PoolBuilder, commission_rate: u16): PoolBuilder {
    self.commission_rate.fill(commission_rate);
    self
}

/// Sets the storage price for the pool.
public fun storage_price(mut self: PoolBuilder, storage_price: u64): PoolBuilder {
    self.storage_price.fill(storage_price);
    self
}

/// Sets the write price for the pool.
public fun write_price(mut self: PoolBuilder, write_price: u64): PoolBuilder {
    self.write_price.fill(write_price);
    self
}

/// Sets the node capacity for the pool.
public fun node_capacity(mut self: PoolBuilder, node_capacity: u64): PoolBuilder {
    self.node_capacity.fill(node_capacity);
    self
}

/// Sets the name for the pool.
public fun name(mut self: PoolBuilder, name: String): PoolBuilder {
    self.name.fill(name);
    self
}

/// Sets the network address for the pool.
public fun network_address(mut self: PoolBuilder, network_address: String): PoolBuilder {
    self.network_address.fill(network_address);
    self
}

/// Sets the metadata for the pool.
public fun metadata(mut self: PoolBuilder, metadata: NodeMetadata): PoolBuilder {
    self.metadata.fill(metadata);
    self
}

/// Sets the public key for the pool.
public fun bls_sk(mut self: PoolBuilder, secret_key: vector<u8>): PoolBuilder {
    self.bls_sk.fill(pad_bls_sk(&secret_key));
    self
}

/// Sets the network public key for the pool.
public fun network_public_key(mut self: PoolBuilder, network_public_key: vector<u8>): PoolBuilder {
    self.network_public_key.fill(network_public_key);
    self
}

/// Builds a staking pool with the parameters set in the builder.
public fun build(self: PoolBuilder, wctx: &WalrusContext, ctx: &mut TxContext): StakingPool {
    let PoolBuilder {
        name,
        network_address,
        metadata,
        bls_sk,
        network_public_key,
        commission_rate,
        storage_price,
        write_price,
        node_capacity,
    } = self;

    let bls_sk = bls_sk.destroy_with_default(bls_sk_for_testing());
    let bls_pub_key = bls_min_pk_from_sk(&bls_sk);
    let pop = bls_min_pk_sign(
        &messages::new_proof_of_possession_msg(wctx.epoch(), ctx.sender(), bls_pub_key).to_bcs(),
        &bls_sk,
    );

    staking_pool::new(
        name.destroy_with_default(b"pool".to_string()),
        network_address.destroy_with_default(b"127.0.0.1".to_string()),
        metadata.destroy_with_default(node_metadata::default()),
        bls_pub_key,
        network_public_key.destroy_with_default(
            x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677ab",
        ),
        pop,
        commission_rate.destroy_with_default(0),
        storage_price.destroy_with_default(1000),
        write_price.destroy_with_default(1000),
        node_capacity.destroy_with_default(1000),
        wctx,
        ctx,
    )
}

/// Similar to `build` but registers the pool with the staking inner, using the
/// same set of
/// parameters.
public fun register(self: PoolBuilder, inner: &mut StakingInnerV1, ctx: &mut TxContext): ID {
    let PoolBuilder {
        name,
        network_address,
        metadata,
        bls_sk,
        network_public_key,
        commission_rate,
        storage_price,
        write_price,
        node_capacity,
    } = self;

    let bls_sk = bls_sk.destroy_with_default(bls_sk_for_testing());
    let bls_pub_key = bls_min_pk_from_sk(&bls_sk);
    let pop = bls_min_pk_sign(
        &messages::new_proof_of_possession_msg(inner.epoch(), ctx.sender(), bls_pub_key).to_bcs(),
        &bls_sk,
    );

    inner.create_pool(
        name.destroy_with_default(b"pool".to_string()),
        network_address.destroy_with_default(b"127.0.0.1".to_string()),
        metadata.destroy_with_default(node_metadata::default()),
        bls_pub_key,
        network_public_key.destroy_with_default(
            x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677ab",
        ),
        pop,
        commission_rate.destroy_with_default(1000),
        storage_price.destroy_with_default(1000),
        write_price.destroy_with_default(1000),
        node_capacity.destroy_with_default(1000),
        ctx,
    )
}

// === BLS Helpers ===

public fun bls_min_pk_sign(msg: &vector<u8>, sk: &vector<u8>): vector<u8> {
    let sk_element = bls12381::scalar_from_bytes(sk);
    let hashed_msg = bls12381::hash_to_g2(msg);
    let sig = bls12381::g2_mul(&sk_element, &hashed_msg);
    *sig.bytes()
}

public fun bls_min_pk_from_sk(sk: &vector<u8>): vector<u8> {
    let sk_element = bls12381::scalar_from_bytes(sk);
    let g1 = bls12381::g1_generator();
    let pk = bls12381::g1_mul(&sk_element, &g1);
    *pk.bytes()
}

// Prepends the key with zeros to get 32 bytes.
public fun pad_bls_sk(sk: &vector<u8>): vector<u8> {
    let mut sk = *sk;
    if (sk.length() < 32) {
        // Prepend with zeros to get 32 bytes.
        sk.reverse();
        (32 - sk.length()).do!(|_| sk.push_back(0));
        sk.reverse();
    };
    sk
}

/// Returns the secret key scalar 117
public fun bls_sk_for_testing(): vector<u8> {
    pad_bls_sk(&x"75")
}

/// Returns 10 bls secret keys.
public fun bls_secret_keys_for_testing(): vector<vector<u8>> {
    let mut res = vector[];
    10u64.do!(|i| {
        let sk = bls12381::scalar_from_u64(1 + (i as u64));
        res.push_back(*sk.bytes());
    });
    res
}

/// Aggregates the given signatures into one signature.
public fun bls_aggregate_sigs(signatures: &vector<vector<u8>>): vector<u8> {
    let mut aggregate = bls12381::g2_identity();
    signatures.do_ref!(
        |sig| aggregate = bls12381::g2_add(&aggregate, &bls12381::g2_from_bytes(sig)),
    );
    *aggregate.bytes()
}

/// Test committee with one committee member and 100 shards, using
/// `test_utils::bls_sk_for_testing()` as secret key.
public fun new_bls_committee_for_testing(epoch: u32): bls_aggregate::BlsCommittee {
    let node_id = tx_context::dummy().fresh_object_address().to_id();
    let sk = bls_sk_for_testing();
    let pub_key = bls12381::g1_from_bytes(&bls_min_pk_from_sk(&sk));
    let member = bls_aggregate::new_bls_committee_member(
        g1_to_uncompressed_g1(&pub_key),
        100,
        node_id,
    );
    bls_aggregate::new_bls_committee(epoch, vector[member])
}

/// Test committee with 10 committee member and 100 shards, using
/// `test_utils::bls_sk_for_testing()` as secret key.
public fun new_bls_committee_with_multiple_members_for_testing(
    epoch: u32,
    tx_context: &mut TxContext,
): bls_aggregate::BlsCommittee {
    let keys = bls_secret_keys_for_testing();
    let members = keys.map!(|sk| {
        let pub_key = bls12381::g1_from_bytes(&bls_min_pk_from_sk(&sk));
        let node_id = tx_context.fresh_object_address().to_id();
        bls_aggregate::new_bls_committee_member(g1_to_uncompressed_g1(&pub_key), 100, node_id)
    });
    bls_aggregate::new_bls_committee(epoch, members)
}

/// Converts a vector of signers to a bitmap.
/// The set of signers MUST be signed.
public fun signers_to_bitmap(signers: &vector<u16>): vector<u8> {
    let mut bitmap: vector<u8> = vector[];
    let mut next_byte = 0;
    signers.do_ref!(|signer| {
        let signer = *signer as u64;
        let byte = signer / 8;
        if (byte > bitmap.length()) {
            bitmap.push_back(next_byte);
            next_byte = 0;
        };
        let bit = (signer % 8) as u8;
        next_byte = next_byte | (1 << bit);
    });
    bitmap.push_back(next_byte);
    bitmap
}

/// Number of FROST per WAL.
public fun frost_per_wal(): u64 {
    1_000_000_000
}

// === Unit Tests ===

#[test]
fun test_bls_pk() {
    let sk = bls_sk_for_testing();
    let pub_key_bytes =
        x"95eacc3adc09c827593f581e8e2de068bf4cf5d0c0eb29e5372f0d23364788ee0f9beb112c8a7e9c2f0c720433705cf0";
    assert!(bls_min_pk_from_sk(&sk) == pub_key_bytes)
}

#[test]
fun test_bls_sign() {
    let sk = bls_sk_for_testing();
    let pub_key_bytes = bls_min_pk_from_sk(&sk);
    let msg = x"deadbeef";
    let sig = bls_min_pk_sign(&msg, &sk);

    assert!(
        bls12381_min_pk_verify(
            &sig,
            &pub_key_bytes,
            &msg,
        ),
    );
}
