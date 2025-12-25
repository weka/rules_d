"""
Action supporting old style linking using the D compiler.

"""

load("//d/private/rules:cc_toolchain.bzl", "find_cc_toolchain_for_linking")
load("//d/private/rules:utils.bzl", "binary_name", "get_os")

def link_with_d_action(ctx, d_info, fat_lto):
    """Action supporting old style linking using the D compiler.

    Args:
        ctx: The rule context.
        d_info: The DInfo provider containing the linking context.
        fat_lto: Whether to use fat LTO.
    Returns:
        A File for the linked binary.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info
    args = ctx.actions.args()
    args.add_all(toolchain.linker_flags, format_each = "-L=%s")
    args.add_all(d_info.linker_flags.to_list(), format_each = "-L=%s")
    if fat_lto:
        args.add("-flto=full")
        object = d_info.bc_output
    else:
        object = d_info.compilation_output
    context = d_info.linking_context if not fat_lto else d_info.bc_linking_context
    libraries = []
    for linker_input in context.linker_inputs.to_list():
        args.add_all(linker_input.user_link_flags, format_each = "-L=%s")
        # ok, this is a shady part. Unless we disable "supports_pic" feature in the cc_toolchain,
        # we might get some cc libraries with only `pic_static_library` set.
        # we can fall back to using it, but mixing pic and nopic code usually breaks at link time.
        for lib in linker_input.libraries:
            if not lib.static_library:
                fail("Library produced by %s has no static library, need to disable supports_pic feature in the cc_toolchain?" % linker_input.owner)
            libraries.append(lib.static_library)
    if not object:
        # ldc can't link without an object file
        empty_object = ctx.actions.declare_file(ctx.label.name + "_empty.o")
        ctx.actions.write(empty_object, "")
        object = empty_object
    args.add(object)
    args.add_all(libraries)
    output = ctx.actions.declare_file(binary_name(ctx, ctx.label.name))
    args.add(output, format = "-of=%s")
    cc_linker_info = find_cc_toolchain_for_linking(ctx)
    env = dict(cc_linker_info.env)
    env.update({
        "CC": cc_linker_info.cc_compiler,  # Have to use the env variable here, since DMD doesn't support -gcc= flag
        # Ok, this is a bit weird. Local toolchain from rules_cc works fine if we don't set PATH here.
        # But doesn't work if we set it to an empty string.
        # OTOH the toolchain from toolchains_llvm doesn't work without setting PATH here. (Can't find the linker executable)
        # Even though the cc_wrapper script adds "/usr/bin" to the PATH variable,
        # it only works if the PATH is already in the environment. (I think they have to `export`)
        # So toolchains_llvm works if we set PATH to "" but doesn't work if we don't set it at all.
        # So, to get to a common ground, we set PATH to something generic.
        "PATH": "/bin:/usr/bin:/usr/local/bin",
    })
    if get_os(ctx) != "windows":
        # DMD on Windows doesn't support -Xcc=
        args.add_all(cc_linker_info.cc_linking_options, format_each = "-Xcc=%s")
    inputs = depset(direct = [object] + libraries)
    ctx.actions.run(
        inputs = inputs,
        outputs = [output],
        executable = toolchain.d_compiler[DefaultInfo].files_to_run,
        tools = [cc_linker_info.cc_toolchain.all_files],
        arguments = [args],
        env = env,
        use_default_shell_env = False,
        mnemonic = "Dlink",
        progress_message = "Linking D binary %s" % ctx.label.name,
    )
    return output
