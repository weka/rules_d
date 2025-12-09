"""D test rule for compiling binaries."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("//d/private:providers.bzl", "DInfo")
load("//d/private/rules:compile.bzl", "TARGET_TYPE", "compilation_action", "runnable_attrs")
load("//d/private/rules:link.bzl", "link_action")

def _d_binary_impl(ctx):
    """Implementation of d_binary rule."""
    providers = compilation_action(ctx, target_type = TARGET_TYPE.BINARY)
    d_info = [p for p in providers if type(p) == type(DInfo())][0]
    default_info = [p for p in providers if type(p) == type(DefaultInfo())][0]
    return link_action(ctx, default_info.files.to_list()[0], d_info)

d_binary = rule(
    implementation = _d_binary_impl,
    attrs = runnable_attrs,
    toolchains = ["//d:toolchain_type"] + use_cc_toolchain(),
    fragments = ["cpp"],
    executable = True,
)
