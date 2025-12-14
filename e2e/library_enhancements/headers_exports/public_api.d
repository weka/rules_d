module public_api;

// Public API - exported to consumers
int publicFunction(int x) {
    import internal;
    return internalHelper(x) + 10;
}
