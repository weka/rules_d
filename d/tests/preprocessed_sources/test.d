
unittest {
    import lib1 = d.tests.preprocessed_sources.lib1;
    import lib2 = d.tests.preprocessed_sources.lib2;
    assert(lib2.foo(1) == 2);
    assert(lib1.bar(1) == 3);
    assert(lib1.filename == "d/tests/preprocessed_sources/lib1.d");
    assert(lib2.filename == "d/tests/preprocessed_sources/lib2.d");
}
