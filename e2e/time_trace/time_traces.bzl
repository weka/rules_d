"""Test-only rules: a tracing D toolchain, and the time_traces output group of a D target built with or without it."""

load("@rules_d//d:toolchain.bzl", "DToolchainInfo")

def _trace_transition_impl(_settings, attr):
    return {"//:trace": attr.trace}

_trace_transition = transition(
    implementation = _trace_transition_impl,
    inputs = [],
    outputs = ["//:trace"],
)

def _time_traces_impl(ctx):
    # A list file rather than the profiles themselves: $(rootpaths) fails on an empty group.
    traces = ctx.attr.target[0][OutputGroupInfo].time_traces.to_list()
    listing = ctx.actions.declare_file(ctx.label.name + ".list")
    ctx.actions.write(listing, "".join([f.short_path + "\n" for f in traces]))
    return [DefaultInfo(files = depset([listing]), runfiles = ctx.runfiles(files = traces))]

time_traces = rule(
    implementation = _time_traces_impl,
    doc = "Lists the time_traces output group of `target`, built with --//:trace set to `trace`; the profiles are its runfiles.",
    attrs = {
        "target": attr.label(
            doc = "The D target whose time_traces group is returned.",
            mandatory = True,
            cfg = _trace_transition,
        ),
        "trace": attr.bool(
            doc = "Whether to build `target` with the toolchain that passes --ftime-trace.",
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _trace_off_impl(_settings, _attr):
    return {"//:trace": False}

_trace_off = transition(
    implementation = _trace_off_impl,
    inputs = [],
    outputs = ["//:trace"],
)

def _traced_toolchain_impl(ctx):
    base = ctx.attr._base[0]
    info = base[DToolchainInfo]
    fields = {k: getattr(info, k) for k in dir(info) if k not in ("to_json", "to_proto")}
    per_mode = dict(info.compiler_flags_per_mode or {})
    for mode in ("dbg", "fastbuild"):
        per_mode[mode] = per_mode.get(mode, []) + ctx.attr.flags
    fields["compiler_flags_per_mode"] = per_mode
    return [platform_common.ToolchainInfo(
        default = base[DefaultInfo],
        d_toolchain_info = DToolchainInfo(**fields),
        template_variables = base[platform_common.TemplateVariableInfo],
    )]

traced_toolchain = rule(
    implementation = _traced_toolchain_impl,
    doc = "rules_d's default D toolchain with `flags` added to its dbg and fastbuild compiler flags.",
    attrs = {
        "flags": attr.string_list(
            doc = "Compiler flags added in the dbg and fastbuild modes.",
            mandatory = True,
        ),
        # Resolved with --//:trace off, so that it is the default toolchain and not this one.
        "_base": attr.label(
            default = "@rules_d//d:resolved_toolchain",
            cfg = _trace_off,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
