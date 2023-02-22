D_TOOLCHAIN = "@//d:toolchain_type"

def _d_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        name = ctx.label.name,
        d_compiler = ctx.attr.d_compiler,
        link_flags = ctx.attr.link_flags,
        import_flags = ctx.attr.import_flags,
        libphobos = ctx.attr.libphobos,
        libphobos_src = ctx.attr.libphobos_src,
        druntime = ctx.attr.druntime,
        druntime_src = ctx.attr.druntime_src,
    )
    return [toolchain_info]

d_toolchain = rule(
    _d_toolchain_impl,
    attrs = {
        "d_compiler": attr.label(
            executable = True,
            # allow_files = True,
            cfg = "host",
        ),
        "link_flags": attr.string_list(
            default = [],
        ),
        "import_flags": attr.string_list(),
        "libphobos": attr.label(),
        "libphobos_src": attr.label(),
        "druntime": attr.label(),
        "druntime_src": attr.label(),
    }
)

