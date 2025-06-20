
load("//d:d.bzl", "d_lib", "d_test")

d_lib(
    name = "lib_a",
    srcs = ["lib_a.d"],
    exports = ["lib_a.d"],
    exports_lib = "lib_a_exports",
    deps = [
        ":lib_b",
    ],
)

d_lib(
    name = "lib_b",
    srcs = ["lib_b.d"],
    exports = ["lib_b.d"],
    deps = [
        ":lib_a_exports",
    ],
)

d_test(
    name = "circular_deps_test",
    srcs = ["circular_deps_test.d"],
    link_order = {
        ":lib_a": "-1",  # lib_a must be linked last
    },
    args = [
        "--DRT-oncycle=ignore",
    ],
    deps = [
        ":lib_a",
        ":lib_b",
    ],
)

d_test(
    name = "circular_deps_test2",
    srcs = ["circular_deps_test.d"],
    link_order = {
        ":lib_a": "-1",  # lib_a must be linked last
    },
    args = [
        "--DRT-oncycle=ignore",
    ],
    deps = [
        ":lib_b",
        ":lib_a",
    ],
)