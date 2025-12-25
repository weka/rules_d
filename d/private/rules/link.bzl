"""
Linking action for D rules.

"""

load("@rules_cc//cc:defs.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//d/private/rules:cc_toolchain.bzl", "find_cc_toolchain_for_linking")
load("//d/private/rules:link_with_d.bzl", "link_with_d_action")
load("//d/private/rules:utils.bzl", "resolve_tristate_flag")

def link_action(ctx, d_info):
    """Linking action for D rules.

    Args:
        ctx: The rule context.
        d_info: The DInfo provider containing the linking context.
    Returns:
        A File for the linked binary.
    """
    toolchain = ctx.toolchains["//d:toolchain_type"].d_toolchain_info
    link_with_d = resolve_tristate_flag(ctx.attr.link_with_d, toolchain.link_with_d)
    fat_lto = resolve_tristate_flag(ctx.attr.fat_lto, toolchain.fat_lto)
    if link_with_d:
        return link_with_d_action(ctx, d_info, fat_lto)
    druntime = None
    mode = ctx.var["COMPILATION_MODE"]
    if fat_lto:
        mode = "lto"  # use special mode for LTO
    if toolchain.druntime_per_mode and mode in toolchain.druntime_per_mode:
        druntime = toolchain.druntime_per_mode[mode]
    if not druntime and toolchain.druntime:
        druntime = toolchain.druntime
    libphobos = None
    if toolchain.libphobos_per_mode and mode in toolchain.libphobos_per_mode:
        libphobos = toolchain.libphobos_per_mode[mode]
    if not libphobos and toolchain.libphobos:
        libphobos = toolchain.libphobos
    if not libphobos:
        fail("No Phobos library found for mode: %s" % mode)
    if fat_lto:
        linking_context = d_info.bc_linking_context
        output = d_info.bc_output or d_info.compilation_output
    else:
        linking_context = d_info.linking_context
        output = d_info.compilation_output

    cc_linker_info = find_cc_toolchain_for_linking(ctx)
    linking_contexts = [
        linking_context,
        libphobos[CcInfo].linking_context,
    ] + ([druntime[CcInfo].linking_context] if druntime else [])
    compilation_outputs = cc_common.create_compilation_outputs(
        objects = depset(direct = [output] if output else None),
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

    additional_inputs = []
    if ctx.attr.linker_script:
        linker_script = ctx.attr.linker_script.files.to_list()[0]
        additional_inputs.append(linker_script)
        user_link_flags.extend(["-T", linker_script.path])

    if ctx.attr.dynamic_symbols:
        dynamic_symbols = ctx.attr.dynamic_symbols.files.to_list()[0]
        additional_inputs.append(dynamic_symbols)
        user_link_flags.extend(["-dynamic-list", dynamic_symbols.path])

    return cc_common.link(
        name = ctx.label.name,
        actions = ctx.actions,
        feature_configuration = cc_linker_info.feature_configuration,
        cc_toolchain = cc_linker_info.cc_toolchain,
        compilation_outputs = compilation_outputs,
        linking_contexts = linking_contexts,
        user_link_flags = user_link_flags,
        additional_inputs = additional_inputs,
    ).executable
