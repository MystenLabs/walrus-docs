// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::metadata_tests;

use sui::vec_map::EKeyDoesNotExist;
use walrus::metadata;

#[test]
public fun test_metadata_success() {
    let mut metadata = metadata::new();
    metadata.insert_or_update(b"key1".to_string(), b"value1".to_string());
    metadata.insert_or_update(b"key2".to_string(), b"value2".to_string());
    // Update the value corresponding to key1.
    metadata.insert_or_update(b"key1".to_string(), b"value3".to_string());
    let (key, value) = metadata.remove(&b"key1".to_string());
    assert!(key == b"key1".to_string());
    assert!(value == b"value3".to_string());
}

#[test, expected_failure(abort_code = EKeyDoesNotExist)]
public fun test_metadata_failure() {
    let mut metadata = metadata::new();
    metadata.insert_or_update(b"key1".to_string(), b"value1".to_string());
    metadata.remove(&b"key2".to_string());
}
