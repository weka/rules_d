import std.stdio;
import lib_a;

void main() {
    writeln("Testing single object mode");
    assert(addOne(5) == 6);
    writeln("Success!");
}
