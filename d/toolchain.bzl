load("@bazel_skylib//rules:common_settings.bzl", "string_setting")
load("//d:config.bzl", "DToolchainConfigInfo")

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
    config = ctx.attr.config[DToolchainConfigInfo] if ctx.attr.config else None
    if config == None:
        # TODO: deprecate this
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
            common_flags = ctx.attr.common_flags,
            fastbuild_flags = ctx.attr.fastbuild_flags,
            dbg_flags = ctx.attr.dbg_flags,
            opt_flags = ctx.attr.opt_flags,
            hdrgen_flags = ctx.attr.hdrgen_flags,
            global_versions_common = [],
            global_versions_per_mode = {
                "fastbuild": [],
                "dbg": [],
                "opt": [],
            },
        )
    else:
        toolchain_info = platform_common.ToolchainInfo(
            name = ctx.attr.name,
            d_compiler = config.d_compiler or ctx.attr.d_compiler,
            c_compiler = config.c_compiler or ctx.attr.c_compiler,
            lib_flags = config.lib_flags or ctx.attr.lib_flags,
            link_flags = (config.linkopts_common + config.linkopts_per_mode[ctx.var["COMPILATION_MODE"]]) or ctx.attr.link_flags,
            import_flags = config.import_flags or ctx.attr.import_flags,
            libphobos = config.libphobos or ctx.attr.libphobos,
            libphobos_src = config.libphobos_src or ctx.attr.libphobos_src,
            druntime = config.druntime or ctx.attr.druntime,
            druntime_src = config.druntime_src or ctx.attr.druntime_src,
            version_flag = config.version_flag or ctx.attr.version_flag,
            common_flags = config.common_flags or ctx.attr.common_flags,
            fastbuild_flags = config.copts_per_mode["fastbuild"] or ctx.attr.fastbuild_flags,
            dbg_flags = config.copts_per_mode["dbg"] or ctx.attr.dbg_flags,
            opt_flags = config.copts_per_mode["opt"] or ctx.attr.opt_flags,
            hdrgen_flags = config.hdrgen_flags,
            global_versions_common = config.global_versions_common,
            global_versions_per_mode = config.global_versions_per_mode,
        )
    return [toolchain_info]

d_toolchain = rule(
    _d_toolchain_impl,
    attrs = {
        "d_compiler": attr.label(
            executable = True,
            # allow_files = True,
            cfg = "exec",
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
        "common_flags": attr.string_list(),
        "fastbuild_flags": attr.string_list(),
        "dbg_flags": attr.string_list(),
        "opt_flags": attr.string_list(),
        "hdrgen_flags": attr.string_list(),
        "config": attr.label(
            providers = [DToolchainConfigInfo],
        ),
    },
)
