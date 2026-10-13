# Sources

Where each claim in this skill comes from, so a reader can verify it. Consult before quoting a chapter, a threshold, or a metric definition to a human.

## Accelerate

Nicole Forsgren, Jez Humble and Gene Kim. *Accelerate: The Science of Lean Software and DevOps: Building and Scaling High Performing Technology Organizations.* IT Revolution, 2018. ISBN 978-1942788331.

Chapter titles (Part I, "What We Found"): 1 Accelerate; 2 Measuring Performance; 3 Measuring and Changing Culture; 4 Technical Practices; 5 Architecture; 6 Integrating Infosec into the Delivery Lifecycle; 7 Management Practices for Software; 8 Product Development; 9 Making Work Sustainable; 10 Employee Satisfaction, Identity, and Engagement; 11 Leaders and Managers. Appendix A is "Capabilities to Drive Improvement".

The chapter for each capability below is taken from the book's own "Quick Reference: Capabilities to Drive Improvement" (front matter), as reproduced in the publisher's excerpt at https://itrevolution.com/wp-content/uploads/2022/06/ACC_excerpt.pdf. Page numbers are deliberately not cited: they differ between print, ebook and excerpt editions.

| Capability used in this skill | Accelerate chapter | Current DORA page |
| --- | --- | --- |
| The four key measures | Ch. 2 Measuring Performance | https://dora.dev/guides/dora-metrics/ |
| Version control | Ch. 4 | https://dora.dev/capabilities/version-control/ |
| Deployment automation | Ch. 4 | https://dora.dev/capabilities/deployment-automation/ |
| Continuous integration | Ch. 4 | https://dora.dev/capabilities/continuous-integration/ |
| Trunk-based development | Ch. 4 | https://dora.dev/capabilities/trunk-based-development/ |
| Test automation | Ch. 4 | https://dora.dev/capabilities/test-automation/ |
| Continuous delivery | Ch. 4 | https://dora.dev/capabilities/continuous-delivery/ |
| Shift left on security | Ch. 6 | https://dora.dev/capabilities/pervasive-security/ |
| Loosely coupled architecture | Ch. 5 | https://dora.dev/capabilities/loosely-coupled-teams/ |
| Working in small batches | Ch. 8 | https://dora.dev/capabilities/working-in-small-batches/ |
| Change approval processes | Ch. 7 | https://dora.dev/capabilities/streamlining-change-approval/ |
| Monitoring | Ch. 7 | https://dora.dev/capabilities/monitoring-and-observability/ |
| WIP limits | Ch. 7 | https://dora.dev/capabilities/wip-limits/ |
| Visualizing work | Ch. 7 | https://dora.dev/capabilities/visual-management/ |

## DORA statements quoted or paraphrased in this skill

Checked against dora.dev on 2026-10-13.

- Trunk-based development: "Have three or fewer active branches in the application's code repository"; "Merge branches to trunk at least once a day"; "Don't have code freezes and don't have integration phases." (trunk-based-development page)
- Continuous integration: tests should give feedback in a few minutes, "with an upper limit of about 10 minutes"; if the build cannot be fixed in a few minutes, identify and revert the change that broke it. (continuous-integration page)
- Test automation: "don't tolerate flaky tests." (test-automation page)
- Small batches: "Any batch of code that takes longer than a week to complete and check is too big." (working-in-small-batches page)
- WIP limits help "particularly when they are combined with" visual displays and monitoring feedback; set limits by team capacity. (wip-limits page)
- Change approval: from the 2019 State of DevOps research, heavyweight external approval has "a negative impact on software delivery performance", with "no evidence" it lowers change fail rates; approvals are best done "through peer review during the development process". (streamlining-change-approval page)
- Metric history: four keys from the 2015 research; availability in 2018, broadened to reliability in 2021; MTTR renamed and redefined as failed deployment recovery time in 2023; deployment rework rate added in 2024. (https://dora.dev/insights/dora-metrics-history/)

## When a source changes

DORA revises its capability pages and metric definitions most years. If a quoted line above no longer appears on the linked page, update this file and the `Recommended tools and practices` date in `SKILL.md` together, and keep the Accelerate chapter references unchanged (the book is fixed).
