load("//d:d.bzl", "d_binary", "d_lib")

d_lib(
    name = "d_lib",
    srcs = ["lib.d"],
    exports = ["lib.d"],
)

d_lib(
    name = "d_lib2",
    srcs = ["lib2.d"],
    exports = ["lib2.d"],
    deps = [":d_lib"],
)

d_binary(
    name = "main",
    srcs = ["main.d"],
    deps = [":d_lib2"],
)