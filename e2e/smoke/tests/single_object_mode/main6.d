import std.stdio;
import multi_d;
import multi_e;

void main() {
    writeln("Testing multi-source archive library");
    assert(funcD(5) == 10);
    assert(funcE(5) == 15);
    writeln("Success!");
}
