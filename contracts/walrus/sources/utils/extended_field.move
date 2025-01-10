// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module: extended_field
module walrus::extended_field;

use sui::dynamic_field as df;

/// Extended field acts as a field, but stored in a dynamic field, hence, it does
/// not bloat the original object's storage, storing only `UID` of the extended
/// field.
public struct ExtendedField<phantom T: store> has key, store { id: UID }

/// Key to store the value in the extended field. Never changes.
public struct Key() has copy, drop, store;

/// Creates a new extended field with the given value.
public fun new<T: store>(value: T, ctx: &mut TxContext): ExtendedField<T> {
    let mut id = object::new(ctx);
    df::add(&mut id, Key(), value);
    ExtendedField { id }
}

/// Borrows the value stored in the extended field.
public fun borrow<T: store>(field: &ExtendedField<T>): &T {
    df::borrow(&field.id, Key())
}

/// Borrows the value stored in the extended field mutably.
public fun borrow_mut<T: store>(field: &mut ExtendedField<T>): &mut T {
    df::borrow_mut(&mut field.id, Key())
}

/// Swaps the value stored in the extended field with the given value.
public fun swap<T: store>(field: &mut ExtendedField<T>, value: T): T {
    let old = df::remove(&mut field.id, Key());
    df::add(&mut field.id, Key(), value);
    old
}

/// Destroys the extended field and returns the value stored in it.
public fun destroy<T: store>(field: ExtendedField<T>): T {
    let ExtendedField { mut id } = field;
    let value = df::remove(&mut id, Key());
    id.delete();
    value
}
