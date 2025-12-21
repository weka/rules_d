module d.tests.cyclic_deps.b;

import a = d.tests.cyclic_deps.a;

int g(int x)
{
    return x + a.h(x);
}
