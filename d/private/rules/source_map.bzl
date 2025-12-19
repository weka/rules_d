"""Source map utilities."""

def write_source_map(ctx, source_map):
    """Writes the source map to a file."""
    source_map_file = ctx.actions.declare_file(ctx.label.name + "_source_map.txt")
    ctx.actions.write(source_map_file, "\n".join(["{src} {dest}".format(src=src.path, dest=dest) for src, dest in source_map.items()]))
    return source_map_file

def merge_source_maps(source_maps):
    """
    Merges the source maps.

    Args:
        source_maps: List of source maps.
    Returns:
        Merged source map.
    Fails if a source file is mapped to multiple destinations.
    """
    result = {}
    reverse_map = {}
    for source_map in source_maps:
        for src, dest in source_map.items():
            if src in reverse_map:
                fail("Source file {src} is already in the source map, but it's being mapped to {dest} and {dest2}.".format(src=src, dest=reverse_map[src], dest2=dest))
            reverse_map[dest] = src
            result[src] = dest
    return result

def filter_source_map(source_map, srcs):
    """Filters the source map."""
    return {src: dest for src, dest in source_map.items() if src in srcs}