module tests.header_only_library.header_only_library_test;

void main() {
    import tests.header_only_library.lib;

    int result = add(2, 3);
    
    assert(result == 5);
}