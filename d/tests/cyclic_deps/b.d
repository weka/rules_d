module d.tests.cyclic_deps.b;

import a = d.tests.cyclic_deps.a;

int g(int x)
{
    return x + a.h(x);
}

shared static this() {
    import std.stdio;
    writeln("b initialized");
    a.globalVar = 2;
}
