# PR backlog hygiene

The full procedure for turning an open-PR backlog into a short, ordered, honest list. Read when PRs are piling up, when lead time p90 is long, or before handing a merge batch to whoever holds merge authority.

## Authority first

Before touching anything, establish from the repo-local overlay (or the user) what you may do. The default for an agent maintainer is:

| Action | Default |
| --- | --- |
| Read PRs, checks, logs, reviews | Allowed |
| Merge the trunk into a branch you authored, push it | Allowed |
| Re-run a failed check once | Allowed |
| Comment on a PR with triage findings | Allowed when the repo lets agents comment |
| Push to someone else's branch | Ask first |
| Close a PR | Propose; close only when granted |
| Approve a review, merge a PR, approve a deployment gate | Not allowed unless explicitly granted |
| Force-push, rebase a shared branch, bypass branch protection, `--no-verify` | Not allowed |

The reason for the strict defaults is the change approval finding in Accelerate Ch. 7 and DORA's streamlining-change-approval page: lightweight approval works because a second party reviews the change. An agent approving its own work removes the second party.

## 1. Inventory

```bash
gh pr list --repo OWNER/NAME --state open --limit 200 --json \
  number,title,author,isDraft,createdAt,updatedAt,baseRefName,headRefName,\
mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,labels \
  > "${TMPDIR:-/tmp}/prs.json"

jq -r --argjson now "$(date +%s)" '
  sort_by(.createdAt) | .[] |
  [ .number,
    ((($now - (.createdAt | fromdateiso8601)) / 86400) | floor | tostring) + "d",
    (if .isDraft then "draft" else "open" end),
    .mergeable, .mergeStateStatus,
    (if (.reviewDecision // "") == "" then "NONE" else .reviewDecision end),
    ([.statusCheckRollup[]? | if (.conclusion // "") == "" then (.state // .status) else .conclusion end] | map(select(. != "SUCCESS" and . != "SKIPPED" and . != "NEUTRAL")) | unique | join(",")),
    .title ] | @tsv' "${TMPDIR:-/tmp}/prs.json"
```

`mergeStateStatus` values worth knowing: `CLEAN` (mergeable, checks pass), `BEHIND` (base moved, branch protection requires up to date), `DIRTY` (conflicts), `BLOCKED` (missing review or required check), `UNSTABLE` (non-required check failing), `UNKNOWN` (GitHub still computing; read again).

## 2. Classify

Put every PR in exactly one class. The class decides the next action.

| Class | How you know | Next action |
| --- | --- | --- |
| Ready | `CLEAN`, review approved or not required | Put in the merge-order table |
| Needs main | `BEHIND` or `DIRTY` | Merge trunk in (step 3) |
| CI red, real | Same check fails twice, or log shows an assertion tied to the diff | Diagnose; fix if yours, comment if not |
| CI red, flake | Fails once, passes on one re-run, failure unrelated to the diff | Record it; file or update a flake issue |
| Waiting on review | `REVIEW_REQUIRED`, checks green | Name the reviewer in the table |
| Waiting on author | `CHANGES_REQUESTED` or unanswered comments | Name the author and the open comment |
| Superseded or abandoned | Another PR does the same, or no activity for the repo's stale threshold | Propose closing, with the reason |
| Stacked | Base is another PR's branch | Land the bottom first; do not merge the trunk into upper layers until the base lands |

## 3. Merge the trunk in, do not rebase shared branches

For a branch you own and others may have pulled or reviewed:

```bash
git fetch origin
git switch <branch>
git merge origin/main        # resolve conflicts, run the repo's local gate
git push origin <branch>
```

Merging keeps review comments attached and never rewrites a commit someone else holds. Rebase only unpushed local commits. If the repo-local overlay mandates rebase-and-force-push, follow it; that is a repo decision, not a default.

## 4. Re-run once, then diagnose

```bash
gh run rerun <run-id> --failed
```

One re-run distinguishes a flake from a real failure cheaply. A second failure, or a different failure, is a signal: read the log (`gh run view <run-id> --log-failed`) and find the cause. Retrying until green converts real failures into hidden ones and keeps the flake forever. When the re-run passes, record the flake (test name, run URL, error) in an issue so the CI procedure can quarantine it.

## 5. Close the dead weight

Superseded and abandoned PRs inflate every backlog metric and hide the PRs that matter. Comment with the reason ("superseded by #N", "no activity for 30 days, reopen when resumed"), then close if granted, or list them for the owner.

## 6. Publish the table and the merge order

Hand over a single table. One row per PR, sorted by proposed merge order.

```markdown
| Order | PR | Age | Class | Blocker | Owner of next step |
| --- | --- | --- | --- | --- | --- |
| 1 | #412 fix: null owner | 1d | Ready | none | maintainer: merge |
| 2 | #409 feat: export | 3d | Ready after #412 | touches same file | maintainer: merge |
| - | #401 refactor: client | 12d | CI red, real | test_client fails on main merge | author |
| - | #388 docs: old guide | 40d | Superseded by #405 | none | maintainer: close |
```

Merge-order heuristic, in priority: fixes for a broken trunk first; then smallest diff; then PRs others depend on (bottom of a stack); then oldest. Re-check `mergeStateStatus` after each merge because each one can make the next `BEHIND`.

## WIP limit

Pick a number of open non-draft PRs per author (human or agent) above which no new PR is opened until one lands or closes. DORA's WIP-limits guidance: base the limit on capacity, and treat multitasking as a sign the limit is too high. Reaching the limit is a trigger to land or close, not to stop work.
