# Release cadence

How to assess a repo's release rhythm, move it toward small frequent releases, and keep recovery fast. Read when deployment frequency is low, when first-commit-to-release lead time is much longer than first-commit-to-merge, or when a release failed.

The research basis: Accelerate Ch. 4 (deployment automation, continuous delivery) and Ch. 8 (working in small batches). DORA's small-batches page puts the upper bound plainly: a batch that takes longer than a week to complete and check is too big.

## 1. Read the current rhythm

```bash
gh release list --repo OWNER/NAME --limit 50 --json tagName,publishedAt,isPrerelease \
  --jq '.[] | [.publishedAt[:10], .tagName, (if .isPrerelease then "pre" else "" end)] | @tsv'

# How many merged PRs went into the latest release (for a repo releasing from main):
prev=$(gh release list --repo OWNER/NAME --limit 2 --json tagName --jq '.[1].tagName')
last=$(gh release list --repo OWNER/NAME --limit 1 --json tagName --jq '.[0].tagName')
gh api "repos/OWNER/NAME/compare/$prev...$last" --jq '[.commits[] | select(.parents | length > 1)] | length'
```

Record: releases per week, typical PRs per release, and the longest gap. Then read the repo's release doc or overlay for how a release is cut, who approves, and what is published. The merge-commit count assumes merge commits; for squash-merge repos count commits instead.

## 2. Propose the next smaller step

Move one step at a time, each one only when the pipeline can carry it:

| From | To | Needs |
| --- | --- | --- |
| Ad hoc, multi-week | Fixed weekly | A written, scripted release procedure; release notes from PRs |
| Weekly | Several per week | Release cut by automation (tag or release PR); fast rehearsal |
| Several per week | Per merge (continuous delivery) | Trunk always releasable; automated deploy with a health check and a cheap rollback or fix-forward path |

State the expected effect on the four keys when proposing a change, and re-measure after a few cycles with `scripts/dora-signals.sh`.

## 3. Write release notes at PR creation

Release notes reconstructed at release time are slow and thin. Make each PR carry its own note:

- PR title in a convention the release tooling reads (Conventional Commits for release-please or semantic-release, or a changeset file for changesets).
- PR body opens with a user-facing sentence: what changed for whoever consumes the release, and any upgrade action.
- When a release is cut from a PR (a release PR or a `main` to `release` PR), write its body as the release notes when the PR is opened. Some pipelines copy the body into the GitHub Release, and some gates validate the body from the event payload, so editing it later may not re-run the check.

## 4. Rehearse risky releases

Before the real gate, run the release candidate in a disposable environment two ways:

- **Fresh install**: the documented install path from nothing.
- **Upgrade**: install the previous release, load representative data, then upgrade to the candidate.

Most release-breaking defects (migrations, config defaults, changed artifact names, image architectures) show up only in the upgrade path. Rehearsal also exercises the recovery path you will need if the real release fails. Codify the rehearsal as a repo target so it runs the same way each time.

## 5. When a release fails

1. Confirm the failure is caused by the release (otherwise it is not a change failure; DORA's failed deployment recovery time excludes external outages).
2. Prefer fix-forward with a patch release from the trunk, cut by the normal automation. A release that has been published is generally immutable (tags, package registries, signed images); re-running the release job for the same version is often a silent no-op.
3. If the fix will take longer than the repo's tolerance, roll back the deployment (not the history) to the previous release.
4. Record the failed release and the fixing release in the patch release notes ("fixes a regression in vX.Y.Z"). That pairing is what makes time to restore measurable later.
5. Add the escaped defect to the rehearsal or test suite so the same class cannot escape twice.

## Gates and authority

Release gates (protected environments, required reviewers, release-branch protection) exist so a second party approves what ships. An agent maintainer prepares the release, writes the notes, runs the rehearsal, and reports readiness; it does not approve its own release gate or bump and cut a release unless the repo-local overlay grants that. Stopping at "releasable, here is the evidence" is the job done.
