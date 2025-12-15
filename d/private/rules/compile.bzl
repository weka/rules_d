"""Compilation action for D rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//d/private:providers.bzl", "DInfo")
load("//d/private/rules:bitcode.bzl", "compile_bitcode_to_native", "repack_native_objects")
load("//d/private/rules:utils.bzl", "compute_object_file_names", "object_file_name", "resolve_tristate_flag", "static_library_name")

D_FILE_EXTENSIONS = [".d", ".di"]

common_attrs = {
    "srcs": attr.label_list(
        doc = "List of D '.d' or '.di' source files.",
        allow_files = D_FILE_EXTENSIONS,
        allow_empty = True,
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
        "_ldc_wrapper_script": attr.label(
            default = "//d/private/scripts:ldc_wrapper.sh",
            allow_single_file = True,
            doc = "LDC wrapper script for unified compilation",
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
        "qualified_object_file_names": attr.string(
            default = "auto",
            values = ["auto", "on", "off"],
            doc = """Controls object file naming in archives:
                - "auto": Use toolchain default
                - "on": Use qualified names (package.path.basename.o)
                - "off": Use basename only (basename.o)
            """,
        ),
        "_ldc_wrapper_script": attr.label(
            default = "//d/private/scripts:ldc_wrapper.sh",
            allow_single_file = True,
            doc = "LDC wrapper script for unified compilation",
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

    # Regular dependencies (propagated to consumers)
    c_deps = [d[CcInfo] for d in ctx.attr.deps if CcInfo in d]
    d_deps = [d[DInfo] for d in ctx.attr.deps if DInfo in d]

    # Implementation dependencies (not propagated to consumers)
    impl_c_deps = []
    impl_d_deps = []
    if hasattr(ctx.attr, "implementation_deps") and ctx.attr.implementation_deps:
        impl_c_deps = [d[CcInfo] for d in ctx.attr.implementation_deps if CcInfo in d]
        impl_d_deps = [d[DInfo] for d in ctx.attr.implementation_deps if DInfo in d]

    # For compilation: use ALL deps (regular + implementation)
    all_c_deps = c_deps + impl_c_deps
    all_d_deps = d_deps + impl_d_deps

    # Collect from all deps for compilation
    compiler_flags = depset(
        ctx.attr.dopts,
        transitive = [d.compiler_flags for d in all_d_deps],
    )
    imports = depset(
        [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.imports],
        transitive = [d.imports for d in all_d_deps],
    )
    linker_flags = depset(
        ctx.attr.linkopts,
        transitive = [d.linker_flags for d in all_d_deps],
    )
    string_imports = depset(
        ([paths.join(ctx.label.workspace_root, ctx.label.package)] if ctx.files.string_srcs else []) +
        [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.string_imports],
        transitive = [d.string_imports for d in all_d_deps],
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
        transitive = [d.versions for d in all_d_deps],
    )

    # Collect data files (from all deps for compilation)
    data_files = depset(
        ctx.files.data if hasattr(ctx.files, "data") else [],
        transitive = [d.data for d in all_d_deps if hasattr(d, "data")],
    )
    transitive_data = depset(
        transitive = [d.transitive_data for d in all_d_deps if hasattr(d, "transitive_data")],
    )

    # Determine which sources to export (libraries only)
    d_exports = depset()
    direct_interface_srcs = ctx.files.srcs

    if target_type == TARGET_TYPE.LIBRARY:
        # Priority: hdrs > exports > all srcs (backward compatibility)
        public_srcs = []
        if hasattr(ctx.files, "hdrs") and ctx.files.hdrs:
            public_srcs.extend(ctx.files.hdrs)
        if hasattr(ctx.files, "exports") and ctx.files.exports:
            public_srcs.extend(ctx.files.exports)

        # If no hdrs/exports specified, use all srcs (backward compatibility)
        if public_srcs:
            direct_interface_srcs = public_srcs

        # Build d_exports with transitive (from all deps for compilation)
        d_exports = depset(
            direct_interface_srcs,
            transitive = [d.d_exports for d in all_d_deps if hasattr(d, "d_exports")],
        )

    # Check if this is a header-only or deps-only library (no srcs to compile)
    has_srcs = len(ctx.files.srcs) > 0

    # Skip compilation if no sources (header-only or deps-only library)
    if not has_srcs and target_type == TARGET_TYPE.LIBRARY:
        # Return DInfo without compilation
        return DInfo(
            compilation_output = None,
            compiler_flags = depset(
                ctx.attr.dopts,
                transitive = [d.compiler_flags for d in d_deps],
            ),
            imports = depset(
                [paths.join(ctx.label.workspace_root, ctx.label.package)] +
                [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.imports],
                transitive = [d.imports for d in d_deps],
            ),
            interface_srcs = depset(
                direct_interface_srcs + ctx.files.string_srcs,
                transitive = [d.interface_srcs for d in d_deps],
            ),
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset(
                    transitive = [d.linking_context.linker_inputs for d in all_c_deps + all_d_deps],
                ),
            ),
            linker_flags = depset(
                ctx.attr.linkopts,
                transitive = [d.linker_flags for d in d_deps],
            ),
            source_only = ctx.attr.source_only if hasattr(ctx.attr, "source_only") else False,
            string_imports = depset(
                ([paths.join(ctx.label.workspace_root, ctx.label.package)] if ctx.files.string_srcs else []) +
                [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.string_imports],
                transitive = [d.string_imports for d in d_deps],
            ),
            versions = depset(
                ctx.attr.versions + global_versions,
                transitive = [d.versions for d in d_deps],
            ),
            data = depset(
                ctx.files.data if hasattr(ctx.files, "data") else [],
                transitive = [d.data for d in d_deps if hasattr(d, "data")],
            ),
            transitive_data = depset(
                transitive = [d.transitive_data for d in d_deps if hasattr(d, "transitive_data")],
            ),
            d_exports = depset(
                direct_interface_srcs,
                transitive = [d.d_exports for d in d_deps if hasattr(d, "d_exports")],
            ),
            libs_bc = depset(),
            libs_non_bc = depset(),
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

        # Resolve bitcode and qualified object file names flags
        compile_via_bc = resolve_tristate_flag(ctx.attr.compile_via_bc, toolchain.compile_via_bc)
        qualified_object_file_names = resolve_tristate_flag(
            ctx.attr.qualified_object_file_names,
            toolchain.qualified_object_file_names,
        )

        # Add --oq flag if qualified object file names are enabled
        if qualified_object_file_names:
            args.add("--oq")

        # Validate bitcode requirements if enabled
        if compile_via_bc:
            if not toolchain.output_bc_flags:
                fail("Bitcode compilation requested but toolchain.output_bc_flags not set")
            # Add bitcode flags
            if toolchain.output_bc_flags:
                args.add_all(toolchain.output_bc_flags)

        output = ctx.actions.declare_file(static_library_name(ctx, ctx.label.name))
        library_to_link = None if ctx.attr.source_only else cc_common.create_library_to_link(
            actions = ctx.actions,
            static_library = output,
        )
    else:
        args.add("-c")
        output = ctx.actions.declare_file(object_file_name(ctx, ctx.label.name))
        library_to_link = None
        compile_via_bc = False
        qualified_object_file_names = False

    # Unified compilation using ldc_wrapper.sh
    wrapper_script = ctx.attr._ldc_wrapper_script[DefaultInfo].files.to_list()[0]

    inputs = depset(
        direct = (ctx.files.srcs + ctx.files.string_srcs +
                  (ctx.files.data if hasattr(ctx.files, "data") else []) +
                  (ctx.files.hdrs if hasattr(ctx.files, "hdrs") else []) +
                  (ctx.files.exports if hasattr(ctx.files, "exports") else []) +
                  [wrapper_script]),
        transitive = [toolchain.d_compiler[DefaultInfo].default_runfiles.files] +
                     [d.interface_srcs for d in all_d_deps],
    )

    # Prepare environment variables for wrapper
    env = dict(ctx.var)
    env["LDC2_REAL"] = toolchain.d_compiler[DefaultInfo].files_to_run.executable.path

    # Declare bitcode object files if compiling via bitcode
    bc_objs = []
    bc_archive = None
    compile_output = output  # By default, compile directly to output
    if target_type == TARGET_TYPE.LIBRARY and compile_via_bc:
        # For bitcode compilation, use intermediate bitcode archive
        bc_archive = ctx.actions.declare_file(ctx.label.name + ".bc.a")
        compile_output = bc_archive

        # Compute and declare individual bitcode object files
        obj_names = compute_object_file_names(ctx, ctx.files.srcs, qualified_object_file_names)
        for src, obj_name in obj_names.items():
            bc_obj = ctx.actions.declare_file(ctx.label.name + "_bc_objs/" + obj_name)
            bc_objs.append(bc_obj)

        # Set BC_UNPACK_DIR for wrapper to unpack archive
        bc_unpack_dir = bc_objs[0].dirname if bc_objs else ""
        env["BC_UNPACK_DIR"] = bc_unpack_dir

        # Set AR_CMD: use toolchain ar_tool if available, otherwise system ar
        if toolchain.ar_tool:
            env["AR_CMD"] = toolchain.ar_tool[DefaultInfo].files_to_run.executable.path
        else:
            env["AR_CMD"] = "ar"

    # Stage 1: Compile (and optionally unpack if bitcode)
    args.add(compile_output, format = "-of=%s")
    outputs = [compile_output] + bc_objs
    tools = [toolchain.d_compiler[DefaultInfo].files_to_run]
    # Add ar_tool to tools if using it for unpacking
    if target_type == TARGET_TYPE.LIBRARY and compile_via_bc and toolchain.ar_tool:
        tools.append(toolchain.ar_tool[DefaultInfo].files_to_run)

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = wrapper_script,
        arguments = [args],
        tools = tools,
        env = env,
        use_default_shell_env = False,
        mnemonic = "Dcompile",
        progress_message = "Compiling D %s %s" % (target_type, ctx.label.name),
    )

    # Stage 2 & 3: Bitcode to native compilation and repacking (if bitcode enabled)
    if target_type == TARGET_TYPE.LIBRARY and compile_via_bc:
        # Stage 2: Compile bitcode objects to native
        native_objs = compile_bitcode_to_native(ctx, toolchain, bc_objs, qualified_object_file_names)

        # Stage 3: Repack native objects into final archive
        repack_native_objects(ctx, toolchain, native_objs, output)
    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset(direct = [library_to_link] if library_to_link else None),
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset(
            direct = [linker_input],
            transitive = [
                d.linking_context.linker_inputs
                for d in all_c_deps + all_d_deps
            ],
        ),
    )
    # For DInfo propagation: use only regular deps (not implementation deps)
    return DInfo(
        compilation_output = output,
        compiler_flags = depset(
            ctx.attr.dopts,
            transitive = [d.compiler_flags for d in d_deps],  # Only regular deps
        ),
        imports = depset(
            [paths.join(ctx.label.workspace_root, ctx.label.package)] +
            [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.imports],
            transitive = [d.imports for d in d_deps],  # Only regular deps
        ),
        interface_srcs = depset(
            direct_interface_srcs + ctx.files.string_srcs,
            transitive = [d.interface_srcs for d in d_deps],  # Only regular deps
        ),
        linking_context = linking_context,  # Already includes all deps internally
        linker_flags = depset(
            ctx.attr.linkopts,
            transitive = [d.linker_flags for d in d_deps],  # Only regular deps
        ),
        source_only = ctx.attr.source_only if target_type == TARGET_TYPE.LIBRARY else False,
        string_imports = depset(
            ([paths.join(ctx.label.workspace_root, ctx.label.package)] if ctx.files.string_srcs else []) +
            [paths.join(ctx.label.workspace_root, ctx.label.package, imp) for imp in ctx.attr.string_imports],
            transitive = [d.string_imports for d in d_deps],  # Only regular deps
        ),
        versions = depset(
            ctx.attr.versions + global_versions,
            transitive = [d.versions for d in d_deps],  # Only regular deps
        ),
        data = depset(
            ctx.files.data if hasattr(ctx.files, "data") else [],
            transitive = [d.data for d in d_deps if hasattr(d, "data")],  # Only regular deps
        ),
        transitive_data = depset(
            transitive = [d.transitive_data for d in d_deps if hasattr(d, "transitive_data")],  # Only regular deps
        ),
        d_exports = depset(
            direct_interface_srcs if target_type == TARGET_TYPE.LIBRARY else [],
            transitive = [d.d_exports for d in d_deps if hasattr(d, "d_exports")],  # Only regular deps
        ),
        libs_bc = depset(
            direct = [output] if (target_type == TARGET_TYPE.LIBRARY and compile_via_bc and not ctx.attr.source_only) else [],
            transitive = [d.libs_bc for d in d_deps if hasattr(d, "libs_bc")],
        ),
        libs_non_bc = depset(
            direct = [output] if (target_type == TARGET_TYPE.LIBRARY and not compile_via_bc and not ctx.attr.source_only) else [],
            transitive = [d.libs_non_bc for d in d_deps if hasattr(d, "libs_non_bc")],
        ),
    )
