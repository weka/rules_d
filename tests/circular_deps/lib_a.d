module tests.circular_deps.lib_a;

import tests.circular_deps.lib_b;

__gshared int globalVar = 2;

int f(int x) {
    return x + g(x);
}

int h(int x) {
    return x + 1;
}

shared static this() {
    import std.stdio;
    globalVar += 3;
    writeln("lib_a initialized");
}
