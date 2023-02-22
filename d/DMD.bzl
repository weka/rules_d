load("@bazel_skylib//rules:native_binary.bzl", "native_binary")

package(default_visibility = ["//visibility:public"])

native_binary(
    name = "dmd",
    out = "dmdcopy.exe",
    src = select({
        "@bazel_tools//src/conditions:darwin": "osx/bin/dmd",
        "@bazel_tools//src/conditions:linux_x86_64": "linux/bin64/dmd",
        "@bazel_tools//src/conditions:windows_x64": "windows/bin64/dmd.exe",
    }),
)

cc_import(
    name = "libphobos2",
    shared_library = select({
        "@bazel_tools//src/conditions:darwin": "osx/lib/dmd",
        "@bazel_tools//src/conditions:linux_x86_64": "linux/lib64/libphobos2.so",
        "@bazel_tools//src/conditions:windows_x64": "windows/lib64/dmd.exe",
    }),
    static_library = select({
        "@bazel_tools//src/conditions:darwin": "osx/lib/dmd",
        "@bazel_tools//src/conditions:linux_x86_64": "linux/lib64/libphobos2.a",
        "@bazel_tools//src/conditions:windows_x64": "windows/lib64/dmd.exe",
    }),
)

filegroup(
    name = "phobos_src",
    srcs = glob(["src/phobos/**/*.*"]),
)

filegroup(
    name = "druntime_src",
    srcs = glob([
        "src/druntime/import/*.*",
        "src/druntime/import/**/*.*",
    ]),
)
