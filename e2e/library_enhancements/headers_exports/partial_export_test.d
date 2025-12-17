module headers_exports.partial_export_test;

void main() {
    import headers_exports.public_api;

    // Can use public API
    int result = publicFunction(5);
    assert(result == 20, "publicFunction failed");  // 5*2 + 10 = 20

    // Cannot import internal (this would fail if uncommented)
    // import internal;
}
