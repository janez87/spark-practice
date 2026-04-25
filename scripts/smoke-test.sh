#!/usr/bin/env bash
# Runs every test under tests/smoke/. Exits non-zero on first failure
# but always prints a summary at the end.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${REPO_ROOT}/tests/smoke"

shopt -s nullglob
tests=("${TESTS_DIR}"/test_*.sh)
if (( ${#tests[@]} == 0 )); then
    echo "No smoke tests found under ${TESTS_DIR}" >&2
    exit 1
fi

pass=0
fail=0
failed_tests=()

for t in "${tests[@]}"; do
    name="$(basename "${t}")"
    echo "=== ${name} ==="
    if bash "${t}"; then
        echo "PASS: ${name}"
        ((pass++))
    else
        echo "FAIL: ${name}"
        failed_tests+=("${name}")
        ((fail++))
    fi
    echo
done

echo "Smoke summary: ${pass} passed, ${fail} failed"
if (( fail > 0 )); then
    printf '  - %s\n' "${failed_tests[@]}"
    exit 1
fi
