import utils;
import std.stdio;

void main() {
    assert(multiply(3, 4) == 12);
    assert(square(5) == 25);
    writeln("Cross-package import test passed!");
}
