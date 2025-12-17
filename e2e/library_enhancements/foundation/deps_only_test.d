module foundation.deps_only_test;

void main() {
    import foundation.helper1;
    import foundation.helper2;

    int result1 = helper1Function(5);
    assert(result1 == 15, "helper1Function failed");

    int result2 = helper2Function(5);
    assert(result2 == 10, "helper2Function failed");
}
