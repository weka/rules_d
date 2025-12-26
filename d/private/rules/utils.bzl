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

def compute_project_root(ctx, project_root_attr):
    """Computes the project root path relative to repository root.

    Args:
        ctx: Rule context
        project_root_attr: Value of the project_root attribute

    Returns:
        String path from repository root to project root (normalized, no trailing slash)
    """
    if project_root_attr == "":
        return ""  # Repository root
    elif project_root_attr == ".":
        return ctx.label.package  # Current package
    elif project_root_attr.startswith("./"):
        # Subdirectory relative to package
        subdir = project_root_attr[2:]
        if ctx.label.package:
            return ctx.label.package + "/" + subdir
        return subdir
    elif project_root_attr.startswith("../"):
        # Parent directory relative to package
        package_parts = ctx.label.package.split("/") if ctx.label.package else []
        path_parts = project_root_attr.split("/")

        # Count "../" parts
        up_count = 0
        for part in path_parts:
            if part == "..":
                up_count += 1
            else:
                break

        if up_count > len(package_parts):
            fail("project_root goes above repository root: {}".format(project_root_attr))

        # Remove parent dirs from package path
        result_parts = package_parts[:-up_count] if up_count > 0 else package_parts

        # Add remaining path parts
        remaining_parts = path_parts[up_count:]
        result_parts.extend([p for p in remaining_parts if p])

        return "/".join(result_parts)
    else:
        # Absolute path from repo root
        return project_root_attr.strip("/")

def validate_sources_under_project_root(ctx, srcs, project_root, source_map):
    """Validates that all source files are under the project root.

    Args:
        ctx: Rule context
        srcs: List of source files
        project_root: Project root path
        source_map: Dictionary mapping (generated or preprocessed) source files to their expected locations

    Fails if any source is not under project root.
    """
    if not project_root:
        return  # No validation needed for repo root

    for src in srcs:
        src_path = src.short_path
        if src in source_map:
            src_path = source_map[src]
        if not src_path.startswith(project_root + "/") and src_path != project_root:
            fail(("Source file {} is not under project_root '{}'. " +
                 "All sources must be under the specified project root.").format(
                     src_path, project_root))

def compute_object_file_names(ctx, srcs, qualified, project_root = "", source_map = {}):
    """Computes expected object file names from D source files.

    When --oq is used, LDC creates qualified object names by replacing
    / with . in the module path relative to project_root.

    Args:
        ctx: The rule context
        srcs: List of source Files
        qualified: Boolean, whether --oq flag is enabled
        project_root: Project root path (from compute_project_root)
        source_map: Dictionary mapping (generated or preprocessed) source files to their expected locations
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

        if qualified:
            # Get full path from repo root
            src_path = src.short_path
            if src in source_map:
                src_path = source_map[src]

            # Compute relative path from project root
            if project_root:
                if not src_path.startswith(project_root + "/"):
                    fail("Source file {} is not under project_root '{}'".format(
                        src_path, project_root))
                rel_path = src_path[len(project_root) + 1:]
            else:
                rel_path = src_path

            # Remove file extension from path
            if rel_path.endswith(".d"):
                rel_path = rel_path[:-2]
            elif rel_path.endswith(".di"):
                rel_path = rel_path[:-3]

            # package.d is a special case
            if rel_path.endswith("/package"):
                rel_path = rel_path[:-8]
            elif rel_path.endswith("package"):
                rel_path = rel_path[:-7]

            # Convert path to module name (slashes to dots)
            module_name = rel_path.replace("/", ".")
            obj_name = module_name + obj_ext
        else:
            # Simple: just basename.o
            obj_name = basename + obj_ext

        result[src] = obj_name

    return result
