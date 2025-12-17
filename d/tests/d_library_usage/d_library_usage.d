import d.tests.simple_d_library.simple_library : plusOne;

int main()
{
    int x = 1;
    int y = plusOne(x);
    assert(y == x + 1);

    return 0;
}
