"""Simple rule to pick dependencies to a target based on a flag."""
load("//d:providers.bzl", "DDepsInfo")
load("//d/private:providers.bzl", "DInfo")
load("@rules_cc//cc:defs.bzl", "CcInfo")

def _provide_deps_impl(ctx):
    return [DDepsInfo(
        deps = ctx.attr.deps_true if ctx.attr.flag else ctx.attr.deps_false,
    )]

provide_deps = rule(
    implementation = _provide_deps_impl,
    attrs = {
        "flag": attr.bool(doc = "Flag to determine which dependencies to provide."),
        "deps_true": attr.label_list(doc = "List of dependencies.", providers = [[CcInfo], [DInfo]]),
        "deps_false": attr.label_list(doc = "List of dependencies.", providers = [[CcInfo], [DInfo]]),
    },
    provides = [DDepsInfo],
)