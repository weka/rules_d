#!/bin/bash
# Specialized tool for compiling bitcode archives to native code
# Handles the full workflow: unpack bitcode archive -> compile with llc -> pack native archive
#
# Usage:
#   llc_archive_compiler.sh --input <bc.a> --output-archive <native.a> [options]
#   llc_archive_compiler.sh --input <bc.a> --output-object <obj.o> [options]
#
# Options:
#   --input <path>          Input bitcode archive (required)
#   --output-archive <path> Output native archive for libraries
#   --output-object <path>  Output single .o file for binaries/tests
#   --llc <path>            Path to llc compiler (default: llc)
#   --ar <path>             Path to ar tool (default: ar)
#   --llc-flags <flags>     Additional flags to pass to llc (optional)
#
# Exactly one of --output-archive or --output-object must be specified.

set -e -o pipefail

# Defaults
LLC_CMD="llc"
AR_CMD="ar"
INPUT_ARCHIVE=""
OUTPUT_ARCHIVE=""
OUTPUT_OBJECT=""
LLC_FLAGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input)
            INPUT_ARCHIVE="$2"
            shift 2
            ;;
        --output-archive)
            OUTPUT_ARCHIVE="$2"
            shift 2
            ;;
        --output-object)
            OUTPUT_OBJECT="$2"
            shift 2
            ;;
        --llc)
            LLC_CMD="$2"
            shift 2
            ;;
        --ar)
            AR_CMD="$2"
            shift 2
            ;;
        --llc-flags)
            LLC_FLAGS+=("$2")
            shift 2
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$INPUT_ARCHIVE" ]; then
    echo "Error: --input is required" >&2
    exit 1
fi

if [ -z "$OUTPUT_ARCHIVE" ] && [ -z "$OUTPUT_OBJECT" ]; then
    echo "Error: Either --output-archive or --output-object is required" >&2
    exit 1
fi

if [ -n "$OUTPUT_ARCHIVE" ] && [ -n "$OUTPUT_OBJECT" ]; then
    echo "Error: Cannot specify both --output-archive and --output-object" >&2
    exit 1
fi

# Create temporary directory for working
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Convert paths to absolute before changing directory
INPUT_ARCHIVE_ABS="$INPUT_ARCHIVE"
if [[ "$INPUT_ARCHIVE_ABS" != /* ]]; then
    INPUT_ARCHIVE_ABS="$PWD/$INPUT_ARCHIVE_ABS"
fi

OUTPUT_PATH=""
OUTPUT_IS_ARCHIVE=0
if [ -n "$OUTPUT_ARCHIVE" ]; then
    OUTPUT_PATH="$OUTPUT_ARCHIVE"
    OUTPUT_IS_ARCHIVE=1
else
    OUTPUT_PATH="$OUTPUT_OBJECT"
    OUTPUT_IS_ARCHIVE=0
fi

if [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="$PWD/$OUTPUT_PATH"
fi

# Change to work directory
cd "$WORK_DIR"

# Extract bitcode archive
"$AR_CMD" x "$INPUT_ARCHIVE_ABS"

# Find all object files (bitcode objects have .o extension)
shopt -s nullglob
OBJECT_FILES=(*.o)
if [ ${#OBJECT_FILES[@]} -eq 0 ]; then
    echo "Error: No object files found in bitcode archive $INPUT_ARCHIVE" >&2
    exit 1
fi

# Compile each bitcode object to native (in-place)
for bc_obj in "${OBJECT_FILES[@]}"; do
    # Create temporary output name
    native_obj="${bc_obj}.native"

    # Build llc command: --filetype=obj [llc-flags] input -o output
    LLC_ARGS=(--filetype=obj)
    LLC_ARGS+=("${LLC_FLAGS[@]}")
    LLC_ARGS+=("$bc_obj" -o "$native_obj")

    # Run llc
    "$LLC_CMD" "${LLC_ARGS[@]}"

    # Replace bitcode object with native object (to preserve original name)
    mv "$native_obj" "$bc_obj"
done

# Pack or copy output
if [ "$OUTPUT_IS_ARCHIVE" -eq 1 ]; then
    # Create archive from all native objects
    "$AR_CMD" rcs "$OUTPUT_PATH" "${OBJECT_FILES[@]}"
else
    # Single object mode: should have exactly one object
    if [ ${#OBJECT_FILES[@]} -ne 1 ]; then
        echo "Error: Expected single object for --output-object but found ${#OBJECT_FILES[@]} objects in archive" >&2
        exit 1
    fi

    # Copy the single object to output
    cp "${OBJECT_FILES[0]}" "$OUTPUT_PATH"
fi
