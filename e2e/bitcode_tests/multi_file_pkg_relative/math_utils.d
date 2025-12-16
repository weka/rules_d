module math_utils;

import math_add;
import math_mul;

int addAndMultiply(int a, int b, int c) {
    return multiply(add(a, b), c);
}

int sumSquares(int a, int b) {
    return square(a) + square(b);
}
