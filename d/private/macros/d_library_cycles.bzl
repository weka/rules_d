"""
Macro allowing breaking cyclic dependencies between libraries.
"""

load("//d/private/rules:cycle_breaker.bzl", "d_library_break", "d_library_continue")
load("//d/private/rules:library.bzl", "d_library")

def _d_library_cycles_impl(name, deps, cycle_breaker_suffix, **kwargs):
    if cycle_breaker_suffix == "":
        # If the suffix is empty, fallback to the normal `d_library` rule
        d_library(
            name = name,
            deps = deps,
            **kwargs
        )
        return
    cycle_breaker_name = name + cycle_breaker_suffix
    d_library_break(
        name = cycle_breaker_name,
        deps = [],  # drop the deps
        **kwargs
    )
    d_library_continue(
        name = name,
        deps = deps,
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