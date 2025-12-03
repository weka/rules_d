"""Linking logic for D binaries."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//d/private:providers.bzl", "DInfo")

def link_binary(ctx, object_file, target_type, d_deps, c_libraries, linker_flags, compilation_mode_flags):
    """Links object files into an executable binary.

    Args:
        ctx: The rule context.
        object_file: The object file from compiling binary sources (or None if no sources).
        target_type: The type of the target ('binary' or 'test').
        d_deps: List of D dependencies.
        c_libraries: Depset of C library files.
        linker_flags: Depset of linker flags.
        compilation_mode_flags: List of compilation mode flags.

    Returns:
        The executable output file.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info

    # Build link arguments
    link_args = ctx.actions.args()
    link_args.add_all(compilation_mode_flags)
    link_args.add_all(toolchain.linker_flags)
    link_args.add_all(linker_flags.to_list(), format_each = "-L=%s")

    # Add binary object file if it exists
    if object_file:
        link_args.add(object_file)

    # Collect all D libraries
    all_d_libraries = depset(transitive = [dep.libraries for dep in d_deps])
    link_args.add_all(all_d_libraries)
    link_args.add_all(c_libraries)

    # Determine output file name
    os = _get_os(ctx)
    if os == "windows":
        output_name = ctx.label.name + ".exe"
    else:
        output_name = ctx.label.name

    output = ctx.actions.declare_file(output_name)
    link_args.add(output, format = "-of=%s")

    # Prepare inputs
    link_inputs = depset(
        direct = [object_file] if object_file else [],
        transitive = [toolchain.d_compiler[DefaultInfo].default_runfiles.files] +
                     [dep.libraries for dep in d_deps] +
                     [c_libraries],
    )

    # Run linking action
    ctx.actions.run(
        inputs = link_inputs,
        outputs = [output],
        executable = toolchain.d_compiler[DefaultInfo].files_to_run,
        arguments = [link_args],
        env = ctx.var,
        use_default_shell_env = True,
        mnemonic = "Dlink",
        progress_message = "Linking D %s %s" % (target_type, ctx.label.name),
    )

    return output

def _get_os(ctx):
    """Returns the OS name based on platform constraints."""
    if ctx.target_platform_has_constraint(ctx.attr._linux_constraint[platform_common.ConstraintValueInfo]):
        return "linux"
    elif ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo]):
        return "macos"
    elif ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        return "windows"
    else:
        fail("OS not supported")
