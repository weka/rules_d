package(default_visibility = ["//visibility:public"])

load("//d:toolchain.bzl", "D_TOOLCHAIN", "d_toolchain")

toolchain_type(name = "toolchain_type")

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

d_toolchain(
    name = "dmd_linux_x86_64",
    d_compiler = "@dmd_linux_x86_64//:dmd",
    libphobos = "@dmd_linux_x86_64//:libphobos2",
    libphobos_src = "@dmd_linux_x86_64//:phobos_src",
    druntime_src = "@dmd_linux_x86_64//:druntime_src",
)

toolchain(
    name = "dmd_linux_x86_64_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":dmd_linux_x86_64",
    toolchain_type = D_TOOLCHAIN,
)

