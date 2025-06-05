load("//d:d.bzl", "d_library", "d_test")

d_library(
    name = "deps_only_library",
    srcs = [],
    deps = [
        "//tests/header_only_library:header_only_library",
        "//tests/simple_d_library:simple_d_library",
    ],
)

d_test(
    name = "deps_only_library_test",
    srcs = ["test.d"],
    deps = [":deps_only_library"],
)