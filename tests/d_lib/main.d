module tests.d_lib.main;

import tests.d_lib.lib2;

void main()
{
    int x = 5;
    int result = plusOneTwice(x);
    import std.stdio;
    writeln("The result of plusOne(", x, ") is: ", result);
}