// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::epoch_parameters;

/// The epoch parameters for the system.
public struct EpochParams has copy, drop, store {
    /// The storage capacity of the system.
    total_capacity_size: u64,
    /// The price per unit size of storage.
    storage_price_per_unit_size: u64,
    /// The write price per unit size.
    write_price_per_unit_size: u64,
}

// === Constructor ===

public(package) fun new(
    total_capacity_size: u64,
    storage_price_per_unit_size: u64,
    write_price_per_unit_size: u64,
): EpochParams {
    EpochParams {
        total_capacity_size,
        storage_price_per_unit_size,
        write_price_per_unit_size,
    }
}

// === Accessors ===

/// The storage capacity of the system.
public(package) fun capacity(self: &EpochParams): u64 {
    self.total_capacity_size
}

/// The price per unit size of storage.
public(package) fun storage_price(self: &EpochParams): u64 {
    self.storage_price_per_unit_size
}

/// The write price per unit size.
public(package) fun write_price(self: &EpochParams): u64 {
    self.write_price_per_unit_size
}

// === Test only ===

#[test_only]
public fun epoch_params_for_testing(): EpochParams {
    EpochParams {
        total_capacity_size: 1_000_000_000,
        storage_price_per_unit_size: 5,
        write_price_per_unit_size: 1,
    }
}
