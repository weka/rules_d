module d.tests.lib_exports.impl;

int internalFunction(int x) {
    import internal = d.tests.lib_exports.internal;
    return internal.internalFunction(x);
}
