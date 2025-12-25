"""Configuration provider for D toolchain.

This module defines the DToolchainConfigInfo provider and d_toolchain_config rule,
which separate compiler-specific configuration from the toolchain rule itself.
This provides flexibility to define multiple configurations for the same compiler.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

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
        "ar_tool": "Path to ar archiver tool (for bitcode workflow), optional",

        # Tools
        "dub_tool": "The dub package manager executable, optional",
        "rdmd_tool": "The rdmd compile and execute utility, optional",

        # Standard libraries
        "libphobos": "Phobos library, optional",
        "libphobos_per_mode": "Phobos library per mode (dict: mode -> label, optional)",
        "druntime": "D runtime library, optional",
        "druntime_per_mode": "D runtime library per mode (LDC only, dict: mode -> label, optional)",

        # Common flags (applied to all builds)
        "compiler_flags": "Common compilation flags (list)",
        "linker_flags": "Common linker flags (list)",
        "linker_flags_for_d": "Linker flags for D compiler (list, only used for link_with_d=True)",
        "codegen_opts_common": "Common code generation flags for LLC (list)",
        "global_versions_common": "Common version identifiers (list)",

        # Per-mode flags (indexed by compilation mode: fastbuild, dbg, opt)
        "compiler_flags_per_mode": "Compilation flags per mode (dict: mode -> list)",
        "linker_flags_per_mode": "Linker flags per mode (dict: mode -> list)",
        "linker_flags_for_d_per_mode": "Linker flags for D compiler per mode (dict: mode -> list, only used for link_with_d=True)",
        "codegen_opts_per_mode": "Code generation flags per mode (dict: mode -> list)",
        "global_versions_per_mode": "Version identifiers per mode (dict: mode -> list)",

        # Special flags
        "lib_flags": "Flags for library creation (list)",
        "single_obj_flag": "Flag for single object mode (string, optional)",
        "import_flags": "Flags for import paths (list)",
        "version_flag": "Flag prefix for version identifiers (string)",
        "hdrgen_flags": "Flags for header generation (list)",
        "output_bc_flags": "Flags for bitcode output with LTO (list, e.g., ['-flto=full'])",
        "qualified_object_file_names": "Enable qualified object file names with --oq (bool)",

        # Debug settings
        "debug_repo_root_override": "Override for debug symbol paths (string)",

        # Default modes
        "single_object": "Default for single object mode (bool)",
        "compile_via_bc": "Default for bitcode compilation (bool)",
        "fat_lto": "Default for Fat LTO (bool)",
        "generate_headers": "Default for automatic header generation (bool)",
        "link_with_d": "Default for using the D compiler for linking (bool)",
    },
)

def _d_toolchain_config_impl(ctx):
    """Implementation of the d_toolchain_config rule.

    Args:
        ctx: The rule context.

    Returns:
        List containing DToolchainConfigInfo provider.
    """
    compiler_flags = ctx.attr.compiler_flags
    linker_flags = ctx.attr.linker_flags

    # Process per-mode flags
    compiler_flags_per_mode = {
        "fastbuild": ctx.attr.compiler_flags_fastbuild,
        "dbg": ctx.attr.compiler_flags_dbg,
        "opt": ctx.attr.compiler_flags_opt,
    }

    linker_flags_per_mode = {
        "fastbuild": ctx.attr.linker_flags_fastbuild,
        "dbg": ctx.attr.linker_flags_dbg,
        "opt": ctx.attr.linker_flags_opt,
    }

    linker_flags_for_d_per_mode = {
        "fastbuild": ctx.attr.linker_flags_for_d_fastbuild,
        "dbg": ctx.attr.linker_flags_for_d_dbg,
        "opt": ctx.attr.linker_flags_for_d_opt,
    }

    codegen_opts_per_mode = {
        "fastbuild": ctx.attr.codegen_opts_fastbuild,
        "dbg": ctx.attr.codegen_opts_dbg,
        "opt": ctx.attr.codegen_opts_opt,
    }

    global_versions_per_mode = {
        "fastbuild": ctx.attr.versions_fastbuild,
        "dbg": ctx.attr.versions_dbg,
        "opt": ctx.attr.versions_opt,
    }

    libphobos_per_mode = {}
    druntime_per_mode = {}
    if ctx.attr.libphobos_fastbuild:
        libphobos_per_mode["fastbuild"] = ctx.attr.libphobos_fastbuild
    if ctx.attr.libphobos_dbg:
        libphobos_per_mode["dbg"] = ctx.attr.libphobos_dbg
    if ctx.attr.libphobos_opt:
        libphobos_per_mode["opt"] = ctx.attr.libphobos_opt
    if ctx.attr.druntime_fastbuild:
        druntime_per_mode["fastbuild"] = ctx.attr.druntime_fastbuild
    if ctx.attr.druntime_dbg:
        druntime_per_mode["dbg"] = ctx.attr.druntime_dbg
    if ctx.attr.druntime_opt:
        druntime_per_mode["opt"] = ctx.attr.druntime_opt
    if ctx.attr.druntime_lto:
        druntime_per_mode["lto"] = ctx.attr.druntime_lto

    return [
        DToolchainConfigInfo(
            d_compiler = ctx.attr.d_compiler,
            c_compiler = ctx.attr.c_compiler,
            llc_compiler = ctx.attr.llc_compiler,
            ar_tool = ctx.attr.ar_tool,
            dub_tool = ctx.attr.dub_tool,
            rdmd_tool = ctx.attr.rdmd_tool,
            libphobos = ctx.attr.libphobos,
            libphobos_per_mode = libphobos_per_mode,
            druntime = ctx.attr.druntime,
            druntime_per_mode = druntime_per_mode,
            compiler_flags = compiler_flags,
            linker_flags = linker_flags,
            linker_flags_for_d = ctx.attr.linker_flags_for_d,
            codegen_opts_common = ctx.attr.codegen_opts_common,
            global_versions_common = ctx.attr.global_versions_common,
            compiler_flags_per_mode = compiler_flags_per_mode,
            linker_flags_per_mode = linker_flags_per_mode,
            linker_flags_for_d_per_mode = linker_flags_for_d_per_mode,
            codegen_opts_per_mode = codegen_opts_per_mode,
            global_versions_per_mode = global_versions_per_mode,
            lib_flags = ctx.attr.lib_flags,
            single_obj_flag = ctx.attr.single_obj_flag,
            import_flags = ctx.attr.import_flags,
            version_flag = ctx.attr.version_flag,
            hdrgen_flags = ctx.attr.hdrgen_flags,
            output_bc_flags = ctx.attr.output_bc_flags,
            qualified_object_file_names = ctx.attr.qualified_object_file_names,
            debug_repo_root_override = ctx.attr.debug_repo_root_override,
            single_object = ctx.attr.single_object,
            compile_via_bc = ctx.attr.compile_via_bc,
            fat_lto = ctx.attr.fat_lto,
            generate_headers = ctx.attr.generate_headers[BuildSettingInfo].value,
            link_with_d = ctx.attr.link_with_d,
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
        "ar_tool": attr.label(
            doc = "The ar archiver tool for bitcode compilation (optional)",
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
        ),
        "libphobos_dbg": attr.label(
            doc = "Phobos library file for debug mode",
        ),
        "libphobos_opt": attr.label(
            doc = "Phobos library file for optimized mode",
        ),
        "libphobos_fastbuild": attr.label(
            doc = "Phobos library file for fastbuild mode",
        ),
        "libphobos_lto": attr.label(
            doc = "Phobos library file for LTO mode",
        ),
        "druntime": attr.label(
            doc = "D runtime library file",
        ),
        "druntime_dbg": attr.label(
            doc = "D runtime library file for debug mode",
        ),
        "druntime_opt": attr.label(
            doc = "D runtime library file for optimized mode",
        ),
        "druntime_fastbuild": attr.label(
            doc = "D runtime library file for fastbuild mode",
        ),
        "druntime_lto": attr.label(
            doc = "D runtime library file for LTO mode",
        ),
        # Common flags (applied to all compilation modes)
        "compiler_flags": attr.string_list(
            default = [],
            doc = "Common compilation flags",
        ),
        "linker_flags": attr.string_list(
            default = [],
            doc = "Common linker flags (with link_with_d=True these flags are prefixed with -L)",
        ),
        "linker_flags_for_d": attr.string_list(
            default = [],
            doc = "Linker flags for D compiler (only used for link_with_d=True)",
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
        "compiler_flags_fastbuild": attr.string_list(
            default = [],
            doc = "Compilation flags for fastbuild mode",
        ),
        "compiler_flags_dbg": attr.string_list(
            default = ["-g", "-d-debug", "-d-version=debug_assert"],
            doc = "Compilation flags for debug mode",
        ),
        "compiler_flags_opt": attr.string_list(
            default = ["-O", "-release"],
            doc = "Compilation flags for optimized mode",
        ),

        # Per-mode linker flags
        "linker_flags_fastbuild": attr.string_list(
            default = [],
            doc = "Linker flags for fastbuild mode",
        ),
        "linker_flags_dbg": attr.string_list(
            default = [],
            doc = "Linker flags for debug mode",
        ),
        "linker_flags_opt": attr.string_list(
            default = [],
            doc = "Linker flags for optimized mode",
        ),

        # Per-mode linker flags for D compiler
        "linker_flags_for_d_fastbuild": attr.string_list(
            default = [],
            doc = "Linker flags for D compiler for fastbuild mode",
        ),
        "linker_flags_for_d_dbg": attr.string_list(
            default = [],
            doc = "Linker flags for D compiler for debug mode",
        ),
        "linker_flags_for_d_opt": attr.string_list(
            default = [],
            doc = "Linker flags for D compiler for optimized mode",
        ),

        # Per-mode code generation flags
        "codegen_opts_fastbuild": attr.string_list(
            default = [],
            doc = "Code generation flags for fastbuild mode",
        ),
        "codegen_opts_dbg": attr.string_list(
            default = [],
            doc = "Code generation flags for debug mode",
        ),
        "codegen_opts_opt": attr.string_list(
            default = ["-O3"],
            doc = "Code generation flags for optimized mode",
        ),

        # Per-mode version identifiers
        "versions_fastbuild": attr.string_list(
            default = [],
            doc = "Version identifiers for fastbuild mode",
        ),
        "versions_dbg": attr.string_list(
            default = [],
            doc = "Version identifiers for debug mode",
        ),
        "versions_opt": attr.string_list(
            default = [],
            doc = "Version identifiers for optimized mode",
        ),

        # Special flags
        "lib_flags": attr.string_list(
            default = ["-lib"],
            doc = "Flags for library creation",
        ),
        "single_obj_flag": attr.string(
            default = "",
            doc = "Flag for single object mode (e.g., '--singleobj' for LDC)",
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
            doc = "Flags for bitcode output with LTO (LDC only, e.g., ['-flto=full'])",
        ),
        "qualified_object_file_names": attr.bool(
            default = False,
            doc = "Enable qualified object file names (--oq flag for LDC)",
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
        "generate_headers": attr.label(
            default = "@rules_d//:enable_header_generation",
            doc = "Build setting that controls the default for automatic header generation from exported sources",
            providers = [BuildSettingInfo],
        ),
        "link_with_d": attr.bool(
            default = False,
            doc = "Default for using the D compiler for linking",
        ),
    },
)
