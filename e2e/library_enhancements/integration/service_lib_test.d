module integration.service_lib_test;

void main() {
    import integration.public_service;

    // Can use public API
    int result = processValue(5);
    assert(result == 110, "processValue failed");
}
