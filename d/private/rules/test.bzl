"""D test rule for compiling and running D unit tests."""

load("@bazel_lib//lib:expand_make_vars.bzl", "expand_variables")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")
load("//d/private/rules:compile.bzl", "TARGET_TYPE", "compilation_action", "runnable_attrs")
load("//d/private/rules:link.bzl", "link_action")

def _d_test_impl(ctx):
    """Implementation of d_test rule."""
    d_info = compilation_action(ctx, target_type = TARGET_TYPE.TEST)
    link_result = link_action(ctx, d_info)
    output = link_result.executable
    env_with_expansions = {
        k: expand_variables(ctx, ctx.expand_location(v, ctx.files.data), [output], "env")
        for k, v in ctx.attr.env.items()
    }
    return [
        DefaultInfo(
            executable = output,
            files = depset([output] + link_result.additional_outputs),
            runfiles = ctx.runfiles(files = ctx.files.data),
        ),
        RunEnvironmentInfo(environment = env_with_expansions),
    ]

d_test = rule(
    implementation = _d_test_impl,
    attrs = dicts.add(runnable_attrs, {
        "add_main": attr.bool(default = True, doc = "Whether to add -main to the compiler flags."),
    }),
    toolchains = ["//d:toolchain_type"] + use_cc_toolchain(),
    fragments = ["cpp"],
    test = True,
)
