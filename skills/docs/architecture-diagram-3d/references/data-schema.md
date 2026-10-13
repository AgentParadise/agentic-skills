# Data schema: the DIAGRAMS array

Read this while writing the data for a view. The engine in
`assets/template.html` renders every entry of `DIAGRAMS` with one generic
builder, so a view is data only, and this file is the contract that data
must meet. Field names are short on purpose: a view is a few hundred lines of
literal data and long keys make it unreadable.

## Units and axes

- Scene units are arbitrary. A typical block is 3 to 4 wide, 1 high, 2 deep;
  floors are 3 apart; a full view fits in about 26 by 20.
- `y` is up. `x` runs left to right as seen from the default camera. `z` runs
  toward the camera (positive) and away (negative).
- A block's `p` is its centre, so a 1-high block on a floor at `y: 3` sits at
  `y: 3.6`. The reference used floor plus 0.6 for 1-high blocks and plus 0.8
  for 1.6-high ones.

## A view

```js
{
  id: "vertical",          // URL hash and tab id; kebab-case, unique
  short: "Full vertical",  // tab text and the back button
  key: "01",               // small mono number on the tab and the readout
  title: "One note, from the corpus to a screen",   // readout heading
  intro: ["...", "..."],   // 1 to 3 paragraphs: what this view shows and the one property it proves
  read: ["...", "..."],    // 2 to 5 lines: how to read the colours and shapes IN THIS VIEW
  cam: { target: [0, 9, 0], dist: 36, theta: -0.62, phi: 1.12 },
  floors: [ { y: 0, label: "Source", k: "00" }, ... ],
  floorSize: [24, 8],      // [width (x), depth (z)] of every floor in this view
  walls: [ ... ],          // may be []
  columns: [ ... ],        // optional
  room: true,              // optional; swaps the grid for a room shell
  nodes: [ ... ],
  edges: [ ... ]
}
```

### `cam`

The reset camera. `target` is the orbit centre, `dist` the distance from it,
`theta` the yaw in radians (negative looks from the left), `phi` the pitch
from straight above (1.1 to 1.2 is a comfortable three-quarter view; 0.2 is
nearly top-down). The engine multiplies `dist` by 1.35 on narrow stages so a
phone sees the whole view.

Finding a good camera: set a guess, publish or open locally, orbit until it
reads well, then read the three numbers off by temporarily logging `view` in
the frame loop. Do not ship the log.

### `floors`

```js
{ y: 3, label: "Ingest (offline)", k: "01" }
```

One slab per layer. `k` is the small key printed before the label. Floors are
drawn at `floorSize` centred on the origin; nothing else about them is
configurable per floor, which keeps them uniform across views.

### `walls`

```js
{ p: [1.6, 11.6, 0], s: [0.06, 11.8, 7.6],
  label: "Authorization boundary: bytes only through the blob store",
  lp: [1.6, 17.9, 3.9] }
```

`p` centre, `s` size (make one dimension 0.06 so it is a pane), `label` the
dashed chip text, `lp` where the chip is anchored (usually the top front
corner of the pane).

### `columns`

```js
{ x: -8.4, st: "built", label: "create", h: 9.6, cells: [0.6, 3.2, 5.8, 8.4] }
```

A glass column at `x`, status-coloured. `h` defaults to 9.6; `cells` lists
the `y` of each small solid cell and defaults to one per floor. Omit a cell to
say the slice owns nothing on that floor. `label` is informational; put the
visible label on a node sitting on top of the column.

### `nodes`

```js
{ id: "log", label: "ESP event log", sub: "v0.18 · one stream per item",
  p: [-6, 6.8, 0], s: [5.4, 1.6, 3.2], st: "built",
  shape: "anchor" | "screen" | "card",      // optional; default is a box
  what: "One paragraph: what it is and what rule it enforces.",
  where: ["contexts/knowledge/infrastructure/esp_item_store.rs", "bead abc-123"],
  notes: ["Optional bullets: invariants, open questions, what it never does."] }
```

- `id` must be unique within the view; edges refer to it.
- `st` is one of `built`, `partial`, `planned`, `gap`. See
  `visual-grammar.md` for what each one promises.
- `where` holds repo-relative paths checked against the main branch, tracker
  ids, document paths, or an external system named plainly ("a separate
  repo"). Use the prefix constants at the top of the data block so a rename is
  one edit. A path with a parenthetical (`corpus_note.rs (content_provider)`)
  points at a symbol inside a file; the check only needs the file to exist.
- `shape: "anchor"` draws an octahedron and ignores `s`. `shape: "screen"`
  draws a textured panel using `s` (make `s[2]` thin, 0.08). `shape: "card"`
  draws a thin slab with no status strip.
- Neither `what` nor `notes` may contain private content. Describe the kind
  of thing stored, not an instance of it.

### `edges`

```js
{ a: "create", b: "log", k: "event", t: "② append Created", dash: false, bend: [0, 1.6, 0] }
```

- `a` and `b` are node ids. Direction is `a` to `b`; the pulses move that
  way.
- `k` is one of `event`, `content`, `read`, `derive` and picks the colour and
  the pulse shape.
- `t` is an optional midpoint label. Leave most edges unlabelled.
- `dash: true` for a reference or a planned path. Dashed edges carry one
  pulse instead of two.
- `bend` is added to the auto-lifted midpoint. The engine lifts every curve
  by min(2.4, 12% of its length) so edges arc over blocks; `bend` is the
  correction on top of that.

An edge whose `a` or `b` is not a node id in the same view is skipped with a
console warning. Check the console once per view.

## Colour and text tokens

The engine reads colours from CSS custom properties on `:root` (`--event`,
`--content`, `--read`, `--derive`, `--built`, `--partial`, `--planned`,
`--gap`). Rename a meaning by changing `EDGE_TEXT` and `STATUS_TEXT` near the
top of the script; the legend and the readout chips follow. Add a new edge
kind by adding a token, an `EDGE_TEXT` entry and a `COL` entry; the builder
needs no change.

## Sizing guidance from the reference

| View kind              | floors | floorSize | nodes | edges | cam.dist |
|------------------------|--------|-----------|-------|-------|----------|
| full vertical          | 7      | [24, 8]   | 22    | 22    | 36       |
| boundary               | 1      | [26, 16]  | 11    | 10    | 25       |
| projections            | 3      | [24, 12]  | 11    | 12    | 25       |
| slice anatomy          | 4      | [26, 9]   | 11    | 6     | 30       |
| landing room           | 1      | [14, 10]  | 7     | 6     | 19       |

Above about 25 nodes a view stops being readable from the reset camera.
Split it.
