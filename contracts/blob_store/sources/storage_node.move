// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::storage_node {
    use std::string::String;
    use sui::group_ops::Element;
    use sui::bls12381::{G1, g1_from_bytes};

    // Error codes
    const EInvalidNetworkPublicKey: u64 = 1;

    /// Represents a storage node and its meta-data.
    ///
    /// Creation and deletion of storage node info is an
    /// uncontrolled operation, but it lacks key so cannot
    /// be stored outside the context of another object.
    public struct StorageNodeInfo has store, drop {
        name: String,
        network_address: String,
        public_key: Element<G1>,
        network_public_key: vector<u8>,
        shard_ids: vector<u16>,
    }

    /// A public constructor for the StorageNodeInfo.
    public fun create_storage_node_info(
        name: String,
        network_address: String,
        public_key: vector<u8>,
        network_public_key: vector<u8>,
        shard_ids: vector<u16>,
    ): StorageNodeInfo {
        assert!(network_public_key.length() == 32, EInvalidNetworkPublicKey);
        StorageNodeInfo {
            name,
            network_address,
            public_key: g1_from_bytes(&public_key),
            network_public_key,
            shard_ids
        }
    }

    public fun public_key(self: &StorageNodeInfo): &Element<G1> {
        &self.public_key
    }

    public fun network_public_key(self: &StorageNodeInfo): &vector<u8> {
        &self.network_public_key
    }

    public fun shard_ids(self: &StorageNodeInfo): &vector<u16> {
        &self.shard_ids
    }

    public fun weight(self: &StorageNodeInfo): u16 {
        self.shard_ids.length() as u16
    }

    #[test_only]
    /// Create a storage node with dummy name & address
    public fun new_for_testing(public_key: vector<u8>, weight: u16): StorageNodeInfo {
        let mut i: u16 = 0;
        let mut shard_ids = vector[];
        while (i < weight) {
            shard_ids.push_back(i);
            i = i + 1;
        };
        StorageNodeInfo {
            name: b"node".to_string(),
            network_address: b"127.0.0.1".to_string(),
            public_key: g1_from_bytes(&public_key),
            network_public_key: x"820e2b273530a00de66c9727c40f48be985da684286983f398ef7695b8a44677",
            shard_ids,
        }
    }
}
