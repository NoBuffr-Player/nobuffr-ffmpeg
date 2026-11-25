#!/usr/bin/env bash
# Verifies that the tools listed in toolchain.json are installed on this machine, at the listed
# versions, and prints what it found. Installs nothing. Exits 1 with the full list of problems.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT}/toolchain.json"
command -v jq >/dev/null || { echo "missing tool: jq (needed to read toolchain.json)" >&2; exit 1; }

bad=0
while IFS=$'\t' read -r name cmd want; do
    if ! command -v "$name" >/dev/null; then
        echo "MISSING  $name (expected ${want:-any version})" >&2; bad=1; continue
    fi
    if [[ -z "$cmd" ]]; then
        echo "ok       $name  $(command -v "$name")"; continue
    fi
    got=$(eval "$cmd" 2>&1 | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)
    if [[ -n "$want" && "$got" != "$want" ]]; then
        echo "VERSION  $name is ${got:-unknown}, expected $want" >&2; bad=1
    else
        echo "ok       $name  ${got:-unknown}"
    fi
done < <(jq -r '.tools[] | [.name, (.command // ""), (.version // "")] | @tsv' "$MANIFEST")

while IFS= read -r f; do
    if [[ -e "$f" ]]; then echo "ok       $f"; else echo "MISSING  $f" >&2; bad=1; fi
done < <(jq -r '.files[]' "$MANIFEST")

sdks=$(xcodebuild -showsdks 2>/dev/null)
while IFS= read -r s; do
    if grep -q "$s" <<<"$sdks"; then echo "ok       SDK $s"; else echo "MISSING  SDK $s" >&2; bad=1; fi
done < <(jq -r '.sdks[]' "$MANIFEST")

if [[ $bad -ne 0 ]]; then
    echo "toolchain does not match toolchain.json; fix the machine (or update toolchain.json on purpose). Nothing is installed." >&2
    exit 1
fi
echo "toolchain ok"
