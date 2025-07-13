load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_skylib//lib:versions.bzl", "versions")

DMD_BUILD_FILE = "//d:DMD.bzl"
LDC_BUILD_FILE = "//d:LDC.bzl"
DMD_STRIP_PREFIX = "dmd2"

def fetch_dmd(version = None):
    if version == None:
        http_archive(
            name = "dmd_linux_x86_64",
            urls = [
                "https://downloads.dlang.org/releases/2.x/2.102.1/dmd.2.102.1.linux.tar.xz",
            ],
            sha256 = "f3f62fd7357d9c0c0349c7b96721d6734fe8285c0f32a37649d378c8abb0e9eb",
            strip_prefix = DMD_STRIP_PREFIX,
            build_file = DMD_BUILD_FILE,
        )

        http_archive(
            name = "dmd_darwin_x86_64",
            urls = [
                "https://downloads.dlang.org/releases/2.x/2.102.1/dmd.2.102.1.osx.tar.xz",
            ],
            sha256 = "300d309a2b71e95404f58e14a23daf342f47cc8608476a0b6414d356485df2bc",
            strip_prefix = DMD_STRIP_PREFIX,
            build_file = DMD_BUILD_FILE,
        )

        # http_archive(
        #     name = "dmd_windows_x86_64",
        #     urls = [
        #         "https://downloads.dlang.org/releases/2.x/2.102.1/dmd.2.102.1.windows.zip",
        #     ],
        #     sha256 = "a263ffbf6232288fa093c71a43a5cc1cd09ef5a75e7eca385ece16606c245090",
        #     strip_prefix = DMD_STRIP_PREFIX,
        #     build_file = DMD_BUILD_FILE,
        # )

    elif versions.is_at_least("2.0.0", version):
        http_archive(
            name = "dmd_linux_x86_64",
            urls = [
                "https://downloads.dlang.org/releases/2.x/{version}/dmd.{version}.linux.tar.xz".format(version = version),
            ],
            strip_prefix = DMD_STRIP_PREFIX,
            build_file = DMD_BUILD_FILE,
        )

        http_archive(
            name = "dmd_darwin_x86_64",
            urls = [
                "https://downloads.dlang.org/releases/2.x/{version}/dmd.{version}.osx.tar.xz".format(version = version),
            ],
            strip_prefix = DMD_STRIP_PREFIX,
            build_file = DMD_BUILD_FILE,
        )

        http_archive(
            name = "dmd_windows_x86_64",
            urls = [
                "https://downloads.dlang.org/releases/2.x/{version}/dmd.{version}.windows.zip".format(version = version),
            ],
            strip_prefix = DMD_STRIP_PREFIX,
            build_file = DMD_BUILD_FILE,
        )

    else:
        fail("Sorry, only DMD 2 is supported, but got %s. Maybe consider switching to D2?" % version)

def fetch_ldc(version = None):
    http_archive(
        name = "ldc_linux_x86_64",
        urls = [
            "https://github.com/ldc-developers/ldc/releases/download/v1.31.0/ldc2-1.31.0-linux-x86_64.tar.xz",
        ],
        sha256 = "7dbd44786c0772ec41890a8c03e22b0985d6ef547c40943dd56bc6be21cf4d98",
        strip_prefix = "ldc2-1.31.0-linux-x86_64",
        build_file = LDC_BUILD_FILE,
    )

def fetch_weka_ldc(version = "1.30.0-weka19"):
    http_archive(
        name = "weka_ldc_linux_x86_64",
        urls = [
            "https://github.com/weka/ldc/releases/download/v{version}/ldc2-{version}-linux-x86_64.tar.xz".format(version = version),
        ],
        sha256 = "bf15208ae97e0ee68cd66d2d18327d808c0eabc47ae2e3e9d22d110f3aae569c",
        strip_prefix = "ldc2-{version}-linux-x86_64".format(version = version),
        build_file = LDC_BUILD_FILE,
    )

def rules_d_toolchains(ctype = "dmd", version = None):
    if ctype == "dmd":
        fetch_dmd(version = version)
        fetch_ldc()
        fetch_weka_ldc()

    elif ctype == "ldc":
        fetch_dmd()
        fetch_ldc(version = version)
        fetch_weka_ldc()

    elif ctype == "weka-ldc":
        # Special case for Weka LDC, which is a fork of LDC
        fetch_weka_ldc(version = version)
        fetch_dmd()
        fetch_ldc()

    else:
        fail("Only \"dmd\", \"ldc\" and \"weka-ldc\" compilers are supported at this moment.")
