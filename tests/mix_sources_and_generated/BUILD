load("//d:d.bzl", "d_binary", "d_library")

genrule(
    name = "generate_b",
    srcs = ["b.d"],
    outs = ["b_generated.d"],
    cmd = "cat $< > $@",
)

d_library(
    name = "lib",
    srcs = ["a.d", ":generate_b"],
    generated_srcs = {
        ":generate_b": "b.d",
    },
)

d_library(
    name = "lib_no_map",
    srcs = ["a.d", ":generate_b"],
)

d_binary(
    name = "bin",
    srcs = ["main.d"],
    deps = [
        ":lib",
    ],
)

# This is expected to fail because the generated source file is not mapped
d_binary(
    name = "bin_no_map",
    srcs = ["main.d"],
    deps = [
        ":lib_no_map",
    ],
    tags = ["manual"],
)