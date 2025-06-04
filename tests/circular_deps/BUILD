
load("//d:d.bzl", "d_lib")

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