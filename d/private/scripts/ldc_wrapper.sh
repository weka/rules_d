#!/bin/bash
# Wrapper script for LDC operations (compile to bitcode archive and unpack)
# Usage: ldc_wrapper.sh <compiler> <output_dir> <archive_path> <ar_cmd> -- <compiler_args...>
set -e -o pipefail

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <compiler> <output_dir> <archive_path> <ar_cmd> -- <compiler_args...>" >&2
    exit 1
fi

COMPILER="$1"
OUTPUT_DIR="$2"
ARCHIVE_PATH="$3"
AR_CMD="$4"
shift 4

# Expect -- separator
if [ "$1" != "--" ]; then
    echo "Error: Expected '--' separator before compiler args" >&2
    exit 1
fi
shift

# Stage 1a: Compile to bitcode archive
"$COMPILER" "$@" -of="$ARCHIVE_PATH"

# Stage 1b: Unpack bitcode archive to output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"
"$AR_CMD" x "$ARCHIVE_PATH"
