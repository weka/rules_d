module d.tests.lib_that_depends_on_lib.lib_that_depends_on_lib;

static import simple_c = d.tests.simple_c_library.simple_library_wrapper;
static import simple_d = d.tests.simple_d_library.simple_library;

int overEngineeredPlusOne(int x)
{
    for (;;)
    {
        int result1 = simple_d.plusOne(x);
        int result2 = simple_c.plus_one(x);
        if (result1 == result2)
            return result1;
    }
}
