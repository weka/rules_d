"""
Configuration information for the D toolchain.
"""

DToolchainConfigInfo = provider(
    doc = "Configuration information for the D toolchain.",
    fields = [
        # binaries
        "d_compiler",
        "c_compiler",
        # libraries
        "libphobos",
        "libphobos_src",
        "druntime",
        "druntime_src",
        # flags that can differ for different toolchains
        "lib_flags",
        "import_flags",  # unused
        "version_flag",
        "hdrgen_flags",
        # compilation modes
        "copts_per_mode",
        "copts_common",
        "linkopts_per_mode",
        "linkopts_common",
        "global_versions_per_mode",
        "global_versions_common",
    ],
)
