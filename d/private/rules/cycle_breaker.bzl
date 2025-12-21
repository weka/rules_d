"""
Helper rules to allow breaking cyclic dependencies between libraries.

Not intended for direct use, only for use from the cycle breaking d_library wrapper macro.
"""
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//d/private/rules:compile.bzl", "compilation_action", "library_attrs", "TARGET_TYPE")
load("//d/private:providers.bzl", "DInfo")

def _d_library_break_impl(ctx):
    return [compilation_action(ctx, target_type = TARGET_TYPE.LIBRARY, cycle_breaker = True)]

d_library_break = rule(
    implementation = _d_library_break_impl,
    attrs = library_attrs,
    toolchains = ["//d:toolchain_type"],
    provides = [DInfo],
)

def _d_library_continue_impl(ctx):
    d_info = compilation_action(ctx, target_type = TARGET_TYPE.LIBRARY, cycle_breaker_lib = ctx.attr.cycle_breaker_lib)
    files = depset([d_info.compilation_output]) if d_info.compilation_output else depset()
    return [
        d_info,
        DefaultInfo(files = files),
    ]

d_library_continue = rule(
    implementation = _d_library_continue_impl,
    attrs = dicts.add(library_attrs, {
        "cycle_breaker_lib": attr.label(
            doc = "Label of the cycle breaker library for this library.",
            providers = [DInfo],
        ),
    }),
    toolchains = ["//d:toolchain_type"],
    provides = [DInfo],
)
