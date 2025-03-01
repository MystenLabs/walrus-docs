// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Contains the metadata for Blobs on Walrus.
module walrus::metadata;

use std::string::String;
use sui::vec_map::{Self, VecMap};

/// The metadata struct for Blob objects.
public struct Metadata has drop, store {
    metadata: VecMap<String, String>,
}

/// Creates a new instance of Metadata.
public fun new(): Metadata {
    Metadata {
        metadata: vec_map::empty(),
    }
}

/// Inserts a key-value pair into the metadata.
///
/// If the key is already present, the value is updated.
public fun insert_or_update(self: &mut Metadata, key: String, value: String) {
    if (self.metadata.contains(&key)) {
        self.metadata.remove(&key);
    };
    self.metadata.insert(key, value);
}

/// Removes the metadata associated with the given key.
public fun remove(self: &mut Metadata, key: &String): (String, String) {
    self.metadata.remove(key)
}

/// Removes the metadata associated with the given key, if it exists.
///
/// Optionally returns the previous value associated with the key.
public fun remove_if_exists(self: &mut Metadata, key: &String): option::Option<String> {
    if (self.metadata.contains(key)) {
        let (_, value) = self.metadata.remove(key);
        option::some(value)
    } else {
        option::none()
    }
}
