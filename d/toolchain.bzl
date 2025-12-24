"""This module implements the D toolchain rule.
"""

load("//d:config.bzl", "DToolchainConfigInfo")

DToolchainInfo = provider(
    doc = "D compiler information.",
    fields = {
        # Legacy fields (kept for backward compatibility)
        "compiler_flags": "Default compiler flags.",
        "d_compiler": "The D compiler executable.",
        "druntime": "The D runtime library. (LDC only)",
        "dub_tool": "The dub package manager executable.",
        "libphobos": "The Phobos library.",
        "linker_flags": "Default linker flags.",
        "rdmd_tool": "The rdmd compile and execute utility.",

        # New configuration fields
        "c_compiler": "The C compiler (for linking).",
        "llc_compiler": "The LLC compiler (for bitcode).",
        "ar_tool": "The ar archiver tool (for bitcode).",
        "compiler_flags_per_mode": "Compilation flags per mode (dict: mode -> list).",
        "linker_flags_per_mode": "Linker flags per mode (dict: mode -> list).",
        "codegen_opts_common": "Common code generation flags for LLC (list).",
        "codegen_opts_per_mode": "Code generation flags per mode (dict: mode -> list).",
        "global_versions_common": "Common version identifiers (list).",
        "global_versions_per_mode": "Version identifiers per mode (dict: mode -> list).",
        "lib_flags": "Flags for library creation (list).",
        "single_obj_flag": "Flag for single object mode (string, optional).",
        "import_flags": "Flags for import paths (list).",
        "version_flag": "Flag prefix for version identifiers (string).",
        "hdrgen_flags": "Flags for header generation (list).",
        "output_bc_flags": "Flags for bitcode output (list).",
        "qualified_object_file_names": "Enable qualified object file names with --oq (bool).",
        "debug_repo_root_override": "Override for debug symbol paths (string).",
        "single_object": "Default for single object mode (bool).",
        "compile_via_bc": "Default for bitcode compilation (bool).",
        "fat_lto": "Default for Fat LTO (bool).",
        "generate_headers": "Default for automatic header generation (bool).",
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

def _expand_toolchain_variables_in_flags(ctx, flags, config = None):
    return [_expand_toolchain_variables(ctx, flag, config) for flag in flags]

def _expand_toolchain_variables_in_flags_per_mode(ctx, flags_per_mode, config = None):
    return {mode: _expand_toolchain_variables_in_flags(ctx, flags, config) for mode, flags in flags_per_mode.items()}

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

        default = DefaultInfo(
            files = depset(d_compiler_files + dub_tool_files + rdmd_tool_files),
            runfiles = ctx.runfiles(files = d_compiler_files + dub_tool_files + rdmd_tool_files),
        )

        # Create DToolchainInfo with all config fields
        d_toolchain_info = DToolchainInfo(
            # Legacy fields (for backward compatibility)
            compiler_flags = _expand_toolchain_variables_in_flags(ctx, config.compiler_flags, config),
            d_compiler = config.d_compiler,
            dub_tool = config.dub_tool,
            linker_flags = _expand_toolchain_variables_in_flags(ctx, config.linker_flags, config),
            rdmd_tool = config.rdmd_tool,
            # New configuration fields
            c_compiler = config.c_compiler,
            llc_compiler = config.llc_compiler,
            ar_tool = config.ar_tool,
            compiler_flags_per_mode = _expand_toolchain_variables_in_flags_per_mode(ctx, config.compiler_flags_per_mode, config),
            linker_flags_per_mode = _expand_toolchain_variables_in_flags_per_mode(ctx, config.linker_flags_per_mode, config),
            codegen_opts_common = _expand_toolchain_variables_in_flags(ctx, config.codegen_opts_common, config),
            codegen_opts_per_mode = _expand_toolchain_variables_in_flags_per_mode(ctx, config.codegen_opts_per_mode, config),
            global_versions_common = _expand_toolchain_variables_in_flags(ctx, config.global_versions_common, config),
            global_versions_per_mode = _expand_toolchain_variables_in_flags_per_mode(ctx, config.global_versions_per_mode, config),
            lib_flags = config.lib_flags,
            single_obj_flag = config.single_obj_flag,
            import_flags = config.import_flags,
            version_flag = config.version_flag,
            hdrgen_flags = config.hdrgen_flags,
            output_bc_flags = config.output_bc_flags,
            qualified_object_file_names = config.qualified_object_file_names,
            debug_repo_root_override = config.debug_repo_root_override,
            single_object = config.single_object,
            compile_via_bc = config.compile_via_bc,
            fat_lto = config.fat_lto,
            generate_headers = config.generate_headers,
            libphobos = config.libphobos,
            druntime = config.druntime,
        )

        # Make the $(tool_BIN) variable available in places like genrules.
        template_variables = platform_common.TemplateVariableInfo({
            "DC": config.d_compiler.files_to_run.executable.path,
            "DUB": config.dub_tool.files_to_run.executable.path if config.dub_tool else "",
        })

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
            compiler_flags = _expand_toolchain_variables_in_flags(ctx, ctx.attr.compiler_flags),
            d_compiler = ctx.attr.d_compiler,
            dub_tool = ctx.attr.dub_tool,
            linker_flags = _expand_toolchain_variables_in_flags(ctx, ctx.attr.linker_flags),
            rdmd_tool = ctx.attr.rdmd_tool,
            # Provide default values for new fields
            c_compiler = None,
            llc_compiler = None,
            ar_tool = None,
            compiler_flags_per_mode = {},
            linker_flags_per_mode = {},
            codegen_opts_common = [],
            codegen_opts_per_mode = {},
            global_versions_common = [],
            global_versions_per_mode = {},
            lib_flags = ["-lib"],
            single_obj_flag = "",
            import_flags = ["-I"],
            version_flag = "-version=",
            hdrgen_flags = [],
            output_bc_flags = [],
            qualified_object_file_names = False,
            debug_repo_root_override = "",
            single_object = True,
            compile_via_bc = False,
            fat_lto = False,
            generate_headers = False,
            libphobos = None,
            druntime = None,
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
        "druntime": attr.label(
            doc = "The D runtime library.",
        ),
        "dub_tool": attr.label(
            doc = "The dub package manager (legacy, use config instead).",
            executable = True,
            cfg = "exec",
        ),
        "libphobos": attr.label(
            doc = "The Phobos library.",
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
