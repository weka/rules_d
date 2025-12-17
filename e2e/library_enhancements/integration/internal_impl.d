module integration.internal_impl;

import integration.utility;

// Internal implementation detail - not exported
// This uses the utility from implementation_deps
int internalHelper(int x) {
    // Uses implementation_deps (utility)
    return multiplyByTwo(x) + 100;
}

shared static this() {
    import integration.public_service;
    processors ~= (x) => internalHelper(x);
}
