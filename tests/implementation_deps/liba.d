module tests.implementation_deps.liba;

int public_func(int x) {
    import tests.simple_d_library.simple_library;
    return plusOne(x);
}