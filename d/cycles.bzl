"""
Macro allowing breaking cyclic dependencies between libraries.

Should work like a drop-in replacement for d_library, but allows breaking cyclic dependencies.
Usage:
```bzl
d_library(
    name = "liba",
    srcs = ["liba.d"],
    deps = [":libb"],
)
d_library(
    name = "libb",
    srcs = ["libb.d"],
    deps = [":liba-cycle-breaker"],
)
```
"""
load("//d/private/macros:d_library_cycles.bzl", _d_library_cycles = "d_library_cycles")

d_library = _d_library_cycles
    