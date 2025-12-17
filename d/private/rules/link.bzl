"""
Linking action for D rules.

"""

load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//d/private/rules:cc_toolchain.bzl", "find_cc_toolchain_for_linking")

def link_action(ctx, d_info):
    """Linking action for D rules.

    Args:
        ctx: The rule context.
        d_info: The DInfo provider containing the linking context.
    Returns:
        A File for the linked binary.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info
    cc_linker_info = find_cc_toolchain_for_linking(ctx)
    linking_contexts = [
        d_info.linking_context,
        toolchain.libphobos[CcInfo].linking_context,
    ] + ([toolchain.druntime[CcInfo].linking_context] if toolchain.druntime else [])
    compilation_outputs = cc_common.create_compilation_outputs(
        objects = depset(direct = [d_info.compilation_output] if d_info.compilation_output else None),
    )

    # Build linker flags in order: toolchain common, toolchain per-mode, user flags, dependency flags
    user_link_flags = []
    if toolchain.linker_flags:
        user_link_flags.extend(toolchain.linker_flags)

    compilation_mode = ctx.var["COMPILATION_MODE"]
    if toolchain.linker_flags_per_mode and compilation_mode in toolchain.linker_flags_per_mode:
        user_link_flags.extend(toolchain.linker_flags_per_mode[compilation_mode])

    user_link_flags.extend(ctx.attr.linkopts)
    user_link_flags.extend(d_info.linker_flags.to_list())

    return cc_common.link(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = cc_linker_info.feature_configuration,
        cc_toolchain = cc_linker_info.cc_toolchain,
        compilation_outputs = compilation_outputs,
        linking_contexts = linking_contexts,
        user_link_flags = user_link_flags,
    ).executable
