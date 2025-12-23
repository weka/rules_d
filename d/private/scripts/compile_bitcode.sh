#!/bin/bash
# Specialized tool for compiling bitcode to native code
# Handles two workflows:
#   1. Single object: compile .bc.o -> .o
#   2. Archive: unpack .bc.a -> compile all -> pack to .a or output single .o
#
# Usage:
#   llc_archive_compiler.sh --input-object <bc.o> --output <native.o> [options]
#   llc_archive_compiler.sh --input-lib <bc.a> --output <native.a> [options]
#
# Options:
#   --input-object <path>   Input single bitcode object file
#   --input-lib <path>      Input bitcode archive (library)
#   --output <path>         Output file path (required)
#   --llc <path>            Path to llc compiler (default: llc)
#   --ar <path>             Path to ar tool (default: ar)
#   --llc-flags <flags>     Additional flags to pass to llc (optional)
#
# Exactly one of --input-object or --input-lib must be specified.

set -e -o pipefail

# Defaults
LLC_CMD="llc"
AR_CMD="ar"
INPUT_OBJECT=""
INPUT_LIB=""
OUTPUT=""
LLC_FLAGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-object)
            INPUT_OBJECT="$2"
            shift 2
            ;;
        --input-lib)
            INPUT_LIB="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --llc)
            LLC_CMD="$(realpath $2)"
            shift 2
            ;;
        --ar)
            AR_CMD="$(realpath $2)"
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
if [ -z "$INPUT_OBJECT" ] && [ -z "$INPUT_LIB" ]; then
    echo "Error: Either --input-object or --input-lib is required" >&2
    exit 1
fi

if [ -n "$INPUT_OBJECT" ] && [ -n "$INPUT_LIB" ]; then
    echo "Error: Cannot specify both --input-object and --input-lib" >&2
    exit 1
fi

if [ -z "$OUTPUT" ]; then
    echo "Error: --output is required" >&2
    exit 1
fi

# Create temporary directory for working
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Convert paths to absolute before changing directory
if [ -n "$INPUT_OBJECT" ]; then
    INPUT_ABS="$INPUT_OBJECT"
else
    INPUT_ABS="$INPUT_LIB"
fi

if [[ "$INPUT_ABS" != /* ]]; then
    INPUT_ABS="$PWD/$INPUT_ABS"
fi

OUTPUT_ABS="$OUTPUT"
if [[ "$OUTPUT_ABS" != /* ]]; then
    OUTPUT_ABS="$PWD/$OUTPUT_ABS"
fi

# Determine if output is an archive based on extension
OUTPUT_IS_ARCHIVE=0
if [[ "$OUTPUT_ABS" == *.a ]]; then
    OUTPUT_IS_ARCHIVE=1
fi

# Handle compilation based on input type
if [ -n "$INPUT_OBJECT" ]; then
    # Single object: compile directly to output
    LLC_ARGS=(--filetype=obj)
    LLC_ARGS+=("${LLC_FLAGS[@]}")
    LLC_ARGS+=("$INPUT_ABS" -o "$OUTPUT_ABS")

    "$LLC_CMD" "${LLC_ARGS[@]}"
else
    # Archive: extract, compile, pack
    INPUT_DIR="$WORK_DIR/input"
    OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

    # Extract bitcode archive
    cd "$INPUT_DIR"
    "$AR_CMD" x "$INPUT_ABS"

    # Find all object files
    shopt -s nullglob
    OBJECT_FILES=(*.o)
    if [ ${#OBJECT_FILES[@]} -eq 0 ]; then
        echo "Error: No object files found in bitcode archive $INPUT_LIB" >&2
        exit 1
    fi

    # Compile each bitcode object to native
    for bc_obj in "${OBJECT_FILES[@]}"; do
        LLC_ARGS=(--filetype=obj)
        LLC_ARGS+=("${LLC_FLAGS[@]}")
        LLC_ARGS+=("$INPUT_DIR/$bc_obj" -o "$OUTPUT_DIR/$bc_obj")

        "$LLC_CMD" "${LLC_ARGS[@]}"
    done

    # Pack or output single object
    cd "$OUTPUT_DIR"
    if [ "$OUTPUT_IS_ARCHIVE" -eq 1 ]; then
        # Create archive from all native objects
        "$AR_CMD" rcs "$OUTPUT_ABS" *.o
    else
        # Single object mode: should have exactly one object
        NATIVE_OBJS=(*.o)
        if [ ${#NATIVE_OBJS[@]} -ne 1 ]; then
            echo "Error: Expected single object but found ${#NATIVE_OBJS[@]} objects in archive" >&2
            exit 1
        fi

        mv "${NATIVE_OBJS[0]}" "$OUTPUT_ABS"
    fi
fi
