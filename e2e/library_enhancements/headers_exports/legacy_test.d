module headers_exports.legacy_test;

void main() {
    import headers_exports.legacy;

    int result = legacyFunction(10);
    assert(result == 11, "legacyFunction failed");
}
