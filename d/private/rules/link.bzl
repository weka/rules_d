"""
Linking action for D rules.

"""

load("@bazel_lib//lib:expand_make_vars.bzl", "expand_variables")
load("//d/private/rules:cc_toolchain.bzl", "find_cc_toolchain_for_linking")
load("//d/private/rules:utils.bzl", "binary_name", "get_os")

def link_action(ctx, d_info):
    """Linking action for D rules.

    Args:
        ctx: The rule context.
        d_info: The DInfo provider.
    Returns:
        List of providers:
            - DefaultInfo: The linked binary.
            - RunEnvironmentInfo: The environment variables for the linked binary.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info
    args = ctx.actions.args()
    args.add_all(toolchain.linker_flags)
    args.add_all(d_info.linker_flags.to_list(), format_each = "-L=%s")
    args.add(d_info.compilation_output)
    args.add_all(d_info.libraries)
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
        # DMD doesn't support -Xcc on Windows
        args.add_all(cc_linker_info.cc_linking_options, format_each = "-Xcc=%s")
    inputs = depset(
        direct = [d_info.compilation_output],
        transitive = [d_info.libraries],
    )
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
    env_with_expansions = {
        k: expand_variables(ctx, ctx.expand_location(v, ctx.files.data), [output], "env")
        for k, v in ctx.attr.env.items()
    }
    return [
        DefaultInfo(
            executable = output,
            runfiles = ctx.runfiles(files = ctx.files.data),
        ),
        RunEnvironmentInfo(environment = env_with_expansions),
    ]
