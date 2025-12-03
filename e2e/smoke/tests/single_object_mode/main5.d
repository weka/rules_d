import std.stdio;
import multi_a;
import multi_b;
import multi_c;

void main() {
    writeln("Testing multi-source single object library");
    assert(funcA(5) == 15);
    assert(funcB(5) == 25);
    assert(funcC(5) == 35);
    writeln("Success!");
}
