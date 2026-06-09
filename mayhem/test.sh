#!/usr/bin/env bash
# tinyxml2/mayhem/test.sh — RUN tinyxml2's own functional suite (the `xmltest` binary built by
# mayhem/build.sh with normal flags) → CTRF. PATCH-grade oracle: it never compiles, only runs.
# xmltest reads/writes resources/ relative to the repo root, so we run it from $SRC. It prints a
# final "Pass <P>, Fail <F>" line and exits with the failure count.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN="$SRC/build-tests/xmltest"
[ -x "$BIN" ] || { echo "missing $BIN — run mayhem/build.sh first" >&2; exit 2; }
mkdir -p "$SRC/resources/out"

# Run from the repo root so xmltest finds resources/. It exits with gFail (failure count); capture
# output regardless of exit code so we can parse the final "Pass P, Fail F" line.
out="$("$BIN" 2>&1)"; rc=$?; echo "$out"

passed=$(printf '%s\n' "$out" | sed -n 's/^Pass \([0-9][0-9]*\), Fail [0-9][0-9]*$/\1/p' | tail -1)
failed=$(printf '%s\n' "$out" | sed -n 's/^Pass [0-9][0-9]*, Fail \([0-9][0-9]*\)$/\1/p' | tail -1)

# Fall back to the binary's exit code for failures if the summary line is missing.
if [ -z "${passed:-}" ] && [ -z "${failed:-}" ]; then
  echo "could not parse xmltest summary ('Pass P, Fail F'); using exit code $rc" >&2
  emit_ctrf "tinyxml2-xmltest" 0 "$rc"
  exit $?
fi
: "${passed:=0}" "${failed:=0}"

emit_ctrf "tinyxml2-xmltest" "$passed" "$failed"
