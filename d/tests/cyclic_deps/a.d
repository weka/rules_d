module d.tests.cyclic_deps.a;

import b = d.tests.cyclic_deps.b;

int f(int x)
{
    return x + b.g(x);
}

int h(int x)
{
    return x + 1;
}
