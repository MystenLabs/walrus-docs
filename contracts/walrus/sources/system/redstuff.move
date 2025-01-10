// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::redstuff;

// The length of a hash used for the Red Stuff metadata
const DIGEST_LEN: u64 = 32;

// The length of a blob id in the stored metadata
const BLOB_ID_LEN: u64 = 32;

/// Computes the encoded length of a blob for the Red Stuff encoding, given its
/// unencoded size and the number of shards. The output length includes the
/// size of the metadata hashes and the blob ID.
/// This computation is the same as done by the function of the same name in
/// `crates/walrus_core/encoding/config.rs` and should be kept in sync.
public(package) fun encoded_blob_length(unencoded_length: u64, n_shards: u16): u64 {
    // prettier-ignore
    let slivers_size = (
        source_symbols_primary(n_shards) as u64 + (source_symbols_secondary(n_shards) as u64),
    ) * (symbol_size(unencoded_length, n_shards) as u64);

    (n_shards as u64) * (slivers_size + metadata_size(n_shards))
}

/// The number of primary source symbols per sliver given `n_shards`.
fun source_symbols_primary(n_shards: u16): u16 {
    n_shards - 2 * max_byzantine(n_shards) - decoding_safety_limit(n_shards)
}

/// The number of secondary source symbols per sliver given `n_shards`.
fun source_symbols_secondary(n_shards: u16): u16 {
    n_shards - max_byzantine(n_shards) - decoding_safety_limit(n_shards)
}

/// The total number of source symbols given `n_shards`.
fun n_source_symbols(n_shards: u16): u64 {
    (source_symbols_primary(n_shards) as u64) * (source_symbols_secondary(n_shards) as u64)
}

/// Computes the symbol size given the `unencoded_length` and number of shards
/// `n_shards`. If the resulting symbols would be larger than a `u16`, this
/// results in an Error.
fun symbol_size(mut unencoded_length: u64, n_shards: u16): u16 {
    if (unencoded_length == 0) {
        unencoded_length = 1;
    };
    let n_symbols = n_source_symbols(n_shards);
    ((unencoded_length - 1) / n_symbols + 1) as u16
}

/// The size of the metadata, i.e. sliver root hashes and blob_id.
fun metadata_size(n_shards: u16): u64 {
    (n_shards as u64) * DIGEST_LEN * 2 + BLOB_ID_LEN
}

/// Returns the decoding safety limit. See `crates/walrus-core/src/encoding/config.rs`
/// for a description.
fun decoding_safety_limit(n_shards: u16): u16 {
    // These ranges are chosen to ensure that the safety limit is at most 20% of f,
    // up to a safety limit of 5.
    (max_byzantine(n_shards) / 5).min(5)
}

/// Maximum number of byzantine shards, given `n_shards`.
fun max_byzantine(n_shards: u16): u16 {
    (n_shards - 1) / 3
}

// Tests

#[test_only]
fun assert_encoded_size(unencoded_length: u64, n_shards: u16, encoded_size: u64) {
    assert!(encoded_blob_length(unencoded_length, n_shards) == encoded_size, 0);
}

#[test]
/// These tests replicate the tests for `encoded_blob_length` in
/// `crates/walrus_core/encoding/config.rs` and should be kept in sync.
fun test_encoded_size() {
    assert_encoded_size(1, 10, 10 * ((4 + 7) + 10 * 2 * 32 + 32));
    assert_encoded_size(1, 1000, 1000 * ((329 + 662) + 1000 * 2 * 32 + 32));
    assert_encoded_size((4 * 7) * 100, 10, 10 * ((4 + 7) * 100 + 10 * 2 * 32 + 32));
    assert_encoded_size(
        (329 * 662) * 100,
        1000,
        1000 * ((329 + 662) * 100 + 1000 * 2 * 32 + 32),
    );
}

#[test]
fun test_zero_size() {
    // test should fail here
    encoded_blob_length(0, 10);
}

#[test, expected_failure]
fun test_symbol_too_large() {
    let n_shards = 100;
    // Create an unencoded length for which each symbol must be larger than the maximum size
    let unencoded_length = (0xffff + 1) * n_source_symbols(n_shards);
    // Test should fail here
    let _ = symbol_size(unencoded_length, n_shards);
}

#[test_only]
fun assert_primary_secondary_source_symbols(n_shards: u16, primary: u16, secondary: u16) {
    assert!(source_symbols_primary(n_shards) == primary, 0);
    assert!(source_symbols_secondary(n_shards) == secondary, 0);
}

#[test]
fun test_source_symbols_number() {
    // These values are taken from the RedStuff docs.
    assert_primary_secondary_source_symbols(7, 3, 5);
    assert_primary_secondary_source_symbols(10, 4, 7);
    assert_primary_secondary_source_symbols(31, 9, 19);
    assert_primary_secondary_source_symbols(100, 29, 62);
    assert_primary_secondary_source_symbols(300, 97, 196);
    assert_primary_secondary_source_symbols(1000, 329, 662);
}
