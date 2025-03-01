// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::redstuff;

// The length of a hash used for the Red Stuff metadata
const DIGEST_LEN: u64 = 32;

// The length of a blob id in the stored metadata
const BLOB_ID_LEN: u64 = 32;

// RedStuff with RaptorQ
const RED_STUFF_RAPTOR: u8 = 0;
// RedStuff with Reed-Solomon
const RS2: u8 = 1;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The encoding type is invalid.
const EInvalidEncodingType: u64 = 0;

/// Computes the encoded length of a blob for the Red Stuff encoding using either
/// RaptorQ or Reed-Solomon, given its unencoded size and the number of shards.
/// The output length includes the size of the metadata hashes and the blob ID.
/// This computation is the same as done by the function of the same name in
/// `crates/walrus_core/encoding/config.rs` and should be kept in sync.
public(package) fun encoded_blob_length(
    unencoded_length: u64,
    n_shards: u16,
    encoding_type: u8,
): u64 {
    // prettier-ignore
    let slivers_size = (
        source_symbols_primary(n_shards, encoding_type) as u64
            + (source_symbols_secondary(n_shards, encoding_type) as u64),
    ) * (symbol_size(unencoded_length, n_shards, encoding_type) as u64);

    (n_shards as u64) * (slivers_size + metadata_size(n_shards))
}

/// The number of primary source symbols per sliver given `n_shards`.
fun source_symbols_primary(n_shards: u16, encoding_type: u8): u16 {
    n_shards - 2 * max_byzantine(n_shards) - decoding_safety_limit(n_shards, encoding_type)
}

/// The number of secondary source symbols per sliver given `n_shards`.
fun source_symbols_secondary(n_shards: u16, encoding_type: u8): u16 {
    n_shards - max_byzantine(n_shards) - decoding_safety_limit(n_shards, encoding_type)
}

/// The total number of source symbols given `n_shards`.
fun n_source_symbols(n_shards: u16, encoding_type: u8): u64 {
    (source_symbols_primary(n_shards, encoding_type) as u64)
        * (source_symbols_secondary(n_shards, encoding_type) as u64)
}

/// Computes the symbol size given the `unencoded_length` and number of shards
/// `n_shards`. If the resulting symbols would be larger than a `u16`, this
/// results in an Error.
fun symbol_size(mut unencoded_length: u64, n_shards: u16, encoding_type: u8): u16 {
    if (unencoded_length == 0) {
        unencoded_length = 1;
    };
    let n_symbols = n_source_symbols(n_shards, encoding_type);
    let mut symbol_size = ((unencoded_length - 1) / n_symbols + 1) as u16;
    if (encoding_type == RS2 && symbol_size % 2 == 1) {
        // For Reed-Solomon, the symbol size must be a multiple of 2.
        symbol_size = symbol_size + 1;
    };
    symbol_size
}

/// The size of the metadata, i.e. sliver root hashes and blob_id.
fun metadata_size(n_shards: u16): u64 {
    (n_shards as u64) * DIGEST_LEN * 2 + BLOB_ID_LEN
}

/// Returns the decoding safety limit. See `crates/walrus-core/src/encoding/config.rs`
/// for a description.
fun decoding_safety_limit(n_shards: u16, encoding_type: u8): u16 {
    match (encoding_type) {
        // These ranges are chosen to ensure that the safety limit is at most 20% of f,
        // up to a safety limit of 5.
        RED_STUFF_RAPTOR => (max_byzantine(n_shards) / 5).min(5),
        RS2 => 0,
        _ => abort EInvalidEncodingType,
    }
}

/// Maximum number of byzantine shards, given `n_shards`.
fun max_byzantine(n_shards: u16): u16 {
    (n_shards - 1) / 3
}

// Tests

#[test_only]
use walrus::test_utils::assert_eq;

#[test_only]
fun assert_encoded_size(
    unencoded_length: u64,
    n_shards: u16,
    encoded_size: u64,
    encoding_type: u8,
) {
    assert_eq!(encoded_blob_length(unencoded_length, n_shards, encoding_type), encoded_size);
}

#[test]
/// These tests replicate the tests for `encoded_blob_length` in
/// `crates/walrus_core/encoding/config.rs` and should be kept in sync.
fun test_encoded_size_raptor() {
    assert_encoded_size(1, 10, 10 * ((4 + 7) + 10 * 2 * 32 + 32), RED_STUFF_RAPTOR);
    assert_encoded_size(1, 1000, 1000 * ((329 + 662) + 1000 * 2 * 32 + 32), RED_STUFF_RAPTOR);
    assert_encoded_size(
        (4 * 7) * 100,
        10,
        10 * ((4 + 7) * 100 + 10 * 2 * 32 + 32),
        RED_STUFF_RAPTOR,
    );
    assert_encoded_size(
        (329 * 662) * 100,
        1000,
        1000 * ((329 + 662) * 100 + 1000 * 2 * 32 + 32),
        RED_STUFF_RAPTOR,
    );
}

#[test]
fun test_encoded_size_reed_solomon() {
    assert_encoded_size(1, 10, 10 * (2*(4 + 7) + 10 * 2 * 32 + 32), RS2);
    assert_encoded_size(1, 1000, 1000 * (2*(334 + 667) + 1000 * 2 * 32 + 32), RS2);
    assert_encoded_size((4 * 7) * 100, 10, 10 * ((4 + 7) * 100 + 10 * 2 * 32 + 32), RS2);
    assert_encoded_size(
        (334 * 667) * 100,
        1000,
        1000 * ((334 + 667) * 100 + 1000 * 2 * 32 + 32),
        RS2,
    );
}

#[test]
fun test_zero_size() {
    assert_encoded_size(0, 10, 10 * ((4 + 7) + 10 * 2 * 32 + 32), RED_STUFF_RAPTOR);
    assert_encoded_size(0, 10, 10 * (2*(4 + 7) + 10 * 2 * 32 + 32), RS2);
}

#[test, expected_failure]
fun test_symbol_too_large() {
    let n_shards = 100;
    // Create an unencoded length for which each symbol must be larger than the maximum size
    let unencoded_length = (0xffff + 1) * n_source_symbols(n_shards, RED_STUFF_RAPTOR);
    // Test should fail here
    let _ = symbol_size(unencoded_length, n_shards, RED_STUFF_RAPTOR);
}

#[test_only]
fun assert_primary_secondary_source_symbols(
    n_shards: u16,
    primary: u16,
    secondary: u16,
    encoding_type: u8,
) {
    assert_eq!(source_symbols_primary(n_shards, encoding_type), primary);
    assert_eq!(source_symbols_secondary(n_shards, encoding_type), secondary);
}

#[test]
fun test_source_symbols_number() {
    // Using RedStuff with RaptorQ. These values are taken from the RedStuff docs.
    assert_primary_secondary_source_symbols(7, 3, 5, RED_STUFF_RAPTOR);
    assert_primary_secondary_source_symbols(10, 4, 7, RED_STUFF_RAPTOR);
    assert_primary_secondary_source_symbols(31, 9, 19, RED_STUFF_RAPTOR);
    assert_primary_secondary_source_symbols(100, 29, 62, RED_STUFF_RAPTOR);
    assert_primary_secondary_source_symbols(300, 97, 196, RED_STUFF_RAPTOR);
    assert_primary_secondary_source_symbols(1000, 329, 662, RED_STUFF_RAPTOR);

    // Using RedStuff with Reed-Solomon. These are the standard BFT values.
    assert_primary_secondary_source_symbols(7, 3, 5, RS2);
    assert_primary_secondary_source_symbols(10, 4, 7, RS2);
    assert_primary_secondary_source_symbols(31, 11, 21, RS2);
    assert_primary_secondary_source_symbols(100, 34, 67, RS2);
    assert_primary_secondary_source_symbols(301, 101, 201, RS2);
    assert_primary_secondary_source_symbols(1000, 334, 667, RS2);
}
