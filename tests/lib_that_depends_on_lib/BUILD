package(default_visibility = ["//visibility:public"])

load("@rules_d//d:d.bzl", "d_library")

d_library(
    name = "lib_that_depends_on_lib",
    srcs = ["lib_that_depends_on_lib.d"],
    imports = [
        "..",
        "../simple_d_library",
    ],
    deps = [
        "//tests/simple_c_library",
        "//tests/simple_c_library:simple_c_library_wrapper",
        "//tests/simple_d_library",
    ],
)
