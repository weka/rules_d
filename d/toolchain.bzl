"""This module implements the D toolchain rule.
"""

load("//d:config.bzl", "DToolchainConfigInfo")

DToolchainInfo = provider(
    doc = "D compiler information.",
    fields = {
        # Legacy fields (kept for backward compatibility)
        "compiler_flags": "Default compiler flags.",
        "d_compiler": "The D compiler executable.",
        "dub_tool": "The dub package manager executable.",
        "linker_flags": "Default linker flags.",
        "rdmd_tool": "The rdmd compile and execute utility.",

        # New configuration fields
        "c_compiler": "The C compiler (for linking).",
        "llc_compiler": "The LLC compiler (for bitcode).",
        "copts_common": "Common compilation flags (list).",
        "copts_per_mode": "Compilation flags per mode (dict: mode -> list).",
        "linkopts_common": "Common linker flags (list).",
        "linkopts_per_mode": "Linker flags per mode (dict: mode -> list).",
        "codegen_opts_common": "Common code generation flags for LLC (list).",
        "codegen_opts_per_mode": "Code generation flags per mode (dict: mode -> list).",
        "global_versions_common": "Common version identifiers (list).",
        "global_versions_per_mode": "Version identifiers per mode (dict: mode -> list).",
        "lib_flags": "Flags for library creation (list).",
        "import_flags": "Flags for import paths (list).",
        "version_flag": "Flag prefix for version identifiers (string).",
        "hdrgen_flags": "Flags for header generation (list).",
        "output_bc_flags": "Flags for bitcode output (list).",
        "debug_repo_root_override": "Override for debug symbol paths (string).",
        "single_object": "Default for single object mode (bool).",
        "compile_via_bc": "Default for bitcode compilation (bool).",
        "fat_lto": "Default for Fat LTO (bool).",
        "libphobos": "Phobos library file.",
        "libphobos_src": "Phobos source files.",
        "druntime": "D runtime library file.",
        "druntime_src": "D runtime source files.",
    },
)

def _expand_toolchain_variables(ctx, input, config = None):
    """Expand toolchain variables in the input string."""
    # Get d_compiler_root from either the config or the legacy attribute
    if config and config.d_compiler:
        d_compiler_root = config.d_compiler.label.workspace_root
    elif ctx.attr.d_compiler:
        d_compiler_root = ctx.attr.d_compiler.label.workspace_root
    else:
        d_compiler_root = ""
    return input.format(D_COMPILER_ROOT = d_compiler_root)

def _d_toolchain_impl(ctx):
    # Check if we're using the new config-based approach or legacy approach
    if ctx.attr.config:
        config = ctx.attr.config[DToolchainConfigInfo]

        # Collect files from config
        d_compiler_files = []
        dub_tool_files = []
        rdmd_tool_files = []

        if config.d_compiler:
            d_compiler_files = config.d_compiler.files.to_list() + config.d_compiler.default_runfiles.files.to_list()
        if config.dub_tool:
            dub_tool_files = config.dub_tool.files.to_list() + config.dub_tool.default_runfiles.files.to_list()
        if config.rdmd_tool:
            rdmd_tool_files = config.rdmd_tool.files.to_list() + config.rdmd_tool.default_runfiles.files.to_list()

        # Make the $(tool_BIN) variable available in places like genrules.
        template_variables = platform_common.TemplateVariableInfo({
            "DC": config.d_compiler.files_to_run.executable.path,
            "DUB": config.dub_tool.files_to_run.executable.path if config.dub_tool else "",
        })

        default = DefaultInfo(
            files = depset(d_compiler_files + dub_tool_files + rdmd_tool_files),
            runfiles = ctx.runfiles(files = d_compiler_files + dub_tool_files + rdmd_tool_files),
        )

        # Create DToolchainInfo with all config fields
        d_toolchain_info = DToolchainInfo(
            # Legacy fields (for backward compatibility)
            compiler_flags = config.copts_common,
            d_compiler = config.d_compiler,
            dub_tool = config.dub_tool,
            linker_flags = config.linkopts_common,
            rdmd_tool = config.rdmd_tool,
            # New configuration fields
            c_compiler = config.c_compiler,
            llc_compiler = config.llc_compiler,
            copts_common = config.copts_common,
            copts_per_mode = config.copts_per_mode,
            linkopts_common = config.linkopts_common,
            linkopts_per_mode = config.linkopts_per_mode,
            codegen_opts_common = config.codegen_opts_common,
            codegen_opts_per_mode = config.codegen_opts_per_mode,
            global_versions_common = config.global_versions_common,
            global_versions_per_mode = config.global_versions_per_mode,
            lib_flags = config.lib_flags,
            import_flags = config.import_flags,
            version_flag = config.version_flag,
            hdrgen_flags = config.hdrgen_flags,
            output_bc_flags = config.output_bc_flags,
            debug_repo_root_override = config.debug_repo_root_override,
            single_object = config.single_object,
            compile_via_bc = config.compile_via_bc,
            fat_lto = config.fat_lto,
            libphobos = config.libphobos,
            libphobos_src = config.libphobos_src,
            druntime = config.druntime,
            druntime_src = config.druntime_src,
        )

        toolchain_info = platform_common.ToolchainInfo(
            default = default,
            d_toolchain_info = d_toolchain_info,
            template_variables = template_variables,
        )
        return [
            default,
            toolchain_info,
            template_variables,
        ]
    else:
        # Legacy path: use old attributes
        d_compiler_files = []
        dub_tool_files = []
        rdmd_tool_files = []

        if ctx.attr.d_compiler:
            d_compiler_files = ctx.attr.d_compiler.files.to_list() + ctx.attr.d_compiler.default_runfiles.files.to_list()
        if ctx.attr.dub_tool:
            dub_tool_files = ctx.attr.dub_tool.files.to_list() + ctx.attr.dub_tool.default_runfiles.files.to_list()
        if ctx.attr.rdmd_tool:
            rdmd_tool_files = ctx.attr.rdmd_tool.files.to_list() + ctx.attr.rdmd_tool.default_runfiles.files.to_list()

        # Make the $(tool_BIN) variable available in places like genrules.
        template_variables = platform_common.TemplateVariableInfo({
            "DC": ctx.attr.d_compiler.files_to_run.executable.path,
            "DUB": ctx.attr.dub_tool.files_to_run.executable.path if ctx.attr.dub_tool else "",
        })

        default = DefaultInfo(
            files = depset(d_compiler_files + dub_tool_files + rdmd_tool_files),
            runfiles = ctx.runfiles(files = d_compiler_files + dub_tool_files + rdmd_tool_files),
        )
        d_toolchain_info = DToolchainInfo(
            compiler_flags = [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.compiler_flags],
            d_compiler = ctx.attr.d_compiler,
            dub_tool = ctx.attr.dub_tool,
            linker_flags = [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.linker_flags],
            rdmd_tool = ctx.attr.rdmd_tool,
            # Provide default values for new fields
            c_compiler = None,
            llc_compiler = None,
            copts_common = [],
            copts_per_mode = {},
            linkopts_common = [],
            linkopts_per_mode = {},
            codegen_opts_common = [],
            codegen_opts_per_mode = {},
            global_versions_common = [],
            global_versions_per_mode = {},
            lib_flags = ["-lib"],
            import_flags = ["-I"],
            version_flag = "-version=",
            hdrgen_flags = [],
            output_bc_flags = [],
            debug_repo_root_override = "",
            single_object = True,
            compile_via_bc = False,
            fat_lto = False,
            libphobos = None,
            libphobos_src = [],
            druntime = None,
            druntime_src = [],
        )

        # Export all the providers inside our ToolchainInfo
        # so the resolved_toolchain rule can grab and re-export them.
        toolchain_info = platform_common.ToolchainInfo(
            default = default,
            d_toolchain_info = d_toolchain_info,
            template_variables = template_variables,
        )
        return [
            default,
            toolchain_info,
            template_variables,
        ]

d_toolchain = rule(
    implementation = _d_toolchain_impl,
    attrs = {
        # New config-based attribute
        "config": attr.label(
            doc = """Toolchain configuration provider.

            When specified, this takes precedence over legacy attributes.
            Allows separating compiler-specific configuration from toolchain definition.
            """,
            providers = [DToolchainConfigInfo],
        ),

        # Legacy attributes (for backward compatibility)
        "compiler_flags": attr.string_list(
            doc = "Compiler flags (legacy, use config instead).",
        ),
        "d_compiler": attr.label(
            doc = "The D compiler (legacy, use config instead).",
            executable = True,
            cfg = "exec",
        ),
        "dub_tool": attr.label(
            doc = "The dub package manager (legacy, use config instead).",
            executable = True,
            cfg = "exec",
        ),
        "linker_flags": attr.string_list(
            doc = "Linker flags (legacy, use config instead).",
        ),
        "rdmd_tool": attr.label(
            doc = "The rdmd compile and execute utility (legacy, use config instead).",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """Defines a d compiler/runtime toolchain.

For usage see https://docs.bazel.build/versions/main/toolchains.html#defining-toolchains.

New usage with config:
    d_toolchain_config(
        name = "ldc_config",
        d_compiler = ":ldc2",
        ...
    )

    d_toolchain(
        name = "ldc_toolchain",
        config = ":ldc_config",
    )

Legacy usage (deprecated):
    d_toolchain(
        name = "toolchain",
        d_compiler = ":dmd",
        compiler_flags = [...],
        linker_flags = [...],
    )
""",
)
