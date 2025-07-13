load("//d:d.bzl", "d_lib")

d_lib(
    name = "liba",
    srcs = ["liba.d"],
    implementation_deps = [
        "//tests/simple_d_library",
    ],
)

d_lib(
    name = "libb",
    srcs = ["libb.d"],
    deps = [
        ":liba",
    ],
)