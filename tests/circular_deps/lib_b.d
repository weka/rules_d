module tests.circular_deps.lib_b;

import tests.circular_deps.lib_a;

int g(int x) {
    return x + h(x);
}
