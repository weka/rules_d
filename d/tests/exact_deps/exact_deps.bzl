"""Test-only rules: what a target's D compiles declare and write when built with --//:exact_deps or --//:record_unread_deps."""

_FLAGS = ["exact_deps", "record_unread_deps"]

def _flag_on_impl(_settings, attr):
    return {"//:" + flag: attr.flag == flag for flag in _FLAGS}

_flag_on = transition(
    implementation = _flag_on_impl,
    inputs = [],
    outputs = ["//:" + flag for flag in _FLAGS],
)

def _describe(action):
    lines = ["argv: " + " ".join(action.argv)]
    lines += ["env: %s=%s" % (key, value) for key, value in sorted(action.env.items())]
    lines += ["input: " + path for path in sorted([f.path for f in action.inputs.to_list()])]
    lines += ["output: " + path for path in sorted([f.path for f in action.outputs.to_list()])]
    return lines

def _compiles_aspect_impl(target, ctx):
    unused_inputs = []
    lines = []
    for action in target.actions:
        if action.mnemonic == "Dcompile":
            unused_inputs += [f for f in action.outputs.to_list() if f.extension == "unused_inputs"]
            lines += _describe(action)
    description = ctx.actions.declare_file(target.label.name + ".dcompile_actions")
    ctx.actions.write(description, "\n".join(lines) + "\n")
    return [OutputGroupInfo(unused_inputs = depset(unused_inputs), dcompile_actions = depset([description]))]

_compiles_aspect = aspect(implementation = _compiles_aspect_impl)

_ATTRS = {
    "flag": attr.string(
        doc = "The one flag `target` is built with.",
        default = "exact_deps",
        values = _FLAGS,
    ),
    "target": attr.label(
        doc = "The D target whose compiles are inspected.",
        mandatory = True,
        cfg = _flag_on,
        aspects = [_compiles_aspect],
    ),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

def _unused_inputs_impl(ctx):
    return [DefaultInfo(files = ctx.attr.target[0][OutputGroupInfo].unused_inputs)]

unused_inputs = rule(
    implementation = _unused_inputs_impl,
    doc = "The unused_inputs lists written by the D compiles of `target`, built with only --//:<flag> set.",
    attrs = _ATTRS,
)

def _dcompile_actions_impl(ctx):
    # Under this rule's own name: the aspect's file has one runfiles path whichever flag built it.
    description = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.symlink(
        output = description,
        target_file = ctx.attr.target[0][OutputGroupInfo].dcompile_actions.to_list()[0],
    )
    return [DefaultInfo(files = depset([description]))]

dcompile_actions = rule(
    implementation = _dcompile_actions_impl,
    doc = "A file describing the D compile actions of `target`, built with only --//:<flag> set: command line, env, inputs and outputs.",
    attrs = _ATTRS,
)
