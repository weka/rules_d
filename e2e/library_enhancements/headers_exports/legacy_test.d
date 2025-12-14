module legacy_test;

void main() {
    import legacy;

    int result = legacyFunction(10);
    assert(result == 11, "legacyFunction failed");
}
