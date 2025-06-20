module tests.circular_deps.circular_deps_test;

void main() {}

unittest
{
    import tests.circular_deps.lib_a;
    import tests.circular_deps.lib_b;

    assert(f(1) == 4);
    assert(g(1) == 3);
    assert(h(1) == 2);
    assert(globalVar == 10);
}
