
"""
Public providers for D.

Currently only used for pre-processed sources.
"""

def _dsourceinfo_init(
    *,
    srcs = None,
    hdrs = None,
    exports = None,
    exports_no_hdrs = None,
    source_map = None,
    string_srcs = None,
):
    return {
        "srcs": srcs or [],
        "hdrs": hdrs or [],
        "exports": exports or [],
        "exports_no_hdrs": exports_no_hdrs or [],
        "source_map": source_map or {},
        "string_srcs": string_srcs or [],
    }

DSourceInfo, _new_dsourceinfo = provider(
    doc = "Information about a D source files.",
    fields = {
        "srcs": "The source files.",
        "hdrs": "The header files.",
        "exports": "The exported source files.",
        "exports_no_hdrs": "The exported source files that should not go through header generation.",
        "source_map": "The source mapping.",
        "string_srcs": "The string source files.",
    },
    init = _dsourceinfo_init,
)
