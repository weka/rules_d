#!/bin/bash
# The compile action of a target must be the same with --//:exact_deps and with --//:record_unread_deps
# (command line, env, inputs, outputs), or the two builds stop sharing remote cache entries. Whether
# bazel is handed the unused list is not visible to Starlark and is not checked here.
#
# Usage: same_action_test.sh <description built with exact_deps> <description built with record_unread_deps>
set -u -o pipefail

exact=${TEST_TMPDIR:-/tmp}/exact
recorded=${TEST_TMPDIR:-/tmp}/recorded

# The flag is set by a transition here, which changes the configuration directory under bazel-out.
sed -E 's#bazel-out/[^/]+/#bazel-out/CONFIG/#g' "$1" > "$exact" || exit 1
sed -E 's#bazel-out/[^/]+/#bazel-out/CONFIG/#g' "$2" > "$recorded" || exit 1

if ! grep -q '^output: .*\.unused_inputs$' "$exact"; then
    echo "FAIL: no D compile that writes an unused list is described"
    exit 1
fi
if ! diff "$exact" "$recorded"; then
    echo "FAIL: the compile action differs (< exact_deps, > record_unread_deps)"
    exit 1
fi
echo "ok: same compile action"
