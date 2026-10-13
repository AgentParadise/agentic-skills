# Build checklist: from a codebase to a published page

Walk this top to bottom when building a diagram. Each item is something that
went wrong, or nearly did, while building the reference implementation. The
order matters: the code is read before anything is drawn, and the page is
checked before it is published.

## 1. Ground it in the code

- [ ] Read the tree of the part being drawn (`git ls-files <dir>` or the
      module index), its module doc comments, and the types that cross
      boundaries. A diagram drawn from memory of the code invents blocks.
- [ ] Read the tracker for the same area: what is open, what is in progress,
      what is a known defect. These become `planned` and `gap` blocks.
- [ ] Decide the views. Start from the five-view set in `visual-grammar.md`
      and drop any view whose property the system does not have.
- [ ] For each block, write `where` first, then `what`. If no path or tracker
      id comes to hand, the block is a concept and gets cut or merged.
- [ ] Set `st` from evidence: on main is `built`; on main in part is
      `partial` with `what` saying which part; tracked and not started is
      `planned` with the tracker id in `where`; known wrong is `gap` with the
      tracker id.
- [ ] Check every path against the main branch, not the working tree:
      ```sh
      git fetch origin main
      for p in $(grep -o '"[A-Za-z0-9_./-]*\.\(rs\|ts\|py\|go\|yaml\|md\)' page.html | tr -d '"' | sort -u); do
        git cat-file -e "origin/main:$p" 2>/dev/null || echo "MISSING $p"
      done
      ```
      Paths built from prefix constants (`K + "slices/create/"`) need the
      prefix expanded; the quickest way is to log `DIAGRAMS.flatMap(d => d.nodes.flatMap(n => n.where))`
      in the browser console and feed that list to the loop. Directory paths
      (`.../slices/create/`) pass `cat-file -e` on the tree object.
- [ ] Nothing private in `what`, `sub`, `notes` or any label: no note text,
      no titles, no personal paths, no hostnames. Screens show placeholder
      bars. The engine's `screenTexture()` draws bars; do not replace it with
      a real capture.

## 2. Write the data

- [ ] Copy `assets/template.html` to the output path. Replace the
      `{{PLACEHOLDERS}}` in the title, eyebrow, heading and the status cards,
      or delete the cards section if nothing sourced belongs there.
- [ ] Replace the worked example in `DIAGRAMS` with the first view. Set the
      path prefix constants to the real directories.
- [ ] Lay out floors first, then the two or three widest blocks, then the
      rest. Keep left and right halves meaning the same thing on every floor.
- [ ] Add edges, labelling only crossings and ordered steps. Add `bend` where
      two edges overlap or an edge passes through a block.
- [ ] Add walls where a boundary exists, with the label naming the crossing.
- [ ] Write `intro` as the property the view proves, and `read` as the
      colours and shapes used in this view, in the reader's order of noticing.
- [ ] Repeat per view. Every view is one more array entry; if adding a view
      needs an engine change, the engine is missing a feature, so add it
      generically rather than special-casing one view.

## 3. Check the page

- [ ] Extract the inline script and syntax-check it. A missing comma in a
      600-line data literal is the most common failure and the page shows
      nothing but the fallback message:
      ```sh
      awk '/^<script>$/{f=1;next} /^<\/script>$/{f=0} f' page.html > /tmp/page-script.js
      node --check /tmp/page-script.js
      ```
      The template's script tags sit alone on their lines so this `awk`
      works; keep them that way. The three.js `<script src>` line is excluded
      because it is not `^<script>$`.
- [ ] Open the page (locally with the skeleton prepended, or as a draft
      artifact) and visit every tab. Check the browser console for the
      "edge references unknown node" warning.
- [ ] From each reset camera, read the labels. Overlapping labels mean two
      blocks are too close or the camera is too far; move the block or lower
      `cam.dist`.
- [ ] Click a block on each view and confirm the readout shows the chip,
      "What it is", "Where it lives" and the back button returns to the
      overview.
- [ ] Narrow the window below 980px: the readout stacks under the stage.
      Below 560px: sublines hide except on the selected block.
- [ ] Toggle auto-orbit off and on; drag; shift-drag; wheel; pinch on a
      touch device if one is at hand. Reset view returns to `cam`.
- [ ] Temporarily block the three.js URL (or rename it) and confirm the
      fallback message appears in the readout instead of a blank stage.
- [ ] `grep -cP '\x{2014}' page.html` is 0 if the house style forbids em
      dashes (the Perl escape keeps this file itself free of one).

## 4. Publish

- [ ] If the host has artifact rules (a CDN allowlist, a two-to-four-word
      `<title>`, theme tokens on `:root`, a size limit), follow them. The
      template already uses cdnjs for three.js, Google Fonts for type, a
      short title and tokens on `:root` with `color-scheme: dark`; it does not
      define a light theme, by design, and says so in the CSS comment.
- [ ] Publish with a one-sentence description that names the system and the
      number of views.
- [ ] Put the page's URL where the code lives: the PR, the handoff, the
      design doc. A diagram nobody can find from the code rots unnoticed.
- [ ] Note the date in the eyebrow. The page is a snapshot of main on that
      day, and `planned` blocks will be wrong within weeks.

## 5. Keep it true

- [ ] When a `planned` block ships, change `st` and move its tracker id from
      `where` into `notes` (or drop it) and add the code path. This is one
      line.
- [ ] Re-run the path check after any large refactor on main. A moved file
      silently turns a true diagram into a false one.
