module tests.deps_only_library.test;

void main() {
    import tests.header_only_library.lib;

    int result = add(2, 3);
    
    assert(result == 5);

    import tests.simple_d_library.simple_library;

    int result2 = plusOne(4);

    assert(result2 == 5);
}