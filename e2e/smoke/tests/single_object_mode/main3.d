import std.stdio;
import lib_a;
import lib_b;
import lib_d;

void main() {
    writeln("Testing mixed mode");
    assert(addOne(5) == 6);
    assert(addTwo(5) == 7);
    assert(addFour(5) == 9);
    writeln("Success!");
}
