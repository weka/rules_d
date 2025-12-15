"""Utility functions for D rules."""

def get_os(ctx):
    """Returns the OS based on the target platform constraint.

    Args:
        ctx: The rule context.
    Returns:
        The OS (one of "linux", "macos", "windows").
    """
    if ctx.target_platform_has_constraint(ctx.attr._linux_constraint[platform_common.ConstraintValueInfo]):
        return "linux"
    elif ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo]):
        return "macos"
    elif ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        return "windows"
    else:
        fail("OS not supported")

def binary_name(ctx, name):
    """Returns the name of the binary based on the OS.

    Args:
        ctx: The rule context.
        name: The base name of the binary.
    Returns:
        The name of the binary file.
    """
    os = get_os(ctx)
    if os == "linux" or os == "macos":
        return name
    elif os == "windows":
        return name + ".exe"
    else:
        fail("Unsupported os %s for binary: %s" % (os, name))

def static_library_name(ctx, name):
    """Returns the name of the static library based on the OS.

    Args:
        ctx: The rule context.
        name: The base name of the library.
    Returns:
        The name of the static library file.
    """
    os = get_os(ctx)
    if os == "linux" or os == "macos":
        return "lib" + name + ".a"
    elif os == "windows":
        return name + ".lib"
    else:
        fail("Unsupported os %s for static library: %s" % (os, name))

def object_file_name(ctx, name):
    """Returns the name of the object file based on the OS.

    Args:
        ctx: The rule context.
        name: The base name of the object file.
    Returns:
        The name of the object file.
    """
    os = get_os(ctx)
    if os == "linux" or os == "macos":
        return name + ".o"
    elif os == "windows":
        return name + ".obj"
    else:
        fail("Unsupported os %s for object file: %s" % (os, name))

def resolve_tristate_flag(attr_value, toolchain_default):
    """Resolves a tri-state attribute (auto/on/off) to a boolean.

    Args:
        attr_value: The attribute value (string: "auto", "on", or "off")
        toolchain_default: The default value from toolchain config (boolean)
    Returns:
        Boolean: True if enabled, False if disabled
    """
    if attr_value == "on":
        return True
    elif attr_value == "off":
        return False
    else:  # "auto"
        return toolchain_default

def compute_object_file_names(ctx, srcs, qualified):
    """Computes expected object file names from D source files.

    When --oq is used, LDC creates qualified object names by replacing
    / with . in the package path: foo/bar/baz.d -> foo.bar.baz.o

    Args:
        ctx: The rule context
        srcs: List of source Files
        qualified: Boolean, whether --oq flag is enabled

    Returns:
        Dictionary mapping source File to expected object file basename
    """
    os = get_os(ctx)
    obj_ext = ".o" if os in ["linux", "macos"] else ".obj"

    result = {}
    for src in srcs:
        basename = src.basename
        if basename.endswith(".d"):
            basename = basename[:-2]
        elif basename.endswith(".di"):
            basename = basename[:-3]

        if qualified and src.owner.package:
            # Qualified: package/path/file.d -> package.path.file.o
            pkg_path = src.owner.package.replace("/", ".")
            obj_name = pkg_path + "." + basename + obj_ext
        else:
            # Simple: just basename.o
            obj_name = basename + obj_ext

        result[src] = obj_name

    return result
