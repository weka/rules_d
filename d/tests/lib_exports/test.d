module d.tests.lib_exports.test;

unittest {
    import d.tests.lib_exports.api;
    assert(publicFunction(5) == 10);
}
