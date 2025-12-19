"""Header generation implementation."""

def generate_headers_action(ctx, toolchain, exports, exports_no_hdrs, source_map):
    """Generates headers for the given sources.

    Args:
        ctx: Rule context
        toolchain: D toolchain
        exports: List of exported source files
        exports_no_hdrs: List of exported source files that should not go through header generation
        source_map: Source map
    Returns:
        List of generated header files
        Updated source map
    """
    nogen = {e.path: True for e in exports_no_hdrs}
    togen = [e for e in exports if e.path not in nogen]
    if not togen:
        return [], source_map
    new_source_map = dict(source_map)
    genhdrs = []
    package = ctx.label.package

    for e in togen:
        short_path = e.short_path
        basename = short_path[len(package) + 1:]
        hdr = ctx.actions.declare_file(basename + "_hdrgen.di")
        args = ctx.actions.args()
        args.add_all(toolchain.hdrgen_flags)
        args.add("-Hf=" + hdr.path)
        args.add(e.path)
        ctx.actions.run(
            executable = toolchain.d_compiler.files_to_run.executable,
            arguments = [args],
            inputs = [e],
            tools = [toolchain.d_compiler[DefaultInfo].default_runfiles.files],
            outputs = [hdr],
            mnemonic = "DHeaderGen",
            progress_message = "Generating D header for {}".format(e.short_path),
        )
        genhdrs.append(hdr)
        target_name = e.short_path[:-2] + ".di"
        if e in source_map:
            target_name = source_map[e][:-2] + ".di"
            new_source_map.pop(e)
        new_source_map[hdr] = target_name
    return genhdrs, new_source_map