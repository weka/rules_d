"""
Macro allowing breaking cyclic dependencies between libraries.
"""

load("//d/private/rules:cycle_breaker.bzl", "d_library_break", "d_library_continue")
load("//d/private/rules:library.bzl", "d_library")

def _d_library_cycles_impl(name, deps, implementation_deps, cycle_breaker_suffix, **kwargs):
    if cycle_breaker_suffix == "":
        # If the suffix is empty, fallback to the normal `d_library` rule
        d_library(
            name = name,
            deps = deps,
            implementation_deps = implementation_deps,
            **kwargs
        )
        return
    cycle_breaker_name = name + cycle_breaker_suffix
    # The `-exports` leaf must remain a true leaf — its whole purpose is to
    # carry only this lib's interface (.di or raw .d) without ANY transit
    # to dependencies. We drop BOTH `deps` and `implementation_deps` here.
    # If either survived, the leaf would form bazel target-graph cycles
    # whenever its containing SCC member's deps closed back on it.
    d_library_break(
        name = cycle_breaker_name,
        deps = [],
        implementation_deps = [],
        **kwargs
    )
    d_library_continue(
        name = name,
        deps = deps,
        implementation_deps = implementation_deps,
        cycle_breaker_lib = ":" + cycle_breaker_name,
        **kwargs
    )

d_library_cycles = macro(
    doc = """
    Macro allowing breaking cyclic dependencies between libraries.
    """,
    implementation = _d_library_cycles_impl,
    inherit_attrs = d_library,
    attrs = {
        "cycle_breaker_suffix": attr.string(default = "-cycle-breaker", configurable = False),
    },
)