// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::auth;

/// Authentication for either a sender or an object.
/// Unlike the `Authorized` type, it cannot be stored and must be used or ignored in the same
/// transaction.
public enum Authenticated has drop {
    Sender(address),
    Object(ID),
}

/// Defines the ways to authorize an action. It can be either an address - checked
/// with `ctx.sender()`, - or an object - checked with `object::id(..)`.
public enum Authorized has copy, drop, store {
    Address(address),
    ObjectID(ID),
}

/// Authenticates the sender as the authorizer.
public fun authenticate_sender(ctx: &TxContext): Authenticated {
    Authenticated::Sender(ctx.sender())
}

/// Authenticates an object as the authorizer.
public fun authenticate_with_object<T: key>(obj: &T): Authenticated {
    Authenticated::Object(object::id(obj))
}

/// Returns the `Authorized` as an address.
public fun authorized_address(addr: address): Authorized {
    Authorized::Address(addr)
}

/// Returns the `Authorized` as an object.
public fun authorized_object(id: ID): Authorized {
    Authorized::ObjectID(id)
}

/// Checks if the authentication matches the authorization.
public(package) fun matches(authenticated: &Authenticated, authorized: &Authorized): bool {
    match (authenticated) {
        Authenticated::Sender(sender) => {
            match (authorized) {
                Authorized::Address(addr) => sender == addr,
                _ => false,
            }
        },
        Authenticated::Object(id) => {
            match (authorized) {
                Authorized::ObjectID(obj_id) => id == obj_id,
                _ => false,
            }
        },
    }
}
