import multi_a;
import multi_b;
import multi_c;

unittest {
    assert(funcA(1) == 11);
    assert(funcB(2) == 22);
    assert(funcC(3) == 33);
    assert(funcA(0) + funcB(0) + funcC(0) == 60);
}
