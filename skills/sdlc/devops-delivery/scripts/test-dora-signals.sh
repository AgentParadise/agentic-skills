#!/usr/bin/env bash
# Offline tests for dora-signals.sh. No network, no gh calls.
#
# Usage: scripts/test-dora-signals.sh
# Runs the script against testdata/ with a pinned --now and checks the
# Markdown report byte for byte, the JSON metrics for a filtered run, argument
# rejection, and that the script contains no mutating gh call.
# Needs: bash, jq. Exit 0 when every check passes, 1 otherwise.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/dora-signals.sh"
data="$here/testdata"
now="2026-10-13T00:00:00Z"
fail=0

check() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi
}

# 1. Markdown report over the default window matches the reviewed snapshot.
if diff -u "$data/expected.md" <("$script" --fixtures "$data" --now "$now"); then
  echo "ok   markdown report matches testdata/expected.md"
else
  echo "FAIL markdown report drifted from testdata/expected.md"; fail=1
fi

# 2. Base filter and prereleases change the numbers the way the reference says.
json="$("$script" --fixtures "$data" --now "$now" --base main --include-prereleases --json)"
get() { printf '%s' "$json" | jq -c "$1"; }
check "base filter drops the release-branch PR" "$(get .merged_prs)" "4"
check "prerelease counted as a deployment" "$(get .releases)" "4"
check "lead time median, first commit to merge (even n averages)" "$(get .lead_time.first_commit_to_merge.median_hours)" "4.5"
check "p90 is nearest rank, keeps the slowest sample" "$(get .lead_time.first_commit_to_merge.p90_hours)" "24"
check "PR with no commits falls back to createdAt" "$(get .lead_time.first_commit_to_merge.n)" "4"
check "revert counted, hotfix on other base excluded" "$(get .change_fail.revert_or_hotfix_prs)" "1"
check "rc patch within window marks v1.3.0 failed" "$(get '[.time_to_restore.pairs[].failed]')" '["v1.2.0","v1.3.0"]'
check "draft release ignored" "$(get '[.time_to_restore.pairs[].fix] | index("v1.4.0")')" "null"

# 3. A window with no activity yields n/a, not a division error.
empty="$("$script" --fixtures "$data" --now 2026-12-31T00:00:00Z --days 7 --json)"
check "empty window has null ratios" "$(printf '%s' "$empty" | jq -c '[.change_fail.fix_ratio, .lead_time.pr_open_to_merge.median_hours]')" "[null,null]"

# 3b. Historical reports ignore releases published after --now.
early="$("$script" --fixtures "$data" --now 2026-10-03T00:00:00Z --json)"
check "later patch release is not a recovery yet" "$(printf '%s' "$early" | jq -c '[.change_fail.release_fail_ratio, .time_to_restore.n]')" "[0,0]"
mid="$("$script" --fixtures "$data" --now 2026-10-06T00:00:00Z --json)"
check "PR not matched to a release published after --now" "$(printf '%s' "$mid" | jq -c '[.lead_time.unreleased_prs, .lead_time.first_commit_to_release.n]')" "[1,2]"
two="$("$script" --fixtures "$data" --now 2026-10-04T00:00:00Z --base main --json)"
check "two-sample median is the mean, p90 the larger" "$(printf '%s' "$two" | jq -c '[.lead_time.first_commit_to_merge.median_hours, .lead_time.first_commit_to_merge.p90_hours]')" "[4.5,6]"

# 4. Bad arguments exit non-zero.
if "$script" --days seven --fixtures "$data" >/dev/null 2>&1; then
  echo "FAIL non-integer --days accepted"; fail=1
else
  echo "ok   non-integer --days rejected"
fi

# 5. Read-only: the script never calls a mutating gh subcommand or HTTP verb.
if grep -nE 'gh (pr (merge|create|edit|close|review|comment|ready)|release (create|delete|edit|upload)|run (rerun|cancel)|issue)|-X *(POST|PUT|PATCH|DELETE)|--method' "$script"; then
  echo "FAIL dora-signals.sh contains a mutating gh call"; fail=1
else
  echo "ok   dora-signals.sh is read-only"
fi

exit "$fail"
