load("//d:d.bzl", "d_library", "d_test_library", "d_test")

d_test_library(
    name = "testlib",
    srcs = ["testlib.d"],   
)

d_library(
    name = "main",
    srcs = ["main.d"],
)

d_test(
    name = "test",
    srcs = [],
    deps = [
        ":main",
        ":testlib",
    ],
)