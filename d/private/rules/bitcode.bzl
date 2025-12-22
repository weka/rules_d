"""Bitcode compilation support for D rules."""

load("//d/private/rules:utils.bzl", "compute_object_file_names")

def compile_bitcode_to_native(ctx, toolchain, bc_archive, bc_objs, single_object, qualified_object_file_names, project_root):
    """Stage 2: Compile bitcode objects to native objects with llc.

    Args:
        ctx: The rule context
        toolchain: The D toolchain
        bc_archive: Bitcode archive File (for single-action mode)
        bc_objs: List of bitcode object Files (for parallel mode, may be empty)
        single_object: Boolean, whether single-object mode is enabled
        qualified_object_file_names: Boolean, whether qualified names are used
        project_root: Project root path (from compute_project_root)

    Returns:
        List of native object Files (or single File for single-action archive mode)
    """
    # Detect single-action mode: single_object or only one source file
    use_single_action = single_object or len(ctx.files.srcs) == 1

    if use_single_action:
        # Single-action mode: use llc_archive_compiler.sh to handle full workflow
        # Note: In single-action mode, we return None to indicate that repacking is not needed
        return None
    else:
        # Parallel mode: compile each bitcode object separately
        return _compile_bitcode_parallel(ctx, toolchain, bc_objs, qualified_object_file_names, project_root)

def compile_bitcode_single_action(ctx, toolchain, bc_obj, bc_archive, output):
    """Compile bitcode in a single action.

    Handles both single bitcode objects (.bc.o) and bitcode archives (.bc.a).

    Args:
        ctx: The rule context
        toolchain: The D toolchain
        bc_obj: Single bitcode object file (for binaries/tests, may be None)
        bc_archive: Bitcode archive file (for libraries, may be None)
        output: Output file (archive .a or object .o, already declared)

    Returns:
        None (output file is written directly)
    """
    # Build arguments for llc_archive_compiler.sh
    args = ctx.actions.args()

    # Add input flag based on type
    if bc_obj:
        args.add("--input-object", bc_obj)
    else:
        args.add("--input-lib", bc_archive)

    # Add output
    args.add("--output", output)

    # Add llc path if available from toolchain
    if toolchain.llc_compiler:
        llc_path = toolchain.llc_compiler[DefaultInfo].files_to_run.executable
        args.add("--llc", llc_path)

    # Add ar path if available from toolchain
    if toolchain.ar_tool:
        ar_path = toolchain.ar_tool[DefaultInfo].files_to_run.executable
        args.add("--ar", ar_path)

    # Add codegen flags if available
    if toolchain.codegen_opts_common:
        for flag in toolchain.codegen_opts_common:
            args.add("--llc-flags", flag)

    # Get llc_archive_compiler script
    compiler_script = ctx.attr._llc_archive_compiler[DefaultInfo].files.to_list()[0]

    # Prepare tools list
    tools = []
    if toolchain.llc_compiler:
        tools.append(toolchain.llc_compiler[DefaultInfo].files_to_run)
    if toolchain.ar_tool:
        tools.append(toolchain.ar_tool[DefaultInfo].files_to_run)

    # Run the compiler
    ctx.actions.run(
        inputs = [bc_obj or bc_archive],
        outputs = [output],
        executable = compiler_script,
        arguments = [args],
        tools = tools,
        use_default_shell_env = True,  # Needed to find system llc/ar if not in toolchain
        mnemonic = "DCompileBitcode",
        progress_message = "Compiling bitcode to native %s" % ctx.label.name,
    )

def _compile_bitcode_parallel(ctx, toolchain, bc_objs, qualified_object_file_names, project_root):
    """Compile bitcode objects in parallel (existing behavior).

    Args:
        ctx: The rule context
        toolchain: The D toolchain
        bc_objs: List of bitcode object Files
        qualified_object_file_names: Boolean, whether qualified names are used
        project_root: Project root path (from compute_project_root)

    Returns:
        List of native object Files
    """
    native_objs = []

    # Compute expected object file names from sources
    obj_names = compute_object_file_names(ctx, ctx.files.srcs, qualified_object_file_names, project_root)

    for src, obj_name in obj_names.items():
        # Declare corresponding bitcode and native object files
        bc_obj = ctx.actions.declare_file(ctx.label.name + "_bc_objs/" + obj_name)
        native_obj = ctx.actions.declare_file(ctx.label.name + "_native_objs/" + obj_name)
        native_objs.append(native_obj)

        # Compile bitcode to native with llc
        llc_args = ctx.actions.args()
        llc_args.add("--filetype=obj")
        if toolchain.codegen_opts_common:
            llc_args.add_all(toolchain.codegen_opts_common)
        llc_args.add(bc_obj)
        llc_args.add("-o", native_obj)

        # Use toolchain llc_compiler if available, otherwise system llc
        if toolchain.llc_compiler:
            ctx.actions.run(
                inputs = [bc_obj],
                outputs = [native_obj],
                executable = toolchain.llc_compiler[DefaultInfo].files_to_run,
                arguments = [llc_args],
                mnemonic = "DCompileBitcode",
                progress_message = "Compiling bitcode to native %s" % obj_name,
            )
        else:
            ctx.actions.run_shell(
                inputs = [bc_obj],
                outputs = [native_obj],
                arguments = [llc_args],
                command = "llc \"$@\"",
                use_default_shell_env = True,
                mnemonic = "DCompileBitcode",
                progress_message = "Compiling bitcode to native %s" % obj_name,
            )

    return native_objs

def repack_native_objects(ctx, toolchain, native_objs, output):
    """Stage 3: Repack native objects into final archive.

    Args:
        ctx: The rule context
        toolchain: The D toolchain
        native_objs: List of native object Files
        output: Output archive File
    """
    ar_args = ctx.actions.args()
    ar_args.add("rcs")
    ar_args.add(output)
    ar_args.add_all(native_objs)

    # Use toolchain ar_tool if available, otherwise system ar
    if toolchain.ar_tool:
        ctx.actions.run(
            inputs = native_objs,
            outputs = [output],
            executable = toolchain.ar_tool[DefaultInfo].files_to_run,
            arguments = [ar_args],
            mnemonic = "DLibraryArchive",
            progress_message = "Packing native objects into archive %s" % ctx.label.name,
        )
    else:
        ctx.actions.run_shell(
            inputs = native_objs,
            outputs = [output],
            arguments = [ar_args],
            command = "ar \"$@\"",
            use_default_shell_env = True,
            mnemonic = "DLibraryArchive",
            progress_message = "Packing native objects into archive %s" % ctx.label.name,
        )
