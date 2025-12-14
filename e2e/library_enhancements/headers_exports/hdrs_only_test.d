module hdrs_only_test;

void main() {
    import hdrs_only_lib;

    int result1 = add(2, 3);
    assert(result1 == 5, "add failed");

    int result2 = multiply(4, 5);
    assert(result2 == 20, "multiply failed");
}
