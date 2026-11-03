#!/bin/bash
# Checks the time_traces output group of //:ctfe_test, a d_test over the d_library //:ctfe_lib.
# With the tracing toolchain, each compiled target returns its own profile, and each profile
# holds a "CTFE func:" event located at a line of that target's source. With the default
# toolchain, the group is empty.
#
# Usage: time_trace_test.sh <list of profiles with tracing> <list of profiles without>
set -u -o pipefail

mapfile -t on < "$1" || exit 1
mapfile -t off < "$2" || exit 1

status=0
fail() {
    echo "FAIL: $*"
    status=1
}

names=$(for f in "${on[@]}"; do basename "$f"; done | sort | tr '\n' ' ')
[[ $names == "ctfe_lib.time-trace ctfe_test.time-trace " ]] ||
    fail "expected one profile per compiled target, got: $names"

for f in "${on[@]}"; do
    src=$(basename "$f" .time-trace).d
    grep -Eq "\"CTFE func: [^\"]*\"[^}]*\"loc\": *\"[^\"]*$src:[0-9]+\"" "$f" ||
        fail "$f has no CTFE func: event located in $src"
done

[[ ${#off[@]} -eq 0 ]] || fail "expected no profiles with the default toolchain, got: ${off[*]}"

[[ $status -eq 0 ]] && echo "ok: one profile per compiled target, each with its CTFE events; none by default"
exit $status
