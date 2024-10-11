// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::messages;

use sui::{bcs, bls12381::bls12381_min_pk_verify};

const APP_ID: u8 = 3;
const INTENT_VERSION: u8 = 0;

const BLS_KEY_LEN: u64 = 48;

// Message Types
const PROOF_OF_POSSESSION_MSG_TYPE: u8 = 0;
const BLOB_CERT_MSG_TYPE: u8 = 1;
const INVALID_BLOB_ID_MSG_TYPE: u8 = 2;

// Errors
const EIncorrectAppId: u64 = 0;
const EIncorrectEpoch: u64 = 1;
const EInvalidMsgType: u64 = 2;
const EIncorrectIntentVersion: u64 = 3;

#[error]
const EInvalidKeyLength: vector<u8> = b"The length of the provided bls key is incorrect.";

/// Message signed by a BLS key in the proof of possession.
public struct ProofOfPossessionMessage has drop {
    intent_type: u8,
    intent_version: u8,
    intent_app: u8,
    epoch: u32,
    sui_address: address,
    bls_key: vector<u8>,
}

/// Creates a new ProofOfPossessionMessage given the expected epoch, sui address and BLS key.
public(package) fun new_proof_of_possession_msg(
    epoch: u32,
    sui_address: address,
    bls_key: vector<u8>,
): ProofOfPossessionMessage {
    assert!(bls_key.length() == BLS_KEY_LEN, EInvalidKeyLength);
    ProofOfPossessionMessage {
        intent_type: PROOF_OF_POSSESSION_MSG_TYPE,
        intent_version: INTENT_VERSION,
        intent_app: APP_ID,
        epoch,
        sui_address,
        bls_key,
    }
}

/// BCS encodes a ProofOfPossessionMessage, considering the BLS key as a fixed-length byte
/// array with 48 bytes.
public(package) fun to_bcs(self: &ProofOfPossessionMessage): vector<u8> {
    let mut bcs = vector[];
    bcs.append(bcs::to_bytes(&self.intent_type));
    bcs.append(bcs::to_bytes(&self.intent_version));
    bcs.append(bcs::to_bytes(&self.intent_app));
    bcs.append(bcs::to_bytes(&self.epoch));
    bcs.append(bcs::to_bytes(&self.sui_address));
    self.bls_key.do_ref!(|key_byte| bcs.append(bcs::to_bytes(key_byte)));
    bcs
}

/// Verify the provided proof of possession using the contained public key and the provided
/// signature.
public(package) fun verify_proof_of_possession(
    self: &ProofOfPossessionMessage,
    pop_signature: vector<u8>,
): bool {
    let message_bytes = self.to_bcs();
    bls12381_min_pk_verify(
        &pop_signature,
        &self.bls_key,
        &message_bytes,
    )
}

/// A message certified by nodes holding `stake_support` shards.
public struct CertifiedMessage has drop {
    intent_type: u8,
    intent_version: u8,
    cert_epoch: u32,
    stake_support: u16,
    message: vector<u8>,
}

/// Message type for certifying a blob.
///
/// Constructed from a `CertifiedMessage`, states that `blob_id` has been certified in `epoch`
/// by a quorum.
public struct CertifiedBlobMessage has drop {
    epoch: u32,
    blob_id: u256,
}

/// Message type for Invalid Blob Certificates.
///
/// Constructed from a `CertifiedMessage`, states that `blob_id` has been marked as invalid
/// in `epoch` by a quorum.
public struct CertifiedInvalidBlobId has drop {
    epoch: u32,
    blob_id: u256,
}

/// Creates a `CertifiedMessage` with support `stake_support` by parsing `message_bytes` and
/// verifying the intent and the message epoch.
public(package) fun new_certified_message(
    message_bytes: vector<u8>,
    committee_epoch: u32,
    stake_support: u16,
): CertifiedMessage {
    // Here we BCS decode the header of the message to check intents, epochs, etc.

    let mut bcs_message = bcs::new(message_bytes);
    let intent_type = bcs_message.peel_u8();
    let intent_version = bcs_message.peel_u8();
    assert!(intent_version == INTENT_VERSION, EIncorrectIntentVersion);

    let intent_app = bcs_message.peel_u8();
    assert!(intent_app == APP_ID, EIncorrectAppId);

    let cert_epoch = bcs_message.peel_u32();
    assert!(cert_epoch == committee_epoch, EIncorrectEpoch);

    let message = bcs_message.into_remainder_bytes();

    CertifiedMessage { intent_type, intent_version, cert_epoch, stake_support, message }
}

/// Constructs the certified blob message, note that constructing
/// implies a certified message, that is already checked.
public(package) fun certify_blob_message(message: CertifiedMessage): CertifiedBlobMessage {
    // Assert type is correct
    assert!(message.intent_type() == BLOB_CERT_MSG_TYPE, EInvalidMsgType);

    // The certified blob message contain a blob_id : u256
    let epoch = message.cert_epoch();
    let message_body = message.into_message();

    let mut bcs_body = bcs::new(message_body);
    let blob_id = bcs_body.peel_u256();

    // On purpose we do not check that nothing is left in the message
    // to allow in the future for extensibility.

    CertifiedBlobMessage { epoch, blob_id }
}

/// Constructs the certified blob message, note this is only
/// used for event blobs
public(package) fun certified_event_blob_message(epoch: u32, blob_id: u256): CertifiedBlobMessage {
    CertifiedBlobMessage { epoch, blob_id }
}

/// Construct the certified invalid Blob ID message, note that constructing
/// implies a certified message, that is already checked.
public(package) fun invalid_blob_id_message(message: CertifiedMessage): CertifiedInvalidBlobId {
    // Assert type is correct
    assert!(message.intent_type() == INVALID_BLOB_ID_MSG_TYPE, EInvalidMsgType);

    // The InvalidBlobID message has no payload besides the blob_id.
    // The certified blob message contain a blob_id : u256
    let epoch = message.cert_epoch();
    let message_body = message.into_message();

    let mut bcs_body = bcs::new(message_body);
    let blob_id = bcs_body.peel_u256();

    // This output is provided as a service in case anything else needs to rely on
    // certified invalid blob ID information in the future. But out base design only
    // uses the event emitted here.
    CertifiedInvalidBlobId { epoch, blob_id }
}

// === Accessors for CertifiedMessage ===

public(package) fun intent_type(self: &CertifiedMessage): u8 {
    self.intent_type
}

public(package) fun intent_version(self: &CertifiedMessage): u8 {
    self.intent_version
}

public(package) fun cert_epoch(self: &CertifiedMessage): u32 {
    self.cert_epoch
}

public(package) fun stake_support(self: &CertifiedMessage): u16 {
    self.stake_support
}

public(package) fun message(self: &CertifiedMessage): &vector<u8> {
    &self.message
}

// Deconstruct into the vector of message bytes
public(package) fun into_message(self: CertifiedMessage): vector<u8> {
    self.message
}

// === Accessors for CertifiedBlobMessage ===

public(package) fun certified_epoch(self: &CertifiedBlobMessage): u32 {
    self.epoch
}

public(package) fun certified_blob_id(self: &CertifiedBlobMessage): u256 {
    self.blob_id
}

// === Accessors for CertifiedInvalidBlobId ===

public(package) fun certified_invalid_epoch(self: &CertifiedInvalidBlobId): u32 {
    self.epoch
}

public(package) fun invalid_blob_id(self: &CertifiedInvalidBlobId): u256 {
    self.blob_id
}

// === Test only functions ===

#[test_only]
public fun certified_message_for_testing(
    intent_type: u8,
    intent_version: u8,
    cert_epoch: u32,
    stake_support: u16,
    message: vector<u8>,
): CertifiedMessage {
    CertifiedMessage { intent_type, intent_version, cert_epoch, stake_support, message }
}

#[test_only]
public fun certified_blob_message_for_testing(epoch: u32, blob_id: u256): CertifiedBlobMessage {
    CertifiedBlobMessage { epoch, blob_id }
}

#[test_only]
public fun certified_message_bytes(epoch: u32, blob_id: u256): vector<u8> {
    let mut message = vector<u8>[];
    message.push_back(BLOB_CERT_MSG_TYPE);
    message.push_back(INTENT_VERSION);
    message.push_back(APP_ID);
    message.append(bcs::to_bytes(&epoch));
    message.append(bcs::to_bytes(&blob_id));
    message
}

#[test_only]
public fun invalid_message_bytes(epoch: u32, blob_id: u256): vector<u8> {
    let mut message = vector<u8>[];
    message.push_back(INVALID_BLOB_ID_MSG_TYPE);
    message.push_back(INTENT_VERSION);
    message.push_back(APP_ID);
    message.append(bcs::to_bytes(&epoch));
    message.append(bcs::to_bytes(&blob_id));
    message
}

#[test]
fun test_message_creation() {
    let epoch = 42;
    let blob_id = 0xdeadbeefdeadbeefdeadbeefdeadbeef;
    let msg = certified_message_bytes(epoch, blob_id);
    let cert_msg = new_certified_message(msg, epoch, 1).certify_blob_message();
    assert!(cert_msg.blob_id == blob_id);
    assert!(cert_msg.epoch == epoch);
}
