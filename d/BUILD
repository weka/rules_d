package(default_visibility = ["//visibility:public"])

load("//d:toolchain.bzl", "D_TOOLCHAIN", "d_toolchain")

toolchain_type(name = "toolchain_type")

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

[d_toolchain(
    name = "dmd_" + os + "_x86_64",
    d_compiler = "@dmd_" + os + "_x86_64//:dmd",
    druntime_src = "@dmd_" + os + "_x86_64//:druntime_src",
    libphobos = "@dmd_" + os + "_x86_64//:libphobos2",
    libphobos_src = "@dmd_" + os + "_x86_64//:phobos_src",
    version_flag = "-version",
) for os in ["linux", "darwin"]] # , "windows"]]

toolchain(
    name = "dmd_linux_x86_64_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//d/constraints/compiler:dmd",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":dmd_linux_x86_64",
    toolchain_type = D_TOOLCHAIN,
)

toolchain(
    name = "dmd_darwin_x86_64_toolchain",
    exec_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
        "//d/constraints/compiler:dmd",
    ],
    target_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":dmd_darwin_x86_64",
    toolchain_type = D_TOOLCHAIN,
)

# toolchain(
#     name = "dmd_windows_x86_64_toolchain",
#     exec_compatible_with = [
#         "@platforms//os:windows",
#         "@platforms//cpu:x86_64",
#         "//d/constraints/compiler:dmd",
#     ],
#     target_compatible_with = [
#         "@platforms//os:windows",
#         "@platforms//cpu:x86_64",
#     ],
#     toolchain = ":dmd_windows_x86_64",
#     toolchain_type = D_TOOLCHAIN,
# )

d_toolchain(
    name = "ldc_linux_x86_64",
    d_compiler = "@ldc_linux_x86_64//:ldc2",
    druntime = "@ldc_linux_x86_64//:druntime",
    druntime_src = "@ldc_linux_x86_64//:druntime_src",
    libphobos = "@ldc_linux_x86_64//:libphobos2",
    libphobos_src = "@ldc_linux_x86_64//:phobos_src",
    version_flag = "--d-version",
    lib_flags = [
        "-lib", "-oq",
    ],
)

toolchain(
    name = "ldc_linux_x86_64_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//d/constraints/compiler:ldc",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":ldc_linux_x86_64",
    toolchain_type = D_TOOLCHAIN,
)

WEKA_LDC_X86_COMMON_OPTS = [
    "-mtriple=x86_64-pc-linux-gnu",
    "-march=x86-64",
    "-mcpu=x86-64-v3",
    "-mattr=",
]

d_toolchain(
    name = "weka_ldc_linux_x86_64",
    d_compiler = "@weka_ldc_linux_x86_64//:ldc2",
    druntime = "@weka_ldc_linux_x86_64//:druntime",
    druntime_src = "@weka_ldc_linux_x86_64//:druntime_src",
    libphobos = "@weka_ldc_linux_x86_64//:libphobos2",
    libphobos_src = "@weka_ldc_linux_x86_64//:phobos_src",
    version_flag = "--d-version",
    lib_flags = [
        "-lib", "-oq",
    ],
    fastbuild_flags = ["-g"] + WEKA_LDC_X86_COMMON_OPTS,
    dbg_flags = [ "-d-debug", "-d-version=debug_assert", "-g" ] + WEKA_LDC_X86_COMMON_OPTS,
    opt_flags = ["-checkaction=halt", "-boundscheck=safeonly", "-O"] + WEKA_LDC_X86_COMMON_OPTS,
)

toolchain(
    name = "weka_ldc_linux_x86_64_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//d/constraints/compiler:weka-ldc",
    ],
    target_compatible_with = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":weka_ldc_linux_x86_64",
    toolchain_type = D_TOOLCHAIN,
)
