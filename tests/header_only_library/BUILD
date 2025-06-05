load("//d:d.bzl", "d_library", "d_test")

package(
    default_visibility = ["//visibility:public"],
)

d_library(
    name = "header_only_library",
    srcs = [],
    hdrs = ["lib.di"],
)

d_test(
    name = "header_only_library_test",
    srcs = ["header_only_library_test.d"],
    deps = [":header_only_library"],
)