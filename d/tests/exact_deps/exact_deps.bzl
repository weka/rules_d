"""Test-only rule: the unused_inputs lists a target's D compiles write when built with --//:exact_deps."""

def _exact_deps_on_impl(_settings, _attr):
    return {"//:exact_deps": True}

_exact_deps_on = transition(
    implementation = _exact_deps_on_impl,
    inputs = [],
    outputs = ["//:exact_deps"],
)

def _unused_inputs_aspect_impl(target, _ctx):
    files = []
    for action in target.actions:
        if action.mnemonic == "Dcompile":
            files += [f for f in action.outputs.to_list() if f.extension == "unused_inputs"]
    return [OutputGroupInfo(unused_inputs = depset(files))]

_unused_inputs_aspect = aspect(implementation = _unused_inputs_aspect_impl)

def _unused_inputs_impl(ctx):
    return [DefaultInfo(files = ctx.attr.target[0][OutputGroupInfo].unused_inputs)]

unused_inputs = rule(
    implementation = _unused_inputs_impl,
    doc = "The unused_inputs lists written by the D compiles of `target`, built with --//:exact_deps.",
    attrs = {
        "target": attr.label(
            doc = "The D target whose compiles are inspected.",
            mandatory = True,
            cfg = _exact_deps_on,
            aspects = [_unused_inputs_aspect],
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
