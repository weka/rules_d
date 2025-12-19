module d.tests.lib_exports.api;

int publicFunction(int x) {
    import d.tests.lib_exports.impl;
    return internalFunction(x);
}
