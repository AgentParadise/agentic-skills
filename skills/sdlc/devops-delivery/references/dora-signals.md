# DORA signals from GitHub metadata

What each DORA key means, the GitHub proxy `scripts/dora-signals.sh` computes for it, the query behind it, and where the proxy misleads. Read this before reporting any number from the script to a human.

## The definitions being approximated

From DORA's current guide (https://dora.dev/guides/dora-metrics/), which supersedes the four-key framing in Accelerate Chapter 2:

| DORA metric | Group | Definition (paraphrased from dora.dev) |
| --- | --- | --- |
| Change lead time | Throughput | Time from a change being committed to version control to it being deployed in production. |
| Deployment frequency | Throughput | Number of deployments over a period, or the time between deployments. |
| Failed deployment recovery time | Throughput | Time to recover from a deployment that fails and needs immediate intervention. Called "time to restore service" (MTTR) before the 2023 report. |
| Change fail rate | Instability | Share of deployments that need immediate intervention, typically a rollback or hotfix. |
| Deployment rework rate | Instability | Share of deployments that are unplanned and happen because of a production incident. Added in the 2024 report. |

History, from https://dora.dev/insights/dora-metrics-history/: the four keys settled in the 2015 research as throughput and stability; availability appeared in 2018 and was broadened to reliability in 2021; MTTR was renamed and redefined in 2023; deployment rework rate was added in 2024.

## The proxies

Window: trailing `--days` (default 28) ending at `--now` (default the current time). PRs are in the window by `mergedAt`; releases by `publishedAt`. Draft releases are ignored. Prereleases are ignored unless `--include-prereleases`.

| Key | Script signal | Computed as | Main way it lies |
| --- | --- | --- | --- |
| Deployment frequency | releases per week | non-draft releases in window / (days / 7) | Repos that deploy without a GitHub release (continuous deploy from `main`, container pushes, app stores) read as zero. Use deployments or the deploy workflow's runs instead (below). |
| Lead time | first commit to merge | `mergedAt` minus `authoredDate` of the PR's first commit (falls back to `createdAt` if the PR has no commits) | Author dates survive rebases and cherry-picks, so a resurrected old commit inflates it; squash-only workflows still keep the PR's commit list, so it holds. |
| Lead time | PR open to merge | `mergedAt` minus `createdAt` | Ignores time before the PR was opened; draft PRs opened early inflate it. |
| Lead time | first commit to release | first non-draft release with `publishedAt >= mergedAt`, minus first commit | Closest to DORA's definition when a release is the deployment. PRs merged after the last release are counted as `unreleased_prs`, not as zero. |
| Change fail rate | revert or hotfix PRs / merged PRs | titles starting with `revert` or `hotfix` (case-insensitive) | Depends on title conventions. GitHub's revert button produces `Revert "..."`, which matches. |
| Change fail rate | fix PRs / merged PRs | titles matching `^fix[(:! ]` | Ordinary bug fixes are not deployment failures. Treat as context, not as the rate. |
| Change fail rate | releases followed by a quick patch | release R counts as failed when the next release is a patch bump of R (same major and minor, higher patch, semver tags with optional `v`) within `--hotfix-hours` (default 72) | Scheduled patch releases look like failures; failures fixed in a minor release look like successes. |
| Time to restore | failed release to patch release | publish gap for each failed/patch pair above | Measures release-to-release, not detection-to-recovery. A failure noticed late reads as a long restore. |

The median is the conventional one (the mean of the two middle values for an even count). p90 is nearest rank, index `ceil(n * 0.9) - 1`, so with ten or fewer samples it is the slowest one. Releases published after `--now` are ignored, so a historical report never uses a later release. Small `n` is printed next to every lead-time row so a reader can discount it.

## Queries the script runs

Both are read-only. Run them by hand when you need a field the script does not print.

```bash
# Merged PRs in the window, first commit only (GitHub search caps results at 1000).
gh api graphql --paginate \
  -f q="repo:OWNER/NAME is:pr is:merged merged:>=2026-09-15 base:main" \
  -f query='query($q: String!, $endCursor: String) {
    search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { ... on PullRequest { number title createdAt mergedAt baseRefName
        commits(first: 1) { nodes { commit { authoredDate } } } } } } }' \
  --jq '.data.search.nodes[]'

gh release list --repo OWNER/NAME --limit 1000 --json tagName,publishedAt,isDraft,isPrerelease
```

`gh pr list --json commits` is deliberately not used: GitHub's GraphQL node limit rejects it once the page holds more than about fifty PRs ("requesting up to 1,000,000 possible nodes"), so it fails on exactly the busy repos worth measuring.

## When releases are not the deployment

Pick the event that actually puts code in front of users and count that instead:

```bash
# GitHub deployments API (environments).
gh api "repos/OWNER/NAME/deployments?environment=production&per_page=100" --jq '.[].created_at'

# Successful runs of the deploy workflow on the trunk.
gh run list --repo OWNER/NAME --workflow deploy.yml --branch main --status success \
  --limit 200 --json createdAt,headSha
```

For lead time against those, join each merged PR's merge commit (`gh pr view N --json mergeCommit`) to the first deploy whose `headSha` contains it (`git merge-base --is-ancestor`).

## Reading the output

- Compare windows, not repos. A 28-day window against the previous 28 days tells you direction; an industry benchmark table tells you little about one repo.
- Read the keys as a set. Lead time down with change fail rate up means batches got faster but less safe. Deployment frequency up with lead time flat usually means releases got cheaper but PRs did not get smaller.
- A long p90 with a short median means a few stuck PRs: run the PR backlog procedure, not CI optimization.
- A long first-commit-to-release with a short first-commit-to-merge means merged work waits for releases: run the release cadence procedure.
- Report every number as a proxy, with `n` and the window. Never present `fix_ratio` as the change failure rate.

## Testing the script

`scripts/test-dora-signals.sh` runs the script offline against `scripts/testdata/` (fixtures in the exact shape the GraphQL search and `gh release list` return) with a pinned `--now`, checks the Markdown report against `testdata/expected.md`, checks filtered JSON values, and asserts the script contains no mutating `gh` call. When you change the computation, update `expected.md` only after checking the new numbers by hand against the fixtures.
