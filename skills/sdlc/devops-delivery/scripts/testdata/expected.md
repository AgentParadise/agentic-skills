## DORA proxy signals: fixtures

Window: 2026-09-15T00:00:00Z to 2026-10-13T00:00:00Z (28 days). 5 merged PRs, 3 releases.

| Key | Signal | Value |
| --- | --- | --- |
| Deployment frequency | releases per week | 0.8 |
| Lead time | first commit to merge | median 3h, p90 6h (n=5) |
| Lead time | PR open to merge | median 2h, p90 4h (n=5) |
| Lead time | first commit to release | median 16h, p90 48h (n=4); merged PRs not yet released: 1 |
| Change fail rate | revert or hotfix PRs / merged PRs | 40% (2) |
| Change fail rate | fix PRs / merged PRs | 20% (1) |
| Change fail rate | releases followed by a quick patch release | 33.3% (1) |
| Time to restore | failed release to patch release | median 36h, p90 36h (n=1) |

All values are proxies from GitHub metadata. Read references/dora-signals.md before acting on them.
