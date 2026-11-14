#!/usr/bin/env bash
# Runs every Lua suite with lua5.4. A failing suite fails the run, and so does a suite that
# prints SKIP (its DMM-parser half did not run) unless MCS_ALLOW_SKIP=1. With the flag each
# skipped suite is still listed, as a GitHub warning when run in Actions.
set -u
failed=0
skipped=()
for test in tests/*_test.lua; do
    if ! output=$(lua5.4 "$test" 2>&1); then
        echo "FAIL $test"
        echo "$output"
        failed=1
        continue
    fi
    echo "$output"
    if grep -q '^SKIP' <<<"$output"; then skipped+=("$test"); fi
done
if [ "$failed" -ne 0 ]; then exit 1; fi
if [ "${#skipped[@]}" -gt 0 ]; then
    for test in "${skipped[@]}"; do
        if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning file=$test::$test skipped its DMM parser checks (DMM_CHOICES_PATH unset)"
        else echo "SKIPPED $test"; fi
    done
    if [ "${MCS_ALLOW_SKIP:-}" != "1" ]; then
        echo "${#skipped[@]} suite(s) skipped; set DMM_CHOICES_PATH to DMM's choices.lua, or MCS_ALLOW_SKIP=1 to accept the skips"
        exit 1
    fi
fi
echo "All Lua suites passed${skipped[*]:+ (${#skipped[@]} with parser checks skipped)}"
