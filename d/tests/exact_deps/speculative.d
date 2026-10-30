module speculative;

// Every import here is speculative. The compiler still reads a module or string file it finds, so
// -makedeps lists it and exact deps keeps it an input; speculative_test.sh checks that only the files
// nothing imports are pruned.

static if (__traits(compiles, { import foo.bar; }))
    enum hasBar = true;
else
    enum hasBar = false;

static if (is(typeof({ import foo.baz; })))
    enum hasBaz = true;
else
    enum hasBaz = false;

// No dependency provides foo.missing: nothing is read, and it is not a candidate either. A file that
// appears later changes the candidates list, which stays in the action key.
static if (__traits(compiles, { import foo.missing; }))
    enum hasMissing = true;
else
    enum hasMissing = false;

enum hasFlag = __traits(compiles, import("strings/flag.txt"));
enum hasAbsent = __traits(compiles, import("strings/absent.txt"));

static assert(hasBar && hasBaz && !hasMissing && hasFlag && !hasAbsent);
