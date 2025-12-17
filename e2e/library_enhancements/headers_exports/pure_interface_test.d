module headers_exports.pure_interface_test;

void main() {
    import headers_exports.pure_interface;

    // Test that we can use the interface through the headers-only library
    int result = calculate(5);
    assert(result == 22, "calculate failed");

    string msg = getMessage();
    assert(msg == "Hello from pure interface", "getMessage failed");
}
