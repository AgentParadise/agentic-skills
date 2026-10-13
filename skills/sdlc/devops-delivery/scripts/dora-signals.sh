#!/usr/bin/env bash
# Read-only DORA proxy signals for one GitHub repository, computed from merged
# pull requests and published releases.
#
# Usage: dora-signals.sh [options]
#   --repo OWNER/NAME     repository (default: the current checkout's repo)
#   --days N              trailing window in days (default: 28)
#   --base BRANCH         only PRs merged into BRANCH (default: any base)
#   --hotfix-hours N      a patch release within N hours of the previous
#                         release marks that release as failed (default: 72)
#   --include-prereleases count prereleases as deployments (default: off)
#   --limit N             max releases to fetch (default: 1000); merged PRs
#                         come from GitHub search, which caps at 1000
#   --now ISO8601         treat this instant as now (default: current time)
#   --fixtures DIR        read DIR/prs.json (an array of the GraphQL search
#                         nodes below) and DIR/releases.json (gh release list
#                         --json shape) instead of calling gh; offline, used
#                         by the tests
#   --json                print the raw metrics object instead of Markdown
#
# Input:  `gh api graphql` (a read-only search for merged PRs, first commit
#         only) and `gh release list --json`. `gh pr list --json commits`
#         is avoided: GitHub rejects it above ~50 PRs (node limit).
# Output: a Markdown table on stdout (or JSON with --json). Every number is a
#         proxy; see references/dora-signals.md for what each one means and
#         where it lies.
# Needs:  bash, jq 1.6+, and gh (authenticated) unless --fixtures is given.
# Exit:   0 on success, 1 on bad arguments or a failed gh call.
set -euo pipefail

repo="" days=28 base="" hotfix_hours=72 prereleases=false limit=1000
now_iso="" fixtures="" as_json=false

die() { echo "dora-signals: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --days) days="${2:?}"; shift 2 ;;
    --base) base="${2:?}"; shift 2 ;;
    --hotfix-hours) hotfix_hours="${2:?}"; shift 2 ;;
    --include-prereleases) prereleases=true; shift ;;
    --limit) limit="${2:?}"; shift 2 ;;
    --now) now_iso="${2:?}"; shift 2 ;;
    --fixtures) fixtures="${2:?}"; shift 2 ;;
    --json) as_json=true; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$days$hotfix_hours$limit" in *[!0-9]*) die "--days, --hotfix-hours and --limit take integers" ;; esac
command -v jq >/dev/null || die "jq is required"

if [ -n "$now_iso" ]; then
  now="$(jq -nr --arg t "$now_iso" '$t | fromdateiso8601')" || die "bad --now: $now_iso"
else
  now="$(jq -n 'now | floor')"
fi
since_date="$(jq -nr --argjson n "$now" --argjson d "$days" '$n - $d * 86400 | strftime("%Y-%m-%d")')"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ -n "$fixtures" ]; then
  cp "$fixtures/prs.json" "$work/prs.json"
  cp "$fixtures/releases.json" "$work/releases.json"
  [ -n "$repo" ] || repo="fixtures"
else
  command -v gh >/dev/null || die "gh is required (or pass --fixtures)"
  [ -n "$repo" ] || repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)" \
    || die "cannot infer repo; pass --repo OWNER/NAME"
  search="repo:$repo is:pr is:merged merged:>=$since_date"
  [ -z "$base" ] || search="$search base:$base"
  # The search lower bound only trims the fetch; jq applies the exact window.
  # shellcheck disable=SC2016  # $q and $endCursor are GraphQL variables, not shell.
  gh api graphql --paginate -f q="$search" -f query='
    query($q: String!, $endCursor: String) {
      search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { ... on PullRequest {
          number title createdAt mergedAt baseRefName
          commits(first: 1) { nodes { commit { authoredDate } } }
        } }
      }
    }' --jq '.data.search.nodes[]' | jq -s . >"$work/prs.json" \
    || die "merged PR search failed for $repo"
  gh release list --repo "$repo" --limit "$limit" \
    --json tagName,publishedAt,isDraft,isPrerelease >"$work/releases.json" \
    || die "gh release list failed for $repo"
fi

metrics="$(jq -n \
  --slurpfile prs "$work/prs.json" \
  --slurpfile rels "$work/releases.json" \
  --arg repo "$repo" --arg base "$base" \
  --argjson now "$now" --argjson days "$days" \
  --argjson hotfix "$hotfix_hours" --argjson pre "$prereleases" '
  def ts: fromdateiso8601;
  def h: . / 3600;
  def q(p): sort | if length == 0 then null else .[((length - 1) * p) | floor] end;
  def ver: (ltrimstr("v")
      | capture("^(?<ma>[0-9]+)\\.(?<mi>[0-9]+)\\.(?<pa>[0-9]+)")
      | map_values(tonumber)) // null;
  def patch_of($prev): ver as $b | ($prev | ver) as $a
      | $a != null and $b != null and $a.ma == $b.ma and $a.mi == $b.mi and $b.pa > $a.pa;
  def summary: {median_hours: (map(h) | q(0.5)), p90_hours: (map(h) | q(0.9)), n: length};

  ($now - $days * 86400) as $since
  | def inwin: . >= $since and . <= $now;

  ($rels[0]
    | map(select((.isDraft | not) and .publishedAt != null and ($pre or (.isPrerelease | not))))
    | map(. + {t: (.publishedAt | ts)})
    | sort_by(.t)) as $all_rels
  | ($all_rels | map(select(.t | inwin))) as $win_rels

  | ($prs[0]
    | map(select(.mergedAt != null and ($base == "" or .baseRefName == $base)))
    | map(. + {m: (.mergedAt | ts), c: (.createdAt | ts)})
    | map(select(.m | inwin))
    | map(.c as $c | . + {f: ([.commits.nodes[]?.commit.authoredDate | ts] | min // $c)})
    | map(.m as $m | . + {r: ([$all_rels[] | select(.t >= $m) | .t] | min)})) as $win_prs

  | ([range(1; $all_rels | length)
      | {prev: $all_rels[. - 1], next: $all_rels[.]}
      | select(.prev.t | inwin)
      | select(.prev.tagName as $p | .next.tagName | patch_of($p))
      | select(.next.t - .prev.t <= $hotfix * 3600)
      | {failed: .prev.tagName, fix: .next.tagName, gap: (.next.t - .prev.t)}]) as $recoveries

  | ($win_prs | map(select(.title | test("^(revert|hotfix)"; "i"))) | length) as $reverts
  | ($win_prs | map(select(.title | test("^fix(\\(|:|!| )"; "i"))) | length) as $fixes
  | ($win_prs | length) as $n_prs
  | ($win_rels | length) as $n_rels

  | {
      repo: $repo, base: (if $base == "" then null else $base end),
      window_days: $days,
      since: ($since | todateiso8601), until: ($now | todateiso8601),
      merged_prs: $n_prs,
      releases: $n_rels,
      deployment_frequency_per_week: (if $days == 0 then null else ($n_rels / ($days / 7)) end),
      lead_time: {
        first_commit_to_merge: ($win_prs | map(.m - .f) | summary),
        pr_open_to_merge: ($win_prs | map(.m - .c) | summary),
        first_commit_to_release: ($win_prs | map(select(.r != null) | .r - .f) | summary),
        unreleased_prs: ($win_prs | map(select(.r == null)) | length)
      },
      change_fail: {
        revert_or_hotfix_prs: $reverts,
        fix_prs: $fixes,
        revert_or_hotfix_ratio: (if $n_prs == 0 then null else $reverts / $n_prs end),
        fix_ratio: (if $n_prs == 0 then null else $fixes / $n_prs end),
        releases_followed_by_patch: ($recoveries | length),
        release_fail_ratio: (if $n_rels == 0 then null else ($recoveries | length) / $n_rels end)
      },
      time_to_restore: ($recoveries | map(.gap) | summary
        + {pairs: ($recoveries | map({failed, fix, hours: (.gap | h)}))})
    }')"

if [ "$as_json" = true ]; then
  printf '%s\n' "$metrics"
  exit 0
fi

printf '%s\n' "$metrics" | jq -r '
  def r: if . == null then "n/a" else (. * 10 | round / 10 | tostring) end;
  def pc: if . == null then "n/a" else (. * 1000 | round / 10 | tostring) + "%" end;
  def lt: "median \(.median_hours | r)h, p90 \(.p90_hours | r)h (n=\(.n))";
  "## DORA proxy signals: \(.repo)\(if .base then " (base \(.base))" else "" end)",
  "",
  "Window: \(.since) to \(.until) (\(.window_days) days). \(.merged_prs) merged PRs, \(.releases) releases.",
  "",
  "| Key | Signal | Value |",
  "| --- | --- | --- |",
  "| Deployment frequency | releases per week | \(.deployment_frequency_per_week | r) |",
  "| Lead time | first commit to merge | \(.lead_time.first_commit_to_merge | lt) |",
  "| Lead time | PR open to merge | \(.lead_time.pr_open_to_merge | lt) |",
  "| Lead time | first commit to release | \(.lead_time.first_commit_to_release | lt); merged PRs not yet released: \(.lead_time.unreleased_prs) |",
  "| Change fail rate | revert or hotfix PRs / merged PRs | \(.change_fail.revert_or_hotfix_ratio | pc) (\(.change_fail.revert_or_hotfix_prs)) |",
  "| Change fail rate | fix PRs / merged PRs | \(.change_fail.fix_ratio | pc) (\(.change_fail.fix_prs)) |",
  "| Change fail rate | releases followed by a quick patch release | \(.change_fail.release_fail_ratio | pc) (\(.change_fail.releases_followed_by_patch)) |",
  "| Time to restore | failed release to patch release | \(.time_to_restore | lt) |",
  "",
  "All values are proxies from GitHub metadata. Read references/dora-signals.md before acting on them."
'
