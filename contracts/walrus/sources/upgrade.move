// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module to manage Walrus contract upgrades.
///
/// This allows upgrading the contract with a quorum of storage nodes or using an emergency upgrade
/// capability.
///
/// Requiring a quorum instead of a simple majority guarantees that (i) a majority of honest nodes
/// (by weight) have voted for the upgrade, and (ii) that an upgrade cannot be blocked solely by
/// byzantine nodes.
module walrus::upgrade;

use sui::{
    package::{UpgradeCap, UpgradeTicket, UpgradeReceipt},
    table::{Self, Table},
    vec_set::{Self, VecSet}
};
use walrus::{auth::Authenticated, events, staking::Staking, system::System};

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The upgrade manager ID in the emergency upgrade cap is incorrect.
const EInvalidUpgradeManager: u64 = 0;
/// Caller is not authorized to vote for upgrades for the specified node.
const ENotAuthorized: u64 = 1;
/// The node already voted for the proposal.
const EDuplicateVote: u64 = 2;
/// The length of the package digest is incorrect.
const EInvalidPackageDigest: u64 = 3;
/// No upgrade proposal exists for the specified digest.
const ENoProposalForDigest: u64 = 4;
/// The upgrade proposal was not authorized in the current epoch.
const EWrongEpoch: u64 = 5;
/// The upgrade proposal has not received enough votes yet.
const ENotEnoughVotes: u64 = 6;
/// The upgrade proposal is not for the correct package version.
const EWrongVersion: u64 = 7;

/// Newtype for package digests, ensures that the digest is always 32 bytes long.
public struct PackageDigest(vector<u8>) has copy, drop, store;

/// An upgrade proposal containing the digest of the package to upgrade to and the votes on the
/// proposal.
public struct UpgradeProposal has drop, store {
    /// The epoch in which the proposal was created.
    /// The upgrade must be performed in the same epoch.
    epoch: u32,
    /// The digest of the package to upgrade to.
    digest: PackageDigest,
    /// The version of the package to upgrade to.
    /// This allows to easily clean up old proposals.
    version: u64,
    /// The voting weight of the proposal.
    voting_weight: u16,
    /// The node IDs that have voted for this proposal.
    /// Note: the number of nodes in the committee is capped, so we can use a VecSet.
    voters: VecSet<ID>,
}

/// The upgrade manager object.
///
/// This object contains the upgrade cap for the package and is used to authorize upgrades.
public struct UpgradeManager has key {
    id: UID,
    cap: UpgradeCap,
    upgrade_proposals: Table<PackageDigest, UpgradeProposal>,
}

/// A capability that allows upgrades to be performed without quorum.
///
/// This is intended for emergency use and should be burned once the community has matured.
public struct EmergencyUpgradeCap has key, store {
    id: UID,
    upgrade_manager_id: ID,
}

/// Create a new upgrade manager.
///
/// This is called from the `init::initialize_walrus` function and will
/// create a unique `UpgradeManager` and `EmergencyUpgradeCap` object.
public(package) fun new(cap: UpgradeCap, ctx: &mut TxContext): EmergencyUpgradeCap {
    let upgrade_manager = UpgradeManager {
        id: object::new(ctx),
        cap,
        upgrade_proposals: table::new(ctx),
    };
    let emergency_upgrade_cap = EmergencyUpgradeCap {
        id: object::new(ctx),
        upgrade_manager_id: object::id(&upgrade_manager),
    };
    transfer::share_object(upgrade_manager);
    emergency_upgrade_cap
}

// === Upgrade Manager Public API ===

/// Vote for an upgrade given the digest of the package to upgrade to.
///
/// This will create a new upgrade proposal if none exists for the given digest.
public fun vote_for_upgrade(
    self: &mut UpgradeManager,
    staking: &Staking,
    auth: Authenticated,
    node_id: ID,
    digest: vector<u8>,
) {
    assert!(staking.check_governance_authorization(node_id, auth), ENotAuthorized);
    let weight = staking.get_current_node_weight(node_id);
    let epoch = staking.epoch();
    let digest = package_digest!(digest);
    // Check if a proposal already exists for the given digest.

    let proposal = if (self.upgrade_proposals.contains(digest)) {
        // Check if the proposal is for the current epoch.
        let proposal = self.upgrade_proposals.borrow_mut(digest);
        // check epoch and version and reset if they don't match
        if (proposal.epoch != epoch || proposal.version != self.cap.version() + 1) {
            *proposal = fresh_proposal(epoch, digest, self.cap.version() + 1);
        };
        proposal
    } else {
        let proposal = fresh_proposal(epoch, digest, self.cap.version() + 1);
        self.upgrade_proposals.add(digest, proposal);
        self.upgrade_proposals.borrow_mut(digest)
    };
    proposal.add_vote(node_id, weight);
    // Check if the proposal has reached quorum and emit an event if it has.
    if (staking.is_quorum(proposal.voting_weight)) {
        events::emit_contract_upgrade_quorum_reached(epoch, digest.0);
    }
}

/// Authorizes an upgrade that has reached quorum.
public fun authorize_upgrade(
    self: &mut UpgradeManager,
    staking: &Staking,
    digest: vector<u8>,
): UpgradeTicket {
    let digest = package_digest!(digest);

    assert!(self.upgrade_proposals.contains(digest), ENoProposalForDigest);
    let proposal = self.upgrade_proposals.remove(digest);

    // Check that the proposal is for the current epoch and that the quorum is reached.
    assert!(proposal.epoch == staking.epoch(), EWrongEpoch);
    assert!(staking.is_quorum(proposal.voting_weight), ENotEnoughVotes);

    // Check that the version is correct.
    assert!(self.cap.version() + 1 == proposal.version, EWrongVersion);

    let policy = self.cap.policy();
    self.cap.authorize(policy, digest.0)
}

/// Authorizes an upgrade using the emergency upgrade cap.
///
/// This should be used sparingly and once walrus has a healthy community and governance,
/// the EmergencyUpgradeCap should be burned.
public fun authorize_emergency_upgrade(
    upgrade_manager: &mut UpgradeManager,
    emergency_upgrade_cap: &EmergencyUpgradeCap,
    digest: vector<u8>,
): UpgradeTicket {
    assert!(
        emergency_upgrade_cap.upgrade_manager_id == object::id(upgrade_manager),
        EInvalidUpgradeManager,
    );
    let policy = upgrade_manager.cap.policy();
    upgrade_manager.cap.authorize(policy, digest)
}

/// Commits an upgrade and sets the new package id in the staking and system objects.
///
/// After committing an upgrade, the staking and system objects should be migrated
/// using the [`package::migrate`] function to emit an event that informs all storage nodes
/// and prevent previous package versions from being used.
public fun commit_upgrade(
    upgrade_manager: &mut UpgradeManager,
    staking: &mut Staking,
    system: &mut System,
    receipt: UpgradeReceipt,
) {
    let new_package_id = receipt.package();
    staking.set_new_package_id(new_package_id);
    system.set_new_package_id(new_package_id);
    upgrade_manager.cap.commit(receipt)
}

/// Cleans up the upgrade proposals table.
///
/// Deletes all proposals from past epochs and versions that are lower than the current version.
public fun cleanup_upgrade_proposals(
    self: &mut UpgradeManager,
    staking: &Staking,
    proposals: vector<vector<u8>>,
) {
    proposals.do!(|digest| {
        let digest = package_digest!(digest);
        if (self.upgrade_proposals.contains(digest)) {
            let proposal = self.upgrade_proposals.borrow(digest);
            if (proposal.version <= self.cap.version() || proposal.epoch < staking.epoch()) {
                self.upgrade_proposals.remove(digest);
            }
        }
    });
}

// === Emergency Upgrade Cap Public API ===

/// Burns the emergency upgrade cap.
///
/// This will prevent any further upgrades using the `EmergencyUpgradeCap` and will
/// make upgrades fully reliant on quorum-based governance.
public fun burn_emergency_upgrade_cap(emergency_upgrade_cap: EmergencyUpgradeCap) {
    let EmergencyUpgradeCap { id, .. } = emergency_upgrade_cap;
    id.delete();
}

// === Upgrade Manager internal functions ===

/// Creates a new upgrade proposal.
///
/// This will emit an event that signals that a new upgrade proposal has been created.
fun fresh_proposal(epoch: u32, digest: PackageDigest, version: u64): UpgradeProposal {
    events::emit_contract_upgrade_proposed(epoch, digest.0);
    UpgradeProposal { epoch, digest, version, voting_weight: 0, voters: vec_set::empty() }
}

/// Adds a vote to an upgrade proposal.
fun add_vote(proposal: &mut UpgradeProposal, node_id: ID, weight: u16) {
    assert!(!proposal.voters.contains(&node_id), EDuplicateVote);
    proposal.voters.insert(node_id);
    proposal.voting_weight = proposal.voting_weight + weight;
}

// === Package Digest ===

/// Creates a new package digest given a byte vector.
///
/// Aborts if the digest is not 32 bytes long.
macro fun package_digest($digest: vector<u8>): PackageDigest {
    let digest = $digest;
    assert!(digest.length() == 32, EInvalidPackageDigest);
    PackageDigest(digest)
}

// === Test only ===

#[test_only]
public fun digest_for_testing(ctx: &mut TxContext): vector<u8> {
    ctx.fresh_object_address().to_bytes()
}
