load("@bazel_skylib//rules:common_settings.bzl", "string_setting")

D_TOOLCHAIN = "//d:toolchain_type"

# string_setting(
#     name = "compiler_type",
#     values = [
#         "dmd",
#         "ldc",
#     ],
# )
# 
# config_setting(
#     name = "dmd",
#     flag_values = {
#         ":compiler_type": "dmd",
#     },
# )
# 
# config_setting(
#     name = "ldc",
#     flag_values = {
#         ":compiler_type": "ldc",
#     },
# )

def _d_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        name = ctx.label.name,
        d_compiler = ctx.attr.d_compiler,
        c_compiler = ctx.attr.c_compiler,
        lib_flags = ctx.attr.lib_flags,
        link_flags = ctx.attr.link_flags,
        import_flags = ctx.attr.import_flags,
        libphobos = ctx.attr.libphobos,
        libphobos_src = ctx.attr.libphobos_src,
        druntime = ctx.attr.druntime,
        druntime_src = ctx.attr.druntime_src,
        version_flag = ctx.attr.version_flag,
        fastbuild_flags = ctx.attr.fastbuild_flags,
        dbg_flags = ctx.attr.dbg_flags,
        opt_flags = ctx.attr.opt_flags,
        hdrgen_flags = ctx.attr.hdrgen_flags,
    )
    return [toolchain_info]

d_toolchain = rule(
    _d_toolchain_impl,
    attrs = {
        "d_compiler": attr.label(
            executable = True,
            # allow_files = True,
            cfg = "host",
        ),
        "c_compiler": attr.label(
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "lib_flags": attr.string_list(
            default = ["-lib"],
        ),
        "link_flags": attr.string_list(
            default = [],
        ),
        "import_flags": attr.string_list(),
        "libphobos": attr.label(),
        "libphobos_src": attr.label(),
        "druntime": attr.label(),
        "druntime_src": attr.label(),
        "version_flag": attr.string(),
        "fastbuild_flags": attr.string_list(),
        "dbg_flags": attr.string_list(),
        "opt_flags": attr.string_list(),
        "hdrgen_flags": attr.string_list(),
    },
)
