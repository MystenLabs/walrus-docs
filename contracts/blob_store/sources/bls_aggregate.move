// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// editorconfig-checker-disable-file

module blob_store::bls_aggregate {
    use sui::group_ops::Self;
    use sui::bls12381::{Self, bls12381_min_pk_verify};

    use blob_store::storage_node::StorageNodeInfo;

    // Error codes
    const ETotalMemberOrder: u64 = 0;
    const ESigVerification: u64 = 1;
    const ENotEnoughStake: u64 = 2;
    const EIncorrectCommittee: u64 = 3;

    /// This represents a BLS signing committee.
    public struct BlsCommittee has store, drop {
        /// A vector of committee members
        members: vector<StorageNodeInfo>,
        /// The total number of shards held by the committee
        n_shards: u16,
    }

    /// Constructor
    public fun new_bls_committee(members: vector<StorageNodeInfo>): BlsCommittee {
        // Compute the total number of shards
        let mut n_shards = 0;
        let mut i = 0;
        while (i < members.length()) {
            let added_weight = members[i].weight();
            assert!(added_weight > 0, EIncorrectCommittee);
            n_shards = n_shards + added_weight;
            i = i + 1;
        };
        assert!(n_shards != 0, EIncorrectCommittee);

        BlsCommittee { members, n_shards }
    }

    /// Returns the number of shards held by the committee.
    public fun n_shards(self: &BlsCommittee): u16 {
        self.n_shards
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
    ): u16 {
        // Use the signers flags to construct the key and the weights.

        // Lower bound for the next `member_index` to ensure they are monotonically increasing
        let mut min_next_member_index = 0;
        let mut i = 0;

        let mut aggregate_key = bls12381::g1_identity();
        let mut aggregate_weight = 0;

        while (i < signers.length()) {
            let member_index = signers[i] as u64;
            assert!(member_index >= min_next_member_index, ETotalMemberOrder);
            min_next_member_index = member_index + 1;

            // Bounds check happens here
            let member = &self.members[member_index];
            let key = member.public_key();
            let weight = member.weight();

            aggregate_key = bls12381::g1_add(&aggregate_key, key);
            aggregate_weight = aggregate_weight + weight;

            i = i + 1;
        };

        // The expression below is the solution to the inequality:
        // n_shards = 3 f + 1
        // stake >= 2f + 1
        assert!(
            3 * (aggregate_weight as u64) >= 2 * (self.n_shards as u64) + 1,
            ENotEnoughStake,
        );

        // Verify the signature
        let pub_key_bytes = group_ops::bytes(&aggregate_key);
        assert!(
            bls12381_min_pk_verify(
                signature,
                pub_key_bytes,
                message,
            ),
            ESigVerification,
        );

        (aggregate_weight as u16)
    }


    #[test_only]
    use blob_store::storage_node::Self;

    #[test_only]
    /// Test committee
    public fun new_bls_committee_for_testing(): BlsCommittee {
        // Pk corresponding to secret key scalar(117)
        let pub_key_bytes = x"95eacc3adc09c827593f581e8e2de068bf4cf5d0c0eb29e5372f0d23364788ee0f9beb112c8a7e9c2f0c720433705cf0";
        let storage_node = storage_node::new_for_testing(pub_key_bytes, 100);
        BlsCommittee { members: vector[storage_node], n_shards: 100 }
    }
}
