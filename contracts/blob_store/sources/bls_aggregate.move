// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::bls_aggregate {
    use sui::group_ops::Self;
    use sui::bls12381::{Self, bls12381_min_pk_verify};

    use blob_store::storage_node::{Self, StorageNodeInfo};

    // Error codes
    const ERROR_TOTAL_MEMBER_ORDER: u64 = 0;
    const ERROR_SIG_VERIFICATION: u64 = 1;
    const ERROR_NOT_ENOUGH_STAKE: u64 = 2;
    const ERROR_INCORRECT_COMMITTEE: u64 = 3;

    /// This represents a BLS signing committee.
    public struct BlsCommittee has store, drop {
        /// A vector of committee members
        members: vector<StorageNodeInfo>,
        /// The total number of shards held by the committee
        n_shards: u16,
    }

    /// Constructor
    public fun new_bls_committee(
        members: vector<StorageNodeInfo>
    ) : BlsCommittee {

        // Compute the total number of shards
        let mut n_shards = 0;
        let mut i = 0;
        while (i < vector::length(&members)) {
            let added_weight = storage_node::weight(vector::borrow(&members, i));
            assert!(added_weight > 0, ERROR_INCORRECT_COMMITTEE);
            n_shards = n_shards + added_weight;
            i = i + 1;
        };
        assert!(n_shards != 0, ERROR_INCORRECT_COMMITTEE);

        BlsCommittee {
            members,
            n_shards
        }
    }

    /// Returns the number of shards held by the committee.
    public fun n_shards(self: &BlsCommittee) : u16 {
        self.n_shards
    }

    #[test_only]
    /// Test committee
    public fun new_bls_committee_for_testing() : BlsCommittee {
        // Pk corresponding to secret key scalar(117)
        let pub_key_bytes = vector[
            149, 234, 204, 58, 220, 9, 200, 39,
            89, 63, 88, 30, 142, 45, 224, 104,
            191, 76, 245, 208, 192, 235, 41, 229,
            55, 47, 13, 35, 54, 71, 136, 238,
            15, 155, 235, 17, 44, 138, 126, 156,
            47, 12, 114, 4, 51, 112, 92, 240,
        ];
        let storage_node = storage_node::new_for_testing(pub_key_bytes, 100);
        BlsCommittee {
            members: vector[storage_node],
            n_shards: 100,
        }
    }

    /// Verify an aggregate BLS signature is a certificate in the epoch, and return the type of
    /// certificate and the bytes certified. The `signers` vector is an increasing list of indexes
    /// into the `members` vector of the committee. If there is a certificate, the function
    /// returns the total stake. Otherwise, it aborts.
    public fun verify_certificate(
        self: &BlsCommittee,
        signature: &vector<u8>,
        signers: &vector<u16>,
        message: &vector<u8>,
    ) : u16
    {
        // Use the signers flags to construct the key and the weights.

        // Lower bound for the next `member_index` to ensure they are monotonically increasing
        let mut min_next_member_index = 0;
        let mut i = 0;

        let mut aggregate_key = bls12381::g1_identity();
        let mut aggregate_weight = 0;

        while (i < vector::length(signers)) {
            let member_index = (*vector::borrow(signers, i) as u64);
            assert!(member_index >= min_next_member_index, ERROR_TOTAL_MEMBER_ORDER);
            min_next_member_index = member_index + 1;

            // Bounds check happens here
            let member = vector::borrow(&self.members, member_index);
            let key = storage_node::public_key(member);
            let weight = storage_node::weight(member);

            aggregate_key = bls12381::g1_add(&aggregate_key, key);
            aggregate_weight = aggregate_weight + weight;

            i = i + 1;
        };

        // The expression below is the solution to the inequality:
        // n_shards = 3 f + 1
        // stake >= 2f + 1
        assert!(3 * (aggregate_weight as u64) >= 2 * (self.n_shards as u64) + 1,
            ERROR_NOT_ENOUGH_STAKE);

        // Verify the signature
        let pub_key_bytes = group_ops::bytes(&aggregate_key);
        assert!(bls12381_min_pk_verify(
            signature,
            pub_key_bytes,
            message), ERROR_SIG_VERIFICATION);

        (aggregate_weight as u16)

    }

}
