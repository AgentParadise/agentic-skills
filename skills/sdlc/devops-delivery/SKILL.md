---
name: devops-delivery
description: Use when acting as a repository's DevOps maintainer or judging its delivery health against Accelerate and DORA research. Trigger phrases include "keep PRs tidy", "PR backlog", "stale PRs", "why are PRs piling up", "CI is slow", "speed up CI", "flaky tests in CI", "DORA metrics", "four keys", "Accelerate", "lead time", "deploy frequency", "change failure rate", "MTTR", "time to restore", "release cadence", "how often should we release", "deployment pipeline", "trunk-based development", "WIP limit on PRs". Covers measuring the four keys from GitHub with `gh`, PR backlog triage, CI pipeline speed and flake handling, and release cadence. Do NOT use for writing a single commit (use `commit`), reviewing one PR's code (use `review`), writing infrastructure as code (Terraform, Pulumi, CloudFormation, Kubernetes manifests, Helm) or provisioning cloud resources even when they serve a deploy pipeline, or incident response runbooks and on-call paging.
---

# DevOps delivery

## Overview

A repository's delivery system is everything between a developer's first commit and a change running for users: branches, pull requests, CI, review, release, and recovery. Accelerate (Forsgren, Humble and Kim, 2018) and the DORA research behind it found that speed and stability are not a trade-off in that system: the same capabilities (small batches, trunk-based development, fast CI, deployment automation, loosely coupled architecture, limited work in progress) predict both. An agent maintaining a repo can move those capabilities directly, because most of them live in files and settings the agent can read: the PR queue, the workflow YAML, the release history. This skill frames that maintainer role around the four DORA keys, gives a checkable signal for each, and supplies the procedures that move them.

## Outcomes we are looking for

The four keys come from Accelerate Chapter 2 ("Measuring Performance"). DORA has since refined them; see the note after Outcome 4. Each signal below is a proxy computed from GitHub metadata by `scripts/dora-signals.sh`; `references/dora-signals.md` says exactly what each proxy measures and where it lies.

### Outcome 1: changes reach users often (deployment frequency)

A repo that releases often ships small, low-risk batches and learns from users quickly. A repo that releases monthly accumulates risk in every release.

- *Signal:* releases (or deployments) per week over a trailing 28-day window, from `gh release list`. Trending flat or up, never a long silence while PRs keep merging.

### Outcome 2: a change moves from first commit to users quickly (lead time for changes)

Short lead time means feedback arrives while the author still remembers the change. Long lead time means stale branches, painful merges, and fixes that wait behind unrelated work.

- *Signal:* median and p90 hours from a PR's first commit to merge, and from PR open to merge, for PRs merged in the window.
- *Signal:* median hours from first commit to the first release published after the merge (closest to DORA's "committed to deployed" definition when releases are the deployment).

### Outcome 3: changes rarely need immediate intervention (change failure rate)

A low change failure rate shows that CI, review and small batches catch problems before users do. It is the counterweight that stops the speed outcomes being met by shipping carelessly.

- *Signal:* share of merged PRs that are reverts or hotfixes, and share of releases followed within 72 hours by a patch release.

### Outcome 4: when a change does fail, service is restored fast (time to restore service)

Failures will happen. What separates high performers is how fast they recover, which depends on small changes, automated deploys, and the ability to roll forward or back without ceremony.

- *Signal:* hours from a release that needed a fix to the patch release that fixed it.

A note on the newer metrics, for accuracy when reporting: DORA added reliability (operational performance) as a fifth measure in the 2021 report, renamed time to restore service to **failed deployment recovery time** in 2023 (to exclude failures not caused by a change, such as a data-center outage), and added **deployment rework rate** in 2024. DORA's current model has five delivery metrics grouped as throughput (change lead time, deployment frequency, failed deployment recovery time) and instability (change fail rate, deployment rework rate). Sources: https://dora.dev/guides/dora-metrics/ and https://dora.dev/insights/dora-metrics-history/. The proxies here map onto the original four; GitHub metadata cannot separate rework from failure without repo-specific labels.

## Principles

Each principle names the Accelerate capability it comes from (chapter numbers are from the book's own Quick Reference) and the DORA capability page that keeps it current. `references/sources.md` holds the full mapping.

1. **Integrate in small batches on a short-lived trunk.** Branches that live hours, not weeks, merge cleanly, review fast, and make every release smaller. DORA's trunk-based development guidance is concrete: three or fewer active branches, merge to trunk at least daily, no code freezes. As a maintainer, treat a PR older than a few days as a delivery problem first and a code problem second. (Trunk-based development and continuous delivery: Accelerate Ch. 4; working in small batches: Ch. 8.)

2. **Keep CI fast and trustworthy, because it is the feedback loop.** DORA's continuous integration page puts the ceiling at about ten minutes for commit feedback and says a build that cannot be fixed in minutes should be reverted. A flaky test is worse than a slow one: it teaches everyone to retry instead of read. Spend maintainer time on the slowest job and the least reliable test before anything else. (Continuous integration and test automation: Ch. 4.)

3. **Automate deployment so a release is a non-event.** When cutting a release is one reviewed merge or one tag, it can happen daily; when it is a checklist, it happens monthly and carries a month of risk. Push every manual release step into the pipeline, and keep the human gate where the repo puts it. (Deployment automation: Ch. 4.)

4. **Prefer a loosely coupled architecture, and let the pipeline reflect it.** Accelerate found that whether a team can test and deploy its part of the system independently mattered more to delivery performance than what kind of system it was (for example, a system of record versus a system of engagement). For a maintainer this shows up as path-filtered jobs, independently releasable packages, and contract tests at seams, so a docs change does not wait on a 20-minute integration suite. (Loosely coupled architecture: Ch. 5.)

5. **Limit work in progress, and make the queue visible.** Every open PR is inventory: it ages, conflicts, and blocks reviewers' attention. DORA notes WIP limits help most when combined with visible work and monitoring, so publish the backlog table and land or close before opening more. (WIP limits and visualizing work: Ch. 7.)

6. **Shift security left into the PR pipeline.** A dependency or secret scan on every PR costs seconds; finding the same issue after release costs a hotfix and counts against change failure rate. Pin third-party actions and tools so the pipeline itself is not the attack path. (Shift left on security: Ch. 6.)

7. **Measure to learn, never to rank.** Accelerate Ch. 2 chose outcome measures precisely because output measures (lines of code, velocity) are easy to game. Read the four signals together: lead time improving while change failure rate climbs is not progress. Report proxies as proxies. (Measuring performance: Ch. 2; monitoring: Ch. 7.)

8. **Use peer review and automation as the change approval, and respect the gates the repo sets.** DORA's change approval research (2019 report) found heavyweight external approval slowed delivery with no evidence of lower change fail rates; peer review plus automated tests worked better. Lightweight does not mean self-approved: an agent never approves its own deploy gate or merges unless the repo explicitly grants that authority. (Change approval processes: Ch. 7.)

## Anti-patterns

Observations from repos where delivery has degraded. Each names what an auditor sees and what it costs.

- **Stacked stale PRs.** A chain of PRs each based on the last, none merged, all drifting from `main`. Every rebase or merge of the base invalidates the reviews above it, so the stack ages faster than it lands. Lead time for everything in the stack grows together.
- **Big-batch releases.** Release notes with forty items after six weeks of silence. Change failure rate rises because any one item can fail the release, and time to restore rises because finding which item failed is now a bisect.
- **Retry-until-green.** A failed check is re-run three or four times until it passes, with no issue filed. The flake stays, the real failures it hides stay, and the team learns that red means "try again".
- **Rewriting shared history.** Force-pushing or rebasing a branch someone else has pulled or reviewed. Review comments detach from code, collaborators lose work, and the audit trail of what was reviewed is gone.
- **Approving your own gate.** The author (human or agent) of a change approves the environment or release gate that guards it. The gate becomes ceremony and the change approval control is gone, which is exactly what DORA's lightweight-approval finding does not endorse.
- **Local-only gates.** A pre-push hook or `make check` target enforces a rule CI does not run. Contributors who skip the hook (or agents in a different environment) merge violations, and the rule is believed to hold when it does not.
- **CI that runs everything on every change.** A one-line docs fix waits on the full integration matrix. Lead time is set by the slowest job regardless of what changed, and runner cost scales with PR count.
- **No concurrency cancellation.** Three pushes to one PR produce three full CI runs, the first two of which nobody will read. The queue backs up for every other PR.
- **Release notes written at release time.** Someone reconstructs six weeks of changes from commit subjects the day of the release. Notes are thin, the release is delayed, and users cannot tell what changed.
- **Metrics as targets.** Deployment frequency is raised by tagging empty releases, or lead time by opening PRs only when the work is done. The number moves; delivery does not.
- **Required checks that a path filter can skip.** A required status check lives in a workflow that `paths:` filters out, so docs-only PRs wait forever on a check that never runs. Teams respond by making the check optional, and lose the gate everywhere.

## Repo-local overlay first

Repo specifics win over this skill. Before acting, look for a repo-local devops skill or document: `.claude/skills/devops/`, `.agents/skills/*devops*`, `docs/release-process.md`, `CONTRIBUTING.md`, `RELEASING.md`, or a release section in `AGENTS.md` / `CLAUDE.md`. When one exists, it defines the branch model, who may merge, which gates need a human, how versions are bumped, and what "released" means for that repo. Read it, follow it, and use this skill only for what it leaves open.

A good overlay is thin. The pattern in Syntropic137's `.claude/skills/devops` is representative: a short `SKILL.md` that names the branch model, points at the canonical release doc instead of copying it, states the repo's hard rules (merge style, no force-push, who approves deploy gates), and routes to small per-task agent files (PR flow, release, CI triage, hotfix, review pass). If a repo has no overlay and you find yourself rediscovering the same repo facts each session, propose one in that shape rather than growing this generic skill.

## Operating procedures

These are the maintainer's recurring jobs. Each is summarized here; the reference file holds commands, tables and edge cases. The authority rule applies to all of them: read, triage, fix branches you own, and report; do not merge, approve reviews, approve deployment gates, or push to protected branches unless the repo-local overlay or the user grants it in so many words.

### Procedure 1: measure

1. Run `scripts/dora-signals.sh --repo OWNER/NAME --base <trunk>` (28-day window by default; `--days`, `--hotfix-hours`, `--json` adjust it). It is read-only: one GraphQL search and one `gh release list`.
2. Compare against the previous run, not against an industry table. Direction over four weeks is the signal; one window is noise.
3. Pick the worst-moving key and run the matching procedure below. Lead time points at Procedure 2 or 3; deployment frequency and time to restore point at Procedure 4; change failure rate points at Procedure 3 (test quality) and Procedure 4 (batch size).

Detail: `references/dora-signals.md`.

### Procedure 2: PR backlog hygiene

1. Inventory every open PR with age, draft state, mergeability, check rollup, and review decision (`gh pr list --json ...`).
2. Classify each: ready, needs-main-merged, CI-red-real, CI-red-flake, waiting-on-review, waiting-on-author, superseded.
3. For branches you are allowed to update, merge the trunk into the branch (not rebase, when others have pulled it) and push; let CI run.
4. Re-run a failed job once. If it fails again, or fails differently, it is not a flake: diagnose from the log.
5. Close or flag superseded and abandoned PRs with a comment explaining why.
6. Publish a ready/blocked table with a proposed merge order (smallest, least conflicting, most depended-on first), and hand it to whoever holds merge authority.

Detail: `references/pr-backlog-hygiene.md`.

### Procedure 3: CI pipeline optimization

1. Find the slowest jobs and the least reliable ones from recent runs (`gh run list` plus `gh run view --json jobs`); rank by wall-clock on the critical path, not total minutes.
2. Apply the cheapest fix first: concurrency with `cancel-in-progress` for PR refs, dependency and build caching, path filters behind an always-running aggregate required check, then job splitting or sharding.
3. Quarantine a confirmed flake with a linked issue and an owner; never delete the test silently.
4. Re-measure the same jobs over a comparable set of runs and report before and after.

Detail: `references/ci-pipeline-optimization.md`.

### Procedure 4: release cadence

1. Read the release history and the repo's release doc; establish the current cadence and batch size.
2. Propose the smallest cadence the pipeline can support (weekly, then per-merge) and the automation it needs.
3. Make release notes a PR-creation habit: PR titles and bodies written as user-facing change notes, so a release is a concatenation, not a reconstruction.
4. Rehearse risky releases (fresh install and upgrade from the last release) in a disposable environment before the real gate.
5. When a release fails, prefer a fast patch release over reverting the release itself, and record the pair so time to restore is measurable.

Detail: `references/release-cadence.md`.

## Recommended tools and practices (as of 2026-10-13)

### For: changes reach users often

- **Release on merge, or on a short fixed timer, via a release workflow** (for example release-please, semantic-release, changesets, or a tag-triggered GitHub Actions job). Ladders up by removing the human checklist that makes releases infrequent. Tradeoff: needs conventional PR titles or changeset files to generate notes.
- **GitHub environments with required reviewers for production.** Ladders up by keeping one fast, explicit human gate instead of a slow manual process. Tradeoff: the gate must be approved by someone other than the change's author.

### For: a change moves from commit to users quickly

- **`scripts/dora-signals.sh`** (this skill). Ladders up by making lead time visible every session at zero cost. Tradeoff: proxy only; GitHub search caps at 1000 merged PRs per query.
- **Concurrency groups keyed on `github.ref` with `cancel-in-progress: true` for pull requests.** Ladders up by freeing runners for the newest commit. Tradeoff: do not cancel on the trunk or release refs, where every run is a record.
- **Merge queue (GitHub merge queue) for busy trunks.** Ladders up by testing the merged result without forcing every author to re-merge `main` by hand. Tradeoff: adds a `merge_group` trigger to required workflows.
- **`gh pr list` / `gh pr view` JSON fields** (`mergeable`, `mergeStateStatus`, `statusCheckRollup`, `reviewDecision`) for backlog triage. Ladders up by turning the backlog into a table instead of a scroll.

### For: changes rarely need immediate intervention

- **An always-running aggregate required check** (one job that `needs:` the real jobs and fails unless each succeeded or was skipped by design). Ladders up by letting path filters cut CI time without leaving required checks stranded.
- **Flake quarantine with an issue per test**, using the test runner's native mechanism (pytest markers, Jest `test.skip` with an issue link, Go build tags, nextest retries with reporting). Ladders up by keeping red meaningful. Tradeoff: quarantine without an owner becomes deletion by neglect.
- **Dependency and secret scanning on every PR** (Dependabot or Renovate, GitHub secret scanning with push protection, a pinned OSV or language-native audit). Ladders up by catching supply-chain failures before release. Tradeoff: tune severity thresholds or the scan becomes ignored noise.
- **Actions pinned by commit SHA with a version comment.** Ladders up by making the pipeline itself immutable between reviewed changes.

### For: when a change fails, service is restored fast

- **Patch releases from the trunk, cut by the same automation as normal releases.** Ladders up by making the fix path the well-worn path. Tradeoff: needs the trunk to be releasable at all times, which is the trunk-based principle again.
- **Release rehearsal in a disposable environment** (fresh install plus upgrade from the previous release). Ladders up by finding the failure before users do, and by exercising the recovery path. Tradeoff: costs a CI or local run per release candidate.
- **Release notes written in the PR body at creation time.** Ladders up by making "what changed in the failed release" answerable in seconds.

## References

- `references/dora-signals.md`: each key's DORA definition, the GitHub proxy, the exact `gh` query, how to read the script's output, and where each proxy misleads. Read before reporting numbers.
- `references/pr-backlog-hygiene.md`: inventory commands, triage classes, the merge-main-in and rerun-once rules, and the ready/blocked table template.
- `references/ci-pipeline-optimization.md`: finding slow and flaky jobs with `gh run`, the fix ladder (concurrency, caching, path filters, splitting), and the flake quarantine protocol.
- `references/release-cadence.md`: cadence assessment, release-notes-at-PR-time, rehearsal, and fix-forward recovery.
- `references/sources.md`: Accelerate chapter mapping (verified against the book's Quick Reference) and DORA capability URLs for every principle.
- `scripts/dora-signals.sh`: read-only signal report; `scripts/test-dora-signals.sh` runs its offline tests against `scripts/testdata/`.

## Continual improvement

File drift, gaps, or proposed updates at https://github.com/AgentParadise/agentic-skills/issues
