"""No-op source preprocessing."""
load("//d:providers.bzl", "DSourceInfo")

def _preprocess_impl(ctx):
    out_srcs = []
    source_map = {}
    for src in ctx.files.srcs:
        out_src = ctx.actions.declare_file(src.basename + ".preprocessed.d")
        out_srcs.append(out_src)
        ctx.actions.run_shell(
            inputs = [src],
            outputs = [out_src],
            command = "cp {} {} && echo 'immutable string filename = \"{}\";' >> {}".format(src.path, out_src.path, src.short_path, out_src.path),
            mnemonic = "Preprocess",
            progress_message = "Preprocessing %s" % src.short_path,
        )
        source_map[out_src] = src.short_path

    return [DSourceInfo(
        srcs = out_srcs,
        source_map = source_map,
    )]

preprocess = rule(
    implementation = _preprocess_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = [".d"],
        ),
    },
    provides = [DSourceInfo],
)
