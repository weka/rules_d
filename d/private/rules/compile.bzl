"""Compilation action for D rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//d/private:providers.bzl", "DInfo")
load("//d/private/rules:utils.bzl", "object_file_name", "resolve_tristate_flag", "static_library_name")

D_FILE_EXTENSIONS = [".d", ".di"]

common_attrs = {
    "srcs": attr.label_list(
        doc = "List of D '.d' or '.di' source files.",
        allow_files = D_FILE_EXTENSIONS,
        allow_empty = False,
    ),
    "deps": attr.label_list(doc = "List of dependencies.", providers = [[CcInfo], [DInfo]]),
    "dopts": attr.string_list(doc = "Compiler flags."),
    "imports": attr.string_list(doc = "List of import paths."),
    "linkopts": attr.string_list(doc = "Linker flags passed via -L flags."),
    "string_imports": attr.string_list(doc = "List of string import paths."),
    "string_srcs": attr.label_list(doc = "List of string import source files."),
    "versions": attr.string_list(doc = "List of version identifiers."),
    "_linux_constraint": attr.label(default = "@platforms//os:linux", doc = "Linux platform constraint"),
    "_macos_constraint": attr.label(default = "@platforms//os:macos", doc = "macOS platform constraint"),
    "_windows_constraint": attr.label(default = "@platforms//os:windows", doc = "Windows platform constraint"),
}

runnable_attrs = dicts.add(
    common_attrs,
    {
        "env": attr.string_dict(doc = "Environment variables for the binary at runtime. Subject of location and make variable expansion."),
        "data": attr.label_list(allow_files = True, doc = "List of files to be made available at runtime."),
        "_cc_toolchain": attr.label(
            default = "@rules_cc//cc:current_cc_toolchain",
            doc = "Default CC toolchain, used for linking. Remove after https://github.com/bazelbuild/bazel/issues/7260 is flipped (and support for old Bazel version is not needed)",
        ),
    },
)

library_attrs = dicts.add(
    common_attrs,
    {
        "source_only": attr.bool(doc = "If true, the source files are compiled, but not library is produced."),
        "single_object": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
            doc = """Controls library compilation mode:
                - "auto": Use toolchain default (from toolchain config)
                - "on": Single object mode (archive with one object file)
                - "off": Multi-object mode (archive with multiple object files)
            """,
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "List of files to be made available at compile time.",
        ),
        "hdrs": attr.label_list(
            allow_files = D_FILE_EXTENSIONS,
            doc = "D header/interface files (.di) for public API.",
        ),
        "exports": attr.label_list(
            allow_files = D_FILE_EXTENSIONS,
            doc = "D source files to export as public API.",
        ),
        "implementation_deps": attr.label_list(
            doc = "Private dependencies not propagated to consumers.",
            providers = [[CcInfo], [DInfo]],
        ),
        "compile_via_bc": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
            doc = "Controls bitcode compilation (requires single_object).",
        ),
    },
)

TARGET_TYPE = struct(
    BINARY = "binary",
    LIBRARY = "library",
    TEST = "test",
)

def compilation_action(ctx, target_type = TARGET_TYPE.LIBRARY):
    """Defines a compilation action for D source files.

    Args:
        ctx: The rule context.
        target_type: The type of the target, either 'binary', 'library', or 'test'.
    Returns:
        The DInfo provider containing the compilation information.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info
    c_deps = [d[CcInfo] for d in ctx.attr.deps if CcInfo in d]
    d_deps = [d[DInfo] for d in ctx.attr.deps if DInfo in d]
    compiler_flags = depset(
        ctx.attr.dopts,
        transitive = [d.compiler_flags for d in d_deps],
    )
    imports = depset(
        [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.imports],
        transitive = [d.imports for d in d_deps],
    )
    linker_flags = depset(
        ctx.attr.linkopts,
        transitive = [d.linker_flags for d in d_deps],
    )
    string_imports = depset(
        ([paths.join(ctx.label.workspace_root, ctx.label.package)] if ctx.files.string_srcs else []) +
        [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.string_imports],
        transitive = [d.string_imports for d in d_deps],
    )

    # Collect global versions from toolchain
    global_versions = []
    if hasattr(toolchain, "global_versions_common") and toolchain.global_versions_common:
        global_versions.extend(toolchain.global_versions_common)

    compilation_mode = ctx.var["COMPILATION_MODE"]
    if (hasattr(toolchain, "global_versions_per_mode") and
        toolchain.global_versions_per_mode and
        compilation_mode in toolchain.global_versions_per_mode):
        global_versions.extend(toolchain.global_versions_per_mode[compilation_mode])

    versions = depset(
        ctx.attr.versions + global_versions,
        transitive = [d.versions for d in d_deps],
    )

    # Collect data files
    data_files = depset(
        ctx.files.data if hasattr(ctx.files, "data") else [],
        transitive = [d.data for d in d_deps if hasattr(d, "data")],
    )
    transitive_data = depset(
        transitive = [d.transitive_data for d in d_deps if hasattr(d, "transitive_data")],
    )

    args = ctx.actions.args()

    # Apply compiler flags in order: toolchain common, toolchain per-mode, user flags
    if toolchain.compiler_flags:
        args.add_all(toolchain.compiler_flags)

    if toolchain.compiler_flags_per_mode and compilation_mode in toolchain.compiler_flags_per_mode:
        args.add_all(toolchain.compiler_flags_per_mode[compilation_mode])

    args.add_all(ctx.files.srcs)
    args.add_all(imports.to_list(), format_each = "-I=%s")
    args.add_all(string_imports.to_list(), format_each = "-J=%s")
    args.add_all(compiler_flags.to_list())

    # Use version_flag from toolchain config
    version_flag = toolchain.version_flag if toolchain.version_flag else "-version="
    args.add_all(versions.to_list(), format_each = version_flag + "%s")
    output = None
    if target_type == TARGET_TYPE.TEST:
        args.add_all(["-main", "-unittest"])
    if target_type == TARGET_TYPE.LIBRARY:
        # Always use lib_flags to create archive
        if toolchain.lib_flags:
            args.add_all(toolchain.lib_flags)

        # Add single object flag if enabled
        # NOTE: Bitcode compilation (future phase) will require single object mode.
        # When compile_via_bc is enabled, single_object must be "on" or "auto"
        # (resolving to True). The --singleobj flag ensures the bitcode workflow
        # produces a single object file before archiving.
        single_object = resolve_tristate_flag(ctx.attr.single_object, toolchain.single_object)
        if single_object:
            # Verify compiler supports single object mode
            if not toolchain.single_obj_flag:
                fail("Single object mode requested but not supported by compiler. " +
                     "Use LDC toolchain or set single_object='off'.")
            args.add(toolchain.single_obj_flag)

        output = ctx.actions.declare_file(static_library_name(ctx, ctx.label.name))
        library_to_link = None if ctx.attr.source_only else cc_common.create_library_to_link(
            actions = ctx.actions,
            static_library = output,
        )
    else:
        args.add("-c")
        output = ctx.actions.declare_file(object_file_name(ctx, ctx.label.name))
        library_to_link = None
    args.add(output, format = "-of=%s")

    inputs = depset(
        direct = (ctx.files.srcs + ctx.files.string_srcs +
                  (ctx.files.data if hasattr(ctx.files, "data") else [])),
        transitive = [toolchain.d_compiler[DefaultInfo].default_runfiles.files] +
                     [d.interface_srcs for d in d_deps],
    )

    ctx.actions.run(
        inputs = inputs,
        outputs = [output],
        executable = toolchain.d_compiler[DefaultInfo].files_to_run,
        arguments = [args],
        env = ctx.var,
        use_default_shell_env = False,
        mnemonic = "Dcompile",
        progress_message = "Compiling D %s %s" % (target_type, ctx.label.name),
    )
    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset(direct = [library_to_link] if library_to_link else None),
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset(
            direct = [linker_input],
            transitive = [
                d.linking_context.linker_inputs
                for d in c_deps + d_deps
            ],
        ),
    )
    return DInfo(
        compilation_output = output,
        compiler_flags = compiler_flags,
        imports = depset(
            [paths.join(ctx.label.workspace_root, ctx.label.package)] +
            [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.imports],
            transitive = [d.imports for d in d_deps],
        ),
        interface_srcs = depset(
            ctx.files.srcs + ctx.files.string_srcs,
            transitive = [d.interface_srcs for d in d_deps],
        ),
        linking_context = linking_context,
        linker_flags = linker_flags,
        source_only = ctx.attr.source_only if target_type == TARGET_TYPE.LIBRARY else False,
        string_imports = depset(
            ([paths.join(ctx.label.workspace_root, ctx.label.package)] if ctx.files.string_srcs else []) +
            [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.string_imports],
            transitive = [d.string_imports for d in d_deps],
        ),
        versions = versions,
        data = data_files,
        transitive_data = transitive_data,
        d_exports = depset(),  # Populated in sub-phase 2
        libs_bc = depset(),  # Populated in sub-phase 5
        libs_non_bc = depset(),  # Populated in sub-phase 5
    )
