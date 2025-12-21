module d.tests.cyclic_deps.cyclic_deps_test;

import d.tests.cyclic_deps.a;
import d.tests.cyclic_deps.b;

void main() {
    // let's say we want to make sure b is initialized before a
    assert(globalVar == 3);
}
