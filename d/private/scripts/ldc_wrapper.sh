#!/bin/bash
# Drop-in replacement wrapper for ldc2
# Optionally compiles to bitcode archive and unpacks it to a directory
#
# Environment variables:
#   LDC2_REAL      - Path to the real ldc2 compiler (required)
#   BC_UNPACK_DIR  - Directory to unpack bitcode objects (optional)
#                    If not set, just compiles normally without unpacking
#   AR_CMD         - ar command to use (default: "ar")

set -e -o pipefail

# Check required environment variables
if [ -z "$LDC2_REAL" ]; then
    echo "Error: LDC2_REAL environment variable not set" >&2
    exit 1
fi

# Compile with real ldc2
"$LDC2_REAL" "$@"

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
