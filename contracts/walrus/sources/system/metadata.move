// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Contains the metadata for Blobs on Walrus.
module walrus::metadata;

use sui::vec_map::{Self, VecMap};
use std::string::String;


/// The metadata struct for Blob objects.
public struct Metadata has store, drop {
    metadata: VecMap<String, String>
}

/// Creates a new instance of Metadata.
public fun new(): Metadata {
    Metadata {
        metadata: vec_map::empty()
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
