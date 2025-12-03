import lib_a;
import lib_b;

unittest {
    assert(addOne(5) == 6);
    assert(addTwo(5) == 7);
    assert(addOne(addTwo(3)) == 6);
}
