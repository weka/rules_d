"""Configuration provider for D toolchain.

This module defines the DToolchainConfigInfo provider and d_toolchain_config rule,
which separate compiler-specific configuration from the toolchain rule itself.
This provides flexibility to define multiple configurations for the same compiler.
"""

DToolchainConfigInfo = provider(
    doc = """Configuration for D toolchain.

    This provider contains all compiler-specific settings including binaries,
    libraries, flags, and compilation modes. It allows separating configuration
    from toolchain definition, enabling multiple configs per compiler.
    """,
    fields = {
        # Compiler binaries
        "d_compiler": "Path to D compiler executable",
        "c_compiler": "Path to C compiler (for linking), optional",
        "llc_compiler": "Path to LLC compiler (for bitcode compilation), optional",

        # Tools
        "dub_tool": "The dub package manager executable, optional",
        "rdmd_tool": "The rdmd compile and execute utility, optional",

        # Standard libraries
        "libphobos": "Phobos library file, optional",
        "libphobos_src": "Phobos source files, optional",
        "druntime": "D runtime library file, optional",
        "druntime_src": "D runtime source files, optional",

        # Common flags (applied to all builds)
        "copts_common": "Common compilation flags (list)",
        "linkopts_common": "Common linker flags (list)",
        "codegen_opts_common": "Common code generation flags for LLC (list)",
        "global_versions_common": "Common version identifiers (list)",

        # Per-mode flags (indexed by compilation mode: fastbuild, dbg, opt)
        "copts_per_mode": "Compilation flags per mode (dict: mode -> list)",
        "linkopts_per_mode": "Linker flags per mode (dict: mode -> list)",
        "codegen_opts_per_mode": "Code generation flags per mode (dict: mode -> list)",
        "global_versions_per_mode": "Version identifiers per mode (dict: mode -> list)",

        # Special flags
        "lib_flags": "Flags for library creation (list)",
        "import_flags": "Flags for import paths (list)",
        "version_flag": "Flag prefix for version identifiers (string)",
        "hdrgen_flags": "Flags for header generation (list)",
        "output_bc_flags": "Flags for bitcode output (list)",

        # Debug settings
        "debug_repo_root_override": "Override for debug symbol paths (string)",

        # Default modes
        "single_object": "Default for single object mode (bool)",
        "compile_via_bc": "Default for bitcode compilation (bool)",
        "fat_lto": "Default for Fat LTO (bool)",
    },
)

def _expand_toolchain_variables(ctx, input):
    """Expand toolchain variables in the input string."""
    d_compiler_root = ctx.attr.d_compiler.label.workspace_root if ctx.attr.d_compiler else ""
    return input.format(D_COMPILER_ROOT = d_compiler_root)

def _d_toolchain_config_impl(ctx):
    """Implementation of the d_toolchain_config rule.

    Args:
        ctx: The rule context.

    Returns:
        List containing DToolchainConfigInfo provider.
    """
    # Expand variables in flags
    copts_common = [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.copts_common]
    linkopts_common = [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.linkopts_common]

    # Process per-mode flags
    copts_per_mode = {
        "fastbuild": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.fastbuild_copts],
        "dbg": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.dbg_copts],
        "opt": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.opt_copts],
    }

    linkopts_per_mode = {
        "fastbuild": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.fastbuild_linkopts],
        "dbg": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.dbg_linkopts],
        "opt": [_expand_toolchain_variables(ctx, flag) for flag in ctx.attr.opt_linkopts],
    }

    codegen_opts_per_mode = {
        "fastbuild": ctx.attr.fastbuild_codegen_opts,
        "dbg": ctx.attr.dbg_codegen_opts,
        "opt": ctx.attr.opt_codegen_opts,
    }

    global_versions_per_mode = {
        "fastbuild": ctx.attr.fastbuild_versions,
        "dbg": ctx.attr.dbg_versions,
        "opt": ctx.attr.opt_versions,
    }

    return [
        DToolchainConfigInfo(
            d_compiler = ctx.attr.d_compiler,
            c_compiler = ctx.attr.c_compiler,
            llc_compiler = ctx.attr.llc_compiler,
            dub_tool = ctx.attr.dub_tool,
            rdmd_tool = ctx.attr.rdmd_tool,
            libphobos = ctx.file.libphobos if ctx.attr.libphobos else None,
            libphobos_src = ctx.files.libphobos_src,
            druntime = ctx.file.druntime if ctx.attr.druntime else None,
            druntime_src = ctx.files.druntime_src,
            copts_common = copts_common,
            linkopts_common = linkopts_common,
            codegen_opts_common = ctx.attr.codegen_opts_common,
            global_versions_common = ctx.attr.global_versions_common,
            copts_per_mode = copts_per_mode,
            linkopts_per_mode = linkopts_per_mode,
            codegen_opts_per_mode = codegen_opts_per_mode,
            global_versions_per_mode = global_versions_per_mode,
            lib_flags = ctx.attr.lib_flags,
            import_flags = ctx.attr.import_flags,
            version_flag = ctx.attr.version_flag,
            hdrgen_flags = ctx.attr.hdrgen_flags,
            output_bc_flags = ctx.attr.output_bc_flags,
            debug_repo_root_override = ctx.attr.debug_repo_root_override,
            single_object = ctx.attr.single_object,
            compile_via_bc = ctx.attr.compile_via_bc,
            fat_lto = ctx.attr.fat_lto,
        ),
    ]

d_toolchain_config = rule(
    implementation = _d_toolchain_config_impl,
    doc = """Defines a D toolchain configuration.

    This rule creates a DToolchainConfigInfo provider that contains all
    compiler-specific settings. Multiple configurations can be created for
    the same compiler with different optimization levels, debug settings, etc.

    Example:
        d_toolchain_config(
            name = "ldc_config",
            d_compiler = ":ldc2_compiler",
            c_compiler = "@local_config_cc//:cc_compiler",
            copts_common = ["-w"],  # Enable warnings
            dbg_copts = ["-g", "-d-debug"],
            opt_copts = ["-O3", "-release"],
        )
    """,
    attrs = {
        # Compiler binaries
        "d_compiler": attr.label(
            mandatory = True,
            doc = "The D compiler executable",
            executable = True,
            cfg = "exec",
        ),
        "c_compiler": attr.label(
            doc = "C compiler for linking (optional)",
            executable = True,
            cfg = "exec",
        ),
        "llc_compiler": attr.label(
            doc = "LLC compiler for bitcode compilation (optional)",
            executable = True,
            cfg = "exec",
        ),

        # Tools
        "dub_tool": attr.label(
            doc = "The dub package manager (optional)",
            executable = True,
            cfg = "exec",
        ),
        "rdmd_tool": attr.label(
            doc = "The rdmd compile and execute utility (optional)",
            executable = True,
            cfg = "exec",
        ),

        # Standard libraries
        "libphobos": attr.label(
            doc = "Phobos library file",
            allow_single_file = True,
        ),
        "libphobos_src": attr.label_list(
            doc = "Phobos source files",
            allow_files = True,
        ),
        "druntime": attr.label(
            doc = "D runtime library file",
            allow_single_file = True,
        ),
        "druntime_src": attr.label_list(
            doc = "D runtime source files",
            allow_files = True,
        ),

        # Common flags (applied to all compilation modes)
        "copts_common": attr.string_list(
            default = [],
            doc = "Common compilation flags",
        ),
        "linkopts_common": attr.string_list(
            default = [],
            doc = "Common linker flags",
        ),
        "codegen_opts_common": attr.string_list(
            default = [],
            doc = "Common code generation flags for LLC",
        ),
        "global_versions_common": attr.string_list(
            default = [],
            doc = "Common version identifiers",
        ),

        # Per-mode compilation flags
        "fastbuild_copts": attr.string_list(
            default = [],
            doc = "Compilation flags for fastbuild mode",
        ),
        "dbg_copts": attr.string_list(
            default = ["-g", "-d-debug", "-d-version=debug_assert"],
            doc = "Compilation flags for debug mode",
        ),
        "opt_copts": attr.string_list(
            default = ["-O", "-release"],
            doc = "Compilation flags for optimized mode",
        ),

        # Per-mode linker flags
        "fastbuild_linkopts": attr.string_list(
            default = [],
            doc = "Linker flags for fastbuild mode",
        ),
        "dbg_linkopts": attr.string_list(
            default = [],
            doc = "Linker flags for debug mode",
        ),
        "opt_linkopts": attr.string_list(
            default = [],
            doc = "Linker flags for optimized mode",
        ),

        # Per-mode code generation flags
        "fastbuild_codegen_opts": attr.string_list(
            default = [],
            doc = "Code generation flags for fastbuild mode",
        ),
        "dbg_codegen_opts": attr.string_list(
            default = [],
            doc = "Code generation flags for debug mode",
        ),
        "opt_codegen_opts": attr.string_list(
            default = ["-O3"],
            doc = "Code generation flags for optimized mode",
        ),

        # Per-mode version identifiers
        "fastbuild_versions": attr.string_list(
            default = [],
            doc = "Version identifiers for fastbuild mode",
        ),
        "dbg_versions": attr.string_list(
            default = [],
            doc = "Version identifiers for debug mode",
        ),
        "opt_versions": attr.string_list(
            default = [],
            doc = "Version identifiers for optimized mode",
        ),

        # Special flags
        "lib_flags": attr.string_list(
            default = ["-lib"],
            doc = "Flags for library creation",
        ),
        "import_flags": attr.string_list(
            default = ["-I"],
            doc = "Flags for import paths",
        ),
        "version_flag": attr.string(
            default = "-version=",
            doc = "Flag prefix for version identifiers",
        ),
        "hdrgen_flags": attr.string_list(
            default = [],
            doc = "Flags for header generation",
        ),
        "output_bc_flags": attr.string_list(
            default = [],
            doc = "Flags for bitcode output (LDC only)",
        ),

        # Debug settings
        "debug_repo_root_override": attr.string(
            default = "",
            doc = "Override for debug symbol paths",
        ),

        # Default modes
        "single_object": attr.bool(
            default = True,
            doc = "Default for single object mode",
        ),
        "compile_via_bc": attr.bool(
            default = False,
            doc = "Default for bitcode compilation",
        ),
        "fat_lto": attr.bool(
            default = False,
            doc = "Default for Fat LTO",
        ),
    },
)
