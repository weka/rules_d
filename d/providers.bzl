
"""
Public providers for D.

Currently only used for pre-processed sources.
"""

def _dsourceinfo_init(
    *,
    srcs = None,
    hdrs = None,
    exports = None,
    source_map = None,
):
    return {
        "srcs": srcs or [],
        "hdrs": hdrs or [],
        "exports": exports or [],
        "source_map": source_map or {},
    }

DSourceInfo, _new_dsourceinfo = provider(
    doc = "Information about a D source files.",
    fields = {
        "srcs": "The source files.",
        "hdrs": "The header files.",
        "exports": "The exported source files.",
        "source_map": "The source mapping.",
    },
    init = _dsourceinfo_init,
)
