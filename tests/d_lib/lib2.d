module tests.d_lib.lib2;

import tests.d_lib.lib;

int plusOneTwice(int x)
{
    return plusOne(plusOne(x));
}