module impl_deps.top_lib;

// Top library - can use middle_lib but should not see base_lib
int topFunction(int x) {
    import impl_deps.middle_lib;
    return middleFunction(x) + 1;

    // This should fail if uncommented (cannot see implementation deps):
    // import base_lib;
}
