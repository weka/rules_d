"""Bitcode compilation support for D rules."""

load("//d/private/rules:utils.bzl", "compute_object_file_names")

def compile_bitcode_to_native(ctx, toolchain, bc_objs, qualified_object_file_names):
    """Stage 2: Compile bitcode objects to native objects with llc.

    Args:
        ctx: The rule context
        toolchain: The D toolchain
        bc_objs: List of bitcode object Files
        qualified_object_file_names: Boolean, whether qualified names are used

    Returns:
        List of native object Files
    """
    native_objs = []

    # Compute expected object file names from sources
    obj_names = compute_object_file_names(ctx, ctx.files.srcs, qualified_object_file_names)

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

        ctx.actions.run(
            inputs = [bc_obj],
            outputs = [native_obj],
            executable = toolchain.llc_compiler[DefaultInfo].files_to_run,
            arguments = [llc_args],
            mnemonic = "LLCcompile",
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
            mnemonic = "ArPack",
            progress_message = "Packing native objects into archive %s" % ctx.label.name,
        )
    else:
        ctx.actions.run_shell(
            inputs = native_objs,
            outputs = [output],
            arguments = [ar_args],
            command = "ar \"$@\"",
            use_default_shell_env = True,
            mnemonic = "ArPack",
            progress_message = "Packing native objects into archive %s" % ctx.label.name,
        )
