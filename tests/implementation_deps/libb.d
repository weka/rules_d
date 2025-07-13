module tests.implementation_deps.libb;

import tests.implementation_deps.liba;

int libb_func(int x) {
    return public_func(x);
}