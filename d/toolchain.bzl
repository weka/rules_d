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
    if not ctx.attr.config:
        fail("config attribute is required")
    config = ctx.attr.config[DToolchainConfigInfo]
    toolchain_info = platform_common.ToolchainInfo(
        name = ctx.attr.name,
        d_compiler = config.d_compiler,
        c_compiler = config.c_compiler,
        llc_compiler = config.llc_compiler,
        lib_flags = config.lib_flags,
        link_flags = (config.linkopts_common + config.linkopts_per_mode[ctx.var["COMPILATION_MODE"]]),
        import_flags = config.import_flags,
        libphobos = config.libphobos,
        libphobos_src = config.libphobos_src,
        druntime = config.druntime,
        druntime_src = config.druntime_src,
        version_flag = config.version_flag,
        common_flags = config.copts_common,
        fastbuild_flags = config.copts_per_mode["fastbuild"],
        dbg_flags = config.copts_per_mode["dbg"],
        opt_flags = config.copts_per_mode["opt"],
        codegen_common_flags = config.codegen_opts_common,
        codegen_per_mode_flags = config.codegen_opts_per_mode,
        hdrgen_flags = config.hdrgen_flags,
        output_bc_flags = config.output_bc_flags,
        global_versions_common = config.global_versions_common,
        global_versions_per_mode = config.global_versions_per_mode,
        debug_repo_root_override = config.debug_repo_root_override,
        compile_via_bc = config.compile_via_bc,
        fat_lto = config.fat_lto,
    )
    return [toolchain_info]

d_toolchain = rule(
    _d_toolchain_impl,
    attrs = {
        "config": attr.label(
            providers = [DToolchainConfigInfo],
        ),
    },
)
