// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Implements Sui Object Display for user-owned objects.
///
/// The default fields for Display are:
/// - name
/// - description
/// - image_url
/// - link
/// - project_url
///
/// Optionally:
/// - thumbnail_url
/// - creator
module walrus::display;

use std::type_name;
use sui::{display::{Self, Display}, object_bag::{Self, ObjectBag}, package::Publisher};
use walrus::{blob::Blob, staked_wal::StakedWal, storage_resource::Storage};

/// The wrapper that stores the objects.
public struct ObjectDisplay has key {
    id: UID,
    inner: ObjectBag,
}

/// The dynamic field key to use
public struct PublisherKey() has copy, drop, store;

/// Creates the `ObjectDisplay` instance with default objects in it.
public(package) fun create(p: Publisher, ctx: &mut TxContext) {
    let mut inner = object_bag::new(ctx);

    inner.add(type_name::get<Blob>(), init_blob_display(&p, ctx));
    inner.add(type_name::get<Storage>(), init_storage_display(&p, ctx));
    inner.add(type_name::get<StakedWal>(), init_staked_wal_display(&p, ctx));
    inner.add(PublisherKey(), p);

    transfer::share_object(ObjectDisplay { id: object::new(ctx), inner })
}

/// Creates initial `Display` for the `Blob` type.
fun init_blob_display(p: &Publisher, ctx: &mut TxContext): Display<Blob> {
    let mut d = display::new(p, ctx);

    d.add(b"name".to_string(), b"Walrus Blob ({size}b)".to_string());
    d.add(
        b"description".to_string(),
        // editorconfig-checker-disable-next-line
        b"Registered: {registered_epoch}; certified: {certified_epoch}; deletable: {deletable}".to_string(),
    );
    d.add(b"image_url".to_string(), b"https://www.walrus.xyz/walrus-blob".to_string());
    d.add(b"project_url".to_string(), b"https://walrus.xyz/".to_string());
    d.add(b"link".to_string(), b"".to_string());
    d.update_version();
    d
}

/// Creates initial `Display` for the `Storage` type.
fun init_storage_display(p: &Publisher, ctx: &mut TxContext): Display<Storage> {
    let mut d = display::new(p, ctx);

    d.add(b"name".to_string(), b"Walrus Storage Resource ({storage_size}b)".to_string());
    d.add(b"description".to_string(), b"Start: {start_epoch}; end: {end_epoch}".to_string());
    d.add(b"image_url".to_string(), b"https://www.walrus.xyz/walrus-storage".to_string());
    d.add(b"project_url".to_string(), b"https://walrus.xyz/".to_string());
    d.add(b"link".to_string(), b"".to_string());
    d.update_version();
    d
}

/// Creates initial `Display` for the `StakedWal` type.
fun init_staked_wal_display(p: &Publisher, ctx: &mut TxContext): Display<StakedWal> {
    let mut d = display::new(p, ctx);

    d.add(b"name".to_string(), b"Staked WAL ({principal} FROST)".to_string());
    d.add(
        b"description".to_string(),
        b"Staked for node: {node_id}, activates at: {activation_epoch}".to_string(),
    );
    d.add(b"image_url".to_string(), b"https://www.walrus.xyz/walrus-stakedwal".to_string());
    d.add(b"project_url".to_string(), b"https://walrus.xyz/".to_string());
    d.add(b"link".to_string(), b"".to_string());
    d.update_version();
    d
}
