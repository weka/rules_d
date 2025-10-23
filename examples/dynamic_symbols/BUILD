package(default_visibility = ["//visibility:public"])

load("//d:d.bzl", "d_binary")

d_binary(
    name = "dynamic_symbols",
    srcs = ["dynamic_symbols.d"],
    dynamic_symbols = ":dynamic_symbols.txt",
    deps = [
        "//examples/hello_lib:greeter",
        "//examples/hello_lib:native_greeter",
    ],
)
