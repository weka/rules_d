module ctfe_test;

import ctfe_lib;

int square(int x) {
    return x * x;
}

unittest {
    // Both run at compile time of the test, square from this target and triple from ctfe_lib.
    static assert(square(triple(1)) == 9);
}
