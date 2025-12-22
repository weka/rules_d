#!/bin/bash
# Drop-in replacement wrapper for ldc2
# Optionally compiles to bitcode archive and unpacks it to a directory
#
# Environment variables:
#   LDC2_REAL       - Path to the real ldc2 compiler (required)
#   BC_UNPACK_DIR   - Directory to unpack bitcode objects (optional)
#                     If not set, just compiles normally without unpacking
#   LDC_SKIP_UNPACK - If set, skip unpacking even if BC_UNPACK_DIR is set
#                     Used in single-action mode where llc_archive_compiler handles unpacking
#   LDC2_SOURCE_MAP - Path to the source map file (optional)
#   AR_CMD          - ar command to use (default: "ar")

set -e -o pipefail

# Check required environment variables
if [ -z "$LDC2_REAL" ]; then
    echo "Error: LDC2_REAL environment variable not set" >&2
    exit 1
fi

# TODO: this is horrible, should we make C++ or Go wrapper instead?
if [ -n "$LDC2_SOURCE_MAP" ]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        target="${line%% *}"
        source="${line#* *}"
        mkdir -p "$(dirname "$source")"
        ln -srf "$PWD/$target" "$source"
    done < "$LDC2_SOURCE_MAP"
fi

DEBUG_PREFIX_MAP=""
if [ -n "$LDC2_DEBUG_REPO_ROOT_OVERRIDE" ]; then
    # this is not enough when running bazel locally, since apparently
    # D toolchain files are _not_ under the sandbox root (current dir)
    # but are under the workspace root (root of the repo).
    # Still, it seems to be working fine with the remote execution.
    # TODO: find a better solution.
    DEBUG_PREFIX_MAP="-fdebug-prefix-map=$PWD=$LDC2_DEBUG_REPO_ROOT_OVERRIDE"
fi

# Compile with real ldc2
"$LDC2_REAL" $DEBUG_PREFIX_MAP "$@"

# If LDC_SKIP_UNPACK is set, skip unpacking (for single-action mode)
if [ -n "$LDC_SKIP_UNPACK" ]; then
    exit 0
fi

# If BC_UNPACK_DIR is set, unpack the archive
if [ -n "$BC_UNPACK_DIR" ]; then
    # Default ar command
    AR_CMD="${AR_CMD:-ar}"

    # Find the output file from arguments (-of=...)
    OUTPUT_FILE=""
    for arg in "$@"; do
        if [[ "$arg" == -of=* ]]; then
            OUTPUT_FILE="${arg#-of=}"
            break
        fi
    done

    if [ -z "$OUTPUT_FILE" ]; then
        echo "Error: BC_UNPACK_DIR set but no output file specified (-of=...)" >&2
        exit 1
    fi

    # Convert to absolute path before changing directory
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$PWD/$OUTPUT_FILE"
    fi

    # Unpack bitcode archive to output directory
    mkdir -p "$BC_UNPACK_DIR"
    cd "$BC_UNPACK_DIR"
    "$AR_CMD" x "$OUTPUT_FILE"
fi
