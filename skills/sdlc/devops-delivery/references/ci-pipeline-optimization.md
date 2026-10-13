# CI pipeline optimization

How to find what makes CI slow or unreliable, the order to fix it in, and how to quarantine a flaky test without losing it. Read when someone says CI is slow, when the PR open-to-merge time is dominated by waiting for checks, or when re-runs are becoming routine.

Target, from DORA's continuous integration capability page: commit feedback in a few minutes, with an upper limit of about ten. Reliability matters as much as speed: DORA's test automation page says plainly "don't tolerate flaky tests".

## 1. Measure the jobs

Rank jobs by median wall-clock and count failures over recent trunk runs. Commands below are read-only.

```bash
R=OWNER/NAME
for id in $(gh run list --repo "$R" --branch main --limit 30 --json databaseId,status \
             --jq '.[] | select(.status=="completed") | .databaseId'); do
  gh run view "$id" --repo "$R" --json workflowName,jobs
done | jq -s -r '
  [ .[] | .workflowName as $w | .jobs[]
    | select(.startedAt and .completedAt and .startedAt != "0001-01-01T00:00:00Z")
    | {job: "\($w) / \(.name)", conclusion,
       secs: ((.completedAt | fromdateiso8601) - (.startedAt | fromdateiso8601))} ]
  | group_by(.job)
  | map({job: .[0].job, runs: length,
         median_min: ((map(.secs) | sort | .[(length - 1) / 2 | floor]) / 60 | . * 10 | round / 10),
         failures: (map(select(.conclusion == "failure")) | length)})
  | sort_by(-.median_min) | .[:10][]
  | "\(.median_min)m\t\(.failures)/\(.runs) failed\t\(.job)"'
```

Then look at the steps of the slowest job to see where its time goes:

```bash
gh run view <run-id> --repo "$R" --json jobs --jq '.jobs[] | select(.name == "<job>") | .steps[]
  | select(.startedAt and .completedAt)
  | [((.completedAt | fromdateiso8601) - (.startedAt | fromdateiso8601)), .name] | @tsv' | sort -nr
```

What matters is the critical path: the longest chain of `needs:` that a PR must wait for before its required checks report. A 15-minute job that runs in parallel with a 16-minute job is not the bottleneck. Also check queue time (`createdAt` of the run versus `startedAt` of its first job): if runners are scarce, no amount of job tuning helps.

For flakiness, look at PR runs as well as trunk runs, because flakes on PRs get re-run away:

```bash
gh run list --repo "$R" --limit 200 --json databaseId,attempt,conclusion,workflowName,headBranch \
  --jq '.[] | select(.attempt > 1) | [.workflowName, .headBranch, .attempt, .conclusion] | @tsv'
```

A workflow that frequently needs `attempt > 1` to pass is hiding a flake.

## 2. Fix in this order

Cheapest and safest first. Re-measure after each step.

1. **Cancel superseded runs.** Add a concurrency group so a new push to a PR cancels the old run, while every trunk and release commit gets its own group:

   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.run_id }}
     cancel-in-progress: ${{ github.event_name == 'pull_request' }}
   ```

   `cancel-in-progress: false` alone is not enough on trunk: a group holds one running and one pending run, so with A running and B pending, C replaces B and B never runs. Grouping non-PR runs by `github.run_id` gives each trunk commit a complete record.

2. **Cache dependencies and build outputs.** Use the language setup action's built-in cache (`actions/setup-node` with `cache:`, `actions/setup-python` or `astral-sh/setup-uv` with caching, `Swatinem/rust-cache` for Cargo) or `actions/cache` keyed on the lockfile hash. Check the cache hit rate in the step log after the change; a key that includes something volatile never hits.

3. **Skip work the change cannot affect.** The trap: a required status check in a workflow that a workflow-level `paths:` / `paths-ignore:` filter skips leaves the PR waiting forever, because a skipped workflow schedules no jobs at all, an `if: always()` job included. So keep the workflow that carries required checks unfiltered: detect changes inside it (a `dorny/paths-filter` step, or `git diff --name-only`, exposed as job outputs), skip expensive jobs with job-level `if:` conditions, and make one always-running aggregate job the only required check:

   ```yaml
   required:
     if: always()
     needs: [lint, test, build]
     runs-on: ubuntu-latest
     steps:
       - run: |
           for r in ${{ join(needs.*.result, ' ') }}; do
             case "$r" in success|skipped) ;; *) exit 1 ;; esac
           done
   ```

   Only allow `skipped` for jobs that are meant to be skippable; otherwise a broken `if:` silently passes.

4. **Run independent jobs in parallel; split the long one.** Remove unnecessary `needs:` chains. Shard a long test job with a matrix (`pytest-split`, `jest --shard`, `cargo nextest --partition`, Playwright `--shard`). Sharding multiplies runner minutes for the setup portion, so cache first.

5. **Move slow, rarely-failing suites off the PR path.** Run them on the trunk, on a schedule, or in the merge queue (`merge_group` trigger), and make sure a failure there pages someone and blocks the next release. This trades a little change failure risk for a lot of lead time; do it consciously, and only for suites whose failure history justifies it.

6. **Bigger runners or a faster toolchain** last, once the waste is gone; otherwise you pay more for the same waste.

## 3. Quarantine a flaky test, do not bury it

A flaky test is confirmed when the same commit fails and then passes with no code change, and the failure is unrelated to the diff. Then:

1. File an issue: test id, two or more run URLs showing the flake, the error text, and a suspected cause (ordering, time, network, shared state).
2. Quarantine with the runner's native mechanism and link the issue in the marker, for example a pytest marker excluded from the required job, `test.skip` with the issue URL, or a separate non-required "quarantine" job that still runs and reports.
3. Give it an owner and a deadline. A quarantine list that only grows is deletion by neglect.
4. Fix the cause, remove the marker, and close the issue in the same PR.

Blanket automatic retries (`retry: 3` on the whole suite) are the opposite of quarantine: they hide new flakes and real intermittent bugs together. If a runner supports reporting retried-then-passed tests (nextest, Playwright, pytest-rerunfailures with reporting), keep the report and treat every entry as a flake candidate.

## 4. Mirror local gates in CI

Every rule a pre-commit or pre-push hook enforces must also run in CI, or it is advisory. The reverse is useful too: a single local command that runs what CI runs (a `make ci`, `just ci`, or script target) lets authors and agents get CI's verdict before pushing. When adding a check, add it to CI first and to the local target second.

## 5. Report before and after

State the jobs touched, the median and p90 over a comparable set of runs before and after (same branch, similar change mix), and any risk moved (for example, a suite moved off the PR path). One fast run is not evidence.
