// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::storage_node {
    use std::string::String;
    #[test_only]
    use std::string;
    use sui::group_ops::Element;
    use sui::bls12381::{G1, g1_from_bytes};

    /// Represents a storage node and its meta-data.
    ///
    /// Creation and deletion of storage node info is an
    /// uncontrolled operation, but it lacks key so cannot
    /// be stored outside the context of another object.
    public struct StorageNodeInfo has store, drop {
        name: String,
        network_address: String,
        public_key: Element<G1>,
        shard_ids: vector<u16>,
    }

    /// A public constructor for the StorageNodeInfo.
    public fun create_storage_node_info(
        name: String,
        network_address: String,
        public_key: vector<u8>,
        shard_ids: vector<u16>,
    ) : StorageNodeInfo {
        StorageNodeInfo {
            name,
            network_address,
            public_key: g1_from_bytes(&public_key),
            shard_ids
        }
    }

    public fun public_key(self: &StorageNodeInfo) : &Element<G1> {
        &self.public_key
    }

    public fun shard_ids(self: &StorageNodeInfo) : &vector<u16> {
        &self.shard_ids
    }

    public fun weight(self: &StorageNodeInfo) : u16 {
        (vector::length(&self.shard_ids) as u16)
    }

    #[test_only]
    /// Create a storage node with dummy name & address
    public fun new_for_testing(
        public_key: vector<u8>,
        weight: u16,
    ) : StorageNodeInfo {
        let mut i: u16 = 0;
        let mut shard_ids = vector::empty();
        while (i < weight) {
            vector::push_back(&mut shard_ids, i);
            i = i + 1;
        };
        StorageNodeInfo {
            name: string::utf8(b"node"),
            network_address: string::utf8(b"127.0.0.1"),
            public_key: g1_from_bytes(&public_key),
            shard_ids
        }
    }
}
