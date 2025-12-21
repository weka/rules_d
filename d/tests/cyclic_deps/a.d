module d.tests.cyclic_deps.a;

import b = d.tests.cyclic_deps.b;

shared int globalVar = 1;

int f(int x)
{
    return x + b.g(x);
}

int h(int x)
{
    return x + 1;
}

shared static this() {
    import std.stdio;
    writeln("a initialized");
    globalVar = 3;
}
