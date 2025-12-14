module data_test;

void main() {
    import lib_with_data;

    int result = processData();
    assert(result == 42, "processData failed");
}
