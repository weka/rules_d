module tests.circular_deps.lib_a;

import tests.circular_deps.lib_b;

int f(int x) {
    return x + g(x);
}

int h(int x) {
    return x + 1;
}