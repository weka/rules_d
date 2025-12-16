import math_add;
import math_sub;
import math_mul;
import math_div;
import math_utils;
import std.stdio;

void main() {
    // Test addition
    assert(add(5, 3) == 8);
    assert(add3(1, 2, 3) == 6);

    // Test subtraction
    assert(subtract(10, 4) == 6);
    assert(negate(5) == -5);

    // Test multiplication
    assert(multiply(3, 4) == 12);
    assert(square(5) == 25);

    // Test division
    assert(divide(20, 4) == 5);
    assert(modulo(17, 5) == 2);

    // Test utils
    assert(addAndMultiply(2, 3, 4) == 20);  // (2+3)*4 = 20
    assert(sumSquares(3, 4) == 25);  // 9+16 = 25

    writeln("Multi-file bitcode test passed!");
}
