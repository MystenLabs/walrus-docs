#[test_only]
#[allow(unused_use)]
module walrus_dep::walrus_dep_tests {
    use walrus_dep::wrapped_blob;

    const ENotImplemented: u64 = 0;

    #[test]
    fun test_walrus_dep() {
        // pass
    }

    #[test, expected_failure(abort_code = ::walrus_dep::walrus_dep_tests::ENotImplemented)]
    fun test_walrus_dep_fail() {
        abort ENotImplemented
    }
}
