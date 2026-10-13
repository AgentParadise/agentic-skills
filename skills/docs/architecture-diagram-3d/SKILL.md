---
name: architecture-diagram-3d
description: Build an interactive, orbitable 3D diagram of a codebase's architecture as one HTML page, where floors are layers, blocks name real code paths, translucent walls mark security boundaries, and moving pulses show the direction of each kind of flow. Trigger phrases include "3D architecture diagram", "interactive architecture diagram", "explorable diagram of the code", "show the vertical in 3D", "orbit the architecture", "3D map of the codebase", "walk me through the stack visually", "click a block to see where it lives", "layer diagram I can rotate", "three.js diagram of the system", "diagram the data path with the trust boundary", "make the architecture page like the knowledge vertical one". Produces a single .html page with several views, a readout panel per block, and a status strip (built, partial, planned, gap) sourced from the code and the tracker. Do NOT use for a static one-scroll poster or how-it-works graphic (use the docs `system-infographic` skill), for a long-form prose explainer (use the docs `html-guide` skill), for a data chart, for a 2D flowchart or sequence diagram, or for a 3D scene that is not a diagram of code (that is a rendering task, not this skill).
---

# Architecture diagram, 3D

## When to Use (and When NOT to Use)

Use when:
- A reader needs to understand how a vertical, a data path or a bounded context hangs together across layers, and a flat diagram would hide the layering or the boundary.
- The diagram must be trustworthy: every block points at code on the main branch, and status (built, partial, planned, gap) comes from the tracker or the code.
- Several views of the same system are wanted (the full vertical, the trust boundary, projections, slice anatomy, where it lands), switchable on one page.
- The output is a page people will orbit, click and share, not a picture.

Do NOT use when:
- The deliverable is a static one-scroll poster or how-it-works graphic: use the docs `system-infographic` skill.
- The deliverable is a prose explainer for a decision: use the docs `html-guide` skill.
- The content is a dataset (a chart), a sequence diagram, or a flowchart with no layering; 3D adds nothing there.
- The 3D scene is the product itself (a game level, a product shot). That is rendering, not a diagram of code.

## Input

- The code being drawn: a repo on disk with `origin/main` fetchable. Required, because every block's `where` is checked against main before publishing.
- The tracker for that code (issues, beads, a board) or the operator's word on what is planned and what is a known gap. Required for status; without it every block is a guess.
- The set of views wanted. Optional; default is the five-view set in `references/visual-grammar.md`, minus any view whose property the system lacks.
- Output path for the `.html` page, or the intent to publish it as a host artifact. Optional; default `docs/<topic>-3d.html` in the relevant repo.
- Node on the machine for the syntax check. Required for the `node --check` step.

## Workflow

1. **Read the code on main before drawing anything.** `git fetch origin main` and read the code at that commit (a detached worktree, or `git show origin/main:<path>`), not the working checkout, so unmerged work is never drawn as built; record the SHA in the eyebrow. List the tree of the area, read module doc comments and the types that cross boundaries, and read the tracker for the same area. Write each block's `where` (code paths, tracker ids) before its `what`. A block with nothing to point at is a concept, not a component, so it gets cut or merged. See `references/build-checklist.md` section 1.
2. **Decide the views.** Start from the five-view set (full vertical, boundary, projections and rebuild, slice anatomy, landing scene) and drop any view whose property the system does not have. A wall that nothing crosses, or a projections view for a system with no log, invents a property the code lacks. See `references/visual-grammar.md`.
3. **Copy `assets/template.html` and fill the data.** Each view is one entry in the `DIAGRAMS` array: floors, walls, nodes, edges, camera, intro and read-tips. One generic builder renders every entry, so adding a view is data only; if a view seems to need an engine change, add the feature generically. The field contract is `references/data-schema.md`.
4. **Apply the grammar strictly.** Floors are layers read bottom to top. Edge colour is the kind of flow (fact, bytes, read, derive); dashed is a reference or a planned path; pulses show direction (cubes for bytes, spheres for facts). Status is a strip on the block's face, and planned blocks are translucent with dashed outlines. One meaning per colour, the same meaning on every view, so a reader decodes view 05 with what they learned on 01.
5. **Write the readout text.** Per view: an intro stating the property the view proves, "how to read it" naming the colours used in this view, and the legend. Per block: what it is, where it lives, and notes for the invariants it enforces or the questions open on it. The scene shows what connects to what; the panel says why and where to read it.
6. **Keep private content out.** Labels and notes describe the kind of thing stored, never an instance of it. Screens draw placeholder bars from `screenTexture()`; never swap in a real capture. No personal paths or hostnames in `where`.
7. **Check every path against main.** `git cat-file -e <sha>:<path>` for each `where` entry that is a path, at the SHA from step 1. A moved file silently turns a true diagram into a false one, and readers trust a diagram more than prose.
8. **Syntax-check the script and walk every view.** Extract the inline script and run `node --check`; a missing comma in the data literal stops the whole script, leaving an empty stage and readout (the fallback message covers only a failed three.js load). Then open the page, visit every tab, click a block on each, check the console for unknown-node warnings, and narrow the window to see the readout stack. See `references/build-checklist.md` section 3.
9. **Publish under the host's artifact rules.** The template already loads three.js r128 from cdnjs and fonts from Google Fonts, uses a short `<title>`, and declares tokens on `:root` with one deliberate dark theme. If the host has an artifact-design skill or page contract (CDN allowlist, title length, theme tokens, size limit), follow it rather than this skill's summary of it. Put the published URL where the code lives: the PR, the handoff, the design doc.

## Output

- One `.html` page: a header with a view switcher, a 3D stage on the left, a readout panel on the right (stacked on phones), optional status cards below, and a footer stating that positions are schematic and paths are relative to main.
- Inside it, a `DIAGRAMS` array with one entry per view, and the generic engine unchanged from the template apart from added features.
- Every `where` path verified against `origin/main` on the date in the eyebrow.
- A `node --check` pass on the extracted script, and a walk through every view in a browser.
- If published as an artifact: the URL, recorded next to the code it draws.

## Outcomes we are looking for

### The diagram is true to the main branch
Signals: every path in every `where` resolves with `git cat-file -e origin/main:<path>`; a maintainer reading it finds no invented block and no status they would dispute.

### A reader decodes any view with one legend
Signals: each colour, dash, pulse shape and surface carries one meaning across all views; the "how to read it" list for view 05 introduces no symbol that view 01 did not.

### Adding a view is data only
Signals: a new view is one more `DIAGRAMS` entry and no engine edit; the engine diff between two diagrams built from the template is empty or a generic feature.

### Nothing private leaves with the page
Signals: screens show placeholder bars; no label, note or path contains note text, titles, home paths or hostnames; the page can be shared outside the team as-is.

### The page works where it is opened
Signals: it orbits, translates and zooms with mouse, trackpad, touch and keyboard; the readout stacks on a phone; reduced motion slows the pulses and stops the auto-orbit; a failed three.js load shows a message, not a blank stage.

## Recommended tools and practices (as of 2026-10-12)

### For: true to the main branch
- Read the tree and the doc comments first, then the tracker, then draw. The reference implementation drew a knowledge vertical this way: 22 blocks on the full view, every one with a path or tracker id, and the operator asked for the method to be repeatable.
- `git cat-file -e origin/main:<path>` per path, on a fresh fetch, not `test -f` on the working tree. The working tree has branches and uncommitted moves; readers will look at main.
- Status values are exactly `built`, `partial`, `planned`, `gap`. A fifth status is usually a sign that `what` should say more, not that the vocabulary is short.

### For: one legend across views
- The grammar in `references/visual-grammar.md`, applied unchanged: cyan facts, amber bytes, green reads, grey derives; dashed references; cubes for bytes and spheres for facts. Extending it means a new token, a legend entry and a `COL` entry, not a borrowed colour.
- Translucent amber walls for every security or authorization boundary, labelled with where the one crossing is, and the crossing edge labelled too. Readers misunderstand the boundary more than anything else on the page. Toned, faint, dashed frames (`tone`, `op`, `dash`) for package and isolation boundaries, so a reader can tell "may not see" from "may not depend on" from "blast radius".

### For: data only
- The `DIAGRAMS` array and the generic `buildScene` from `assets/template.html`. The reference's five views share one builder; `columns` and `room` were added generically when the slice and landing views needed them.
- Path prefix constants at the top of the data (`const K = "contexts/knowledge/"`) so a directory rename is one edit.

### For: nothing private
- The engine's `screenTexture()` for every screen: a title bar and bars of text. The reference published a page about a personal knowledge base and shipped no text from it.
- Describe the kind of record in `what`, never an instance. "The note's bytes, addressed by hash", not the note.

### For: works where opened
- three.js r128 UMD from cdnjs, the hand-written controls in the template (left-drag orbits; right-, middle- or shift-drag translates in screen space; wheel and pinch zoom; two-finger drag translates; arrows or WASD, Q/E, R/F, +/- and 0 on a focusable canvas; block labels are focusable buttons; only a left click picks), `ResizeObserver` for the stage, `prefers-reduced-motion` honoured, and HTML labels projected per frame and scaled by distance with edge labels fading when far. These are all in the template; keep them when editing the engine.
- `node --check` on the extracted script before every publish. One missing comma is the most common way this page ships broken.
- The host's own artifact page contract for publishing (CDN allowlist, title, theme tokens, size). This skill does not duplicate those rules because they change with the host.

## References

- `assets/template.html`: the engine plus one worked example view. Copy it and replace the `DIAGRAMS` data; keep the engine.
- `references/visual-grammar.md`: what every shape, colour, dash, pulse and surface means, and the five-view set. Read during steps 2, 4 and 5.
- `references/data-schema.md`: every field of a `DIAGRAMS` entry, units, camera, and sizing guidance from the reference. Read during step 3.
- `references/build-checklist.md`: the step-by-step checklist from reading the code to keeping the page true after publishing, with the path-check and `node --check` snippets. Read during steps 1, 7, 8 and 9.
- Live example: https://claude.ai/artifact/HnENkkWr7qKV23mYB3tnVU (six views of a knowledge vertical, the page this skill was distilled from).

## Continual improvement

File drift, gaps, or proposed updates at https://github.com/AgentParadise/agentic-skills/issues
