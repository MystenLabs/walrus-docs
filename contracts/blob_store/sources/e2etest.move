// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module blob_store::e2e_test {
    use blob_store::committee::{Self, CreateCommitteeCap};
    use blob_store::storage_node;

    public struct CommitteeCapHolder has key, store {
        id: UID,
        cap: CreateCommitteeCap,
    }

    // NOTE: the function below is means to be used as part of a PTB to construct a committee
    //       The PTB contains a number of `create_storage_node_info` invocations, then
    //       a `MakeMoveVec` invocation, and finally a `make_committee` invocation.

    /// Create a committee given a capability and a list of storage nodes
    public fun make_committee(
        cap: &CommitteeCapHolder,
        epoch: u64,
        storage_nodes: vector<storage_node::StorageNodeInfo>,
    ): committee::Committee {
        committee::create_committee(
            &cap.cap,
            epoch,
            storage_nodes,
        )
    }

    fun init(ctx: &mut TxContext) {
        // Create a committee caps
        let committee_cap = committee::create_committee_cap();

        // We send the wrapped cap to the creator of the package
        transfer::public_transfer(
            CommitteeCapHolder { id: object::new(ctx), cap: committee_cap },
            ctx.sender(),
        );
    }
}
