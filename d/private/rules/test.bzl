"""D test rule for compiling and running D unit tests."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("//d/private:providers.bzl", "DInfo")
load("//d/private/rules:compile.bzl", "TARGET_TYPE", "compilation_action", "runnable_attrs")
load("//d/private/rules:link.bzl", "link_action")

def _d_test_impl(ctx):
    """Implementation of d_test rule."""
    providers = compilation_action(ctx, target_type = TARGET_TYPE.TEST)
    d_info = [p for p in providers if type(p) == type(DInfo())][0]
    default_info = [p for p in providers if type(p) == type(DefaultInfo())][0]
    return link_action(ctx, default_info.files.to_list()[0], d_info)

d_test = rule(
    implementation = _d_test_impl,
    attrs = runnable_attrs,
    toolchains = ["//d:toolchain_type"] + use_cc_toolchain(),
    fragments = ["cpp"],
    test = True,
)
