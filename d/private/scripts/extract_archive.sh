#!/bin/bash
# Extracts an archive to a directory
#
# Usage:
#   extract_archive.sh <archive> <directory>
#
# Arguments:
#   archive: The archive to extract
#   directory: The directory to extract to
# Environment variables:
#   AR_CMD: The ar command to use (default: "ar")

set -e -o pipefail

# Defaults
if [ -z "$AR_CMD" ]; then
    AR="ar"
else
    AR="$(realpath $AR_CMD)"
fi

ARCHIVE="$(realpath $1)"
DIRECTORY="$2"

cd "$DIRECTORY"
"$AR" x "$ARCHIVE"
