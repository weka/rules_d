import std.stdio;
import lib_mid;

void main() {
    writeln("Testing transitive dependencies");
    assert(multiplyAndAddOne(5) == 11);
    writeln("Success!");
}
