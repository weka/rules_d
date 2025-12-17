module foundation.data_test;

void main() {
    import foundation.lib_with_data;

    int result = processData();
    assert(result == 42, "processData failed");
}
