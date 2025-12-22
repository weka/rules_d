module d.tests.indirect_deps.test;

unittest {
    import d.tests.indirect_deps.lib1;

    assert(lib1_func(1) == 2);
}
