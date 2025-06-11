load("//d:d.bzl", "d_binary", "d_library")

d_library(
    name = "lib",
    srcs = ["lib.d"],
    data = ["imports/test.txt"],
    string_imports = ["imports"],
)

d_binary(
    name = "main",
    srcs = ["main.d"],
    deps = [
        ":lib",
    ]
)