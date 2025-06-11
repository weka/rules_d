
int f(int x) {
    return x * 2;
}

unittest
{
    assert(f(2) == 4);
    assert(f(3) == 6);
    assert(f(0) == 0);
    assert(f(-1) == -2);
    assert(f(-5) == -10);
}