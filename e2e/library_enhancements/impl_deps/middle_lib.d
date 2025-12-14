module middle_lib;

// Middle library - uses base_lib internally but doesn't expose it
int middleFunction(int x) {
    import base_lib;
    return baseFunction(x) * 2;
}
