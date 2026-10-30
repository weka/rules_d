#!/bin/bash
# Checks what exact deps prunes for //d/tests/exact_deps:speculative, whose imports are all speculative
# (__traits(compiles, { import ... }), is(typeof({ import ... })), __traits(compiles, import("..."))).
# A file read that way must stay an input, so the unused list may hold only the files nothing imports.
#
# Usage: speculative_test.sh <unused_inputs files...>
set -u -o pipefail

unused=${TEST_TMPDIR:-/tmp}/unused_inputs
expected=${TEST_TMPDIR:-/tmp}/expected
cat -- "$@" | sort > "$unused" || exit 1
printf '%s\n' d/tests/exact_deps/dep/foo/unread.d d/tests/exact_deps/dep/strings/unread.txt > "$expected"

if diff "$expected" "$unused"; then
    echo "ok: only the files nothing imports are unused"
    exit 0
fi
echo "FAIL: unused inputs differ from the expected list (< expected, > actual)"
exit 1
