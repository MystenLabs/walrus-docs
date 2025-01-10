// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus::ringbuffer_tests;

use sui::test_utils::destroy;
use walrus::storage_accounting::{Self as sa, FutureAccountingRingBuffer};

#[test]
public fun test_basic_ring_buffer() {
    let mut buffer: FutureAccountingRingBuffer = sa::ring_new(3);

    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 0)) == 0, 100);
    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 1)) == 1, 100);
    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 2)) == 2, 100);

    let entry = sa::ring_pop_expand(&mut buffer);
    assert!(sa::epoch(&entry) == 0, 100);
    sa::delete_empty_future_accounting(entry);

    let entry = sa::ring_pop_expand(&mut buffer);
    assert!(sa::epoch(&entry) == 1, 100);
    sa::delete_empty_future_accounting(entry);

    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 0)) == 2, 100);
    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 1)) == 3, 100);
    assert!(sa::epoch(sa::ring_lookup_mut(&mut buffer, 2)) == 4, 100);

    destroy(buffer)
}

#[test, expected_failure(abort_code = sa::ETooFarInFuture)]
public fun test_oob_fail_ring_buffer() {
    let mut buffer: FutureAccountingRingBuffer = sa::ring_new(3);

    sa::epoch(sa::ring_lookup_mut(&mut buffer, 3));

    abort
}
