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
