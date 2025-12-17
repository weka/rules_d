module impl_deps.middle_lib_test;

void main() {
    import impl_deps.middle_lib;

    int result = middleFunction(5);
    assert(result == 210, "middleFunction failed");  // (5+100)*2 = 210
}
