"""
Configuration information for the D toolchain.
"""

DToolchainConfigInfo = provider(
    doc = "Configuration information for the D toolchain.",
    fields = [
        # binaries
        "d_compiler",
        "c_compiler",
        "llc_compiler",
        # libraries
        "libphobos",
        "libphobos_src",
        "druntime",
        "druntime_src",
        # flags that can differ for different toolchains
        "lib_flags",
        "import_flags",  # unused
        "version_flag",
        "hdrgen_flags",
        "output_bc_flags",
        # compilation modes
        "copts_per_mode",
        "copts_common",
        "linkopts_per_mode",
        "linkopts_common",
        "codegen_opts_common",
        "codegen_opts_per_mode",
        "global_versions_per_mode",
        "global_versions_common",
        "debug_repo_root_override",
    ],
)

def _d_toolchain_config_impl(ctx):
    return [DToolchainConfigInfo(
        d_compiler = ctx.attr.d_compiler,
        c_compiler = ctx.attr.c_compiler,
        llc_compiler = ctx.attr.llc_compiler,
        libphobos = ctx.attr.libphobos,
        libphobos_src = ctx.attr.libphobos_src,
        druntime = ctx.attr.druntime,
        druntime_src = ctx.attr.druntime_src,
        lib_flags = ctx.attr.lib_flags,
        import_flags = ctx.attr.import_flags,
        version_flag = ctx.attr.version_flag,
        hdrgen_flags = ctx.attr.hdrgen_flags,
        output_bc_flags = ctx.attr.output_bc_flags,
        copts_common = ctx.attr.common_flags,
        copts_per_mode = {
            "fastbuild": ctx.attr.fastbuild_flags,
            "dbg": ctx.attr.dbg_flags,
            "opt": ctx.attr.opt_flags,
        },
        linkopts_common = ctx.attr.link_flags,
        linkopts_per_mode = {
            "fastbuild": ctx.attr.link_flags_fastbuild,
            "dbg": ctx.attr.link_flags_dbg,
            "opt": ctx.attr.link_flags_opt,
        },
        codegen_opts_common = ctx.attr.codegen_common_flags,
        codegen_opts_per_mode = {
            "fastbuild": ctx.attr.codegen_fastbuild_flags,
            "dbg": ctx.attr.codegen_dbg_flags,
            "opt": ctx.attr.codegen_opt_flags,
        },
        global_versions_common = ctx.attr.global_versions_common,    
        global_versions_per_mode = {
            "fastbuild": ctx.attr.global_versions_fastbuild,
            "dbg": ctx.attr.global_versions_dbg,
            "opt": ctx.attr.global_versions_opt,
        },
        debug_repo_root_override = ctx.attr.debug_repo_root_override,
    )]

d_toolchain_config = rule(
    _d_toolchain_config_impl,
    attrs = {
        "d_compiler": attr.label(
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "c_compiler": attr.label(
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
        "llc_compiler": attr.label(
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
        "link_flags_dbg": attr.string_list(
            default = [],
        ),
        "link_flags_opt": attr.string_list(
            default = [],
        ),
        "link_flags_fastbuild": attr.string_list(
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
        "codegen_common_flags": attr.string_list(default = []),
        "codegen_fastbuild_flags": attr.string_list(),
        "codegen_dbg_flags": attr.string_list(),
        "codegen_opt_flags": attr.string_list(),
        "global_versions_common": attr.string_list(),
        "global_versions_fastbuild": attr.string_list(),
        "global_versions_dbg": attr.string_list(),
        "global_versions_opt": attr.string_list(),
        "hdrgen_flags": attr.string_list(),
        "output_bc_flags": attr.string_list(),
        "debug_repo_root_override": attr.string(),
    },
)
