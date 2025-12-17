module headers_exports.public_api;

// Public API - exported to consumers
int publicFunction(int x) {
    import headers_exports.internal;
    return internalHelper(x) + 10;
}
