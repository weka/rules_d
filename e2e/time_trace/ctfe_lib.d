module ctfe_lib;

int triple(int x) {
    return x * 3;
}

// Forces triple through CTFE when this library is compiled.
static assert(triple(2) == 6);
