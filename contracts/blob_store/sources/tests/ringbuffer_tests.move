// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module blob_store::ringbuffer_tests {
    public struct TESTCOIN has store, drop {}

    use blob_store::storage_accounting as sa;
    use blob_store::storage_accounting::FutureAccountingRingBuffer;

    // ------------- TESTS --------------------

    #[test]
    public fun test_basic_ring_buffer(): FutureAccountingRingBuffer<TESTCOIN> {
        let mut buffer: FutureAccountingRingBuffer<TESTCOIN> = sa::ring_new(3);

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

        buffer
    }

    #[test, expected_failure]
    public fun test_oob_fail_ring_buffer(): FutureAccountingRingBuffer<TESTCOIN> {
        let mut buffer: FutureAccountingRingBuffer<TESTCOIN> = sa::ring_new(3);

        sa::epoch(sa::ring_lookup_mut(&mut buffer, 3));

        buffer
    }
}
