module impl_deps.top_lib_test;

void main() {
    import impl_deps.top_lib;

    int result = topFunction(5);
    assert(result == 211, "topFunction failed");  // ((5+100)*2)+1 = 211

    // This should fail if uncommented (cannot see implementation deps):
    // import base_lib;
}
