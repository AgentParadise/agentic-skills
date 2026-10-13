# Visual grammar: what every shape, colour and motion means

Read this before deciding how a system becomes views, and again while filling
in the data. It defines the fixed vocabulary of the diagram so a reader can
decode any view without re-learning it, and so an author does not spend a
colour or a shape on decoration. The engine in `assets/template.html`
implements exactly this grammar.

## The one rule

Every visual property carries one meaning, and the same meaning in every view.
A reader who learns that amber means bytes on view 01 must be able to trust it
on view 05. When the system you are drawing needs a meaning the grammar does
not have, extend the grammar (and the legend) rather than borrowing a colour.

## Space: floors are layers

- A floor is a translucent slab with a grid and an uppercase label at its front
  left corner, keyed `00`, `01`, ... or `L1`, `L2`, ...
- Floors read bottom to top. The bottom floor is the source or the outside
  (a corpus, a client, raw files); the top floor is where the result lands
  (pixels, a screen, a response). Height is the direction of the data.
- Spacing of about 3 scene units between floors leaves room for a 1-unit-high
  block and a lifted edge. Compress to 2.6 when there are four or more floors.
- In a layered-architecture view (domain, ports, application, infrastructure)
  put the innermost layer on top and adapters on the bottom, so "dependencies
  point inward" reads as "arrows point up".
- Left and right halves of a floor can carry a second axis. The reference
  implementation used left for the log side and right for the content side,
  consistently across floors, so a column of blocks reads as one concern.

## Blocks are code

- A block is a box with an emissive tint, a hairline outline and a label
  above it. The label has a name and a mono subline (a type name, a feature
  flag, a tracker id).
- Every block names at least one code path, tracker id, document or external
  system in `where`. A block with nothing to point at is a concept, not a
  component, and does not belong in this kind of diagram.
- Block width should roughly follow importance, not line count. The event
  log and the blob store in the reference were the two widest blocks on their
  floor because everything else depends on them.
- A thin wide block along the back of a floor (for example a process manager
  that runs all of that floor's steps) says "this orchestrates these".

## Status is a strip and a surface

| Status    | Face                         | Outline | Meaning |
|-----------|------------------------------|---------|---------|
| `built`   | solid, teal strip            | solid   | on the main branch today |
| `partial` | solid, amber strip           | solid   | some of it is on main; `what` says which part |
| `planned` | translucent, violet strip    | dashed  | tracked and not started; `where` names the tracker id |
| `gap`     | solid, red strip             | solid   | known wrong or missing, with a tracker id |

Status comes from the tracker or from the code, never from a guess. The
strip runs along the bottom of the front face; the readout chip repeats it in
words. Planned blocks are see-through because they do not exist yet, and a
reader should be able to look through them to what does.

## Walls are boundaries

- A wall is a tall, nearly transparent pane with a dashed label. Its tone
  says what kind of boundary it is.
- The default tone is amber (the content token): a security, authorization
  or trust boundary, what one side can see that the other cannot. The wall
  label says where the one legitimate crossing is ("bytes only through the
  blob store"), and the edge that crosses it is labelled too. The boundary is
  the thing readers most misunderstand, so it earns both.
- A wall that nothing crosses is suspicious: either the crossing is missing
  from the diagram, or the boundary is not real.
- Other tones mark other boundaries. A wall takes `tone` (any status or flow
  token), `op` (opacity) and `dash` (dashed outline), and its label takes the
  tone colour. Use a full box, not a pane, to frame a region:
  - teal (`built`), solid outline, low opacity: a **package boundary** that
    a gate checks, drawn around the floor the package owns;
  - cyan (`event`), dashed, very low opacity: an **isolation unit** (a
    tenant, a compartment, a blast radius), drawn around everything it
    contains;
  - violet (`planned`), dashed, faint: a **later** isolation unit or
    package, placed behind the current one to say the architecture leaves
    room for it.
  The reference's Target view used all three at once: a teal frame around
  the standalone package, a cyan frame around the whole first compartment,
  and a faint violet frame behind it for the next compartment, with the
  amber bytes wall still inside.
- Keep framing walls faint (`op` 0.02 to 0.04). They are context, and a
  reader should see the blocks through them. The amber bytes wall stays at
  the default 0.07 because it is the point of its view.

## Edges are kinds of flow

| Kind      | Colour | Pulse   | Meaning |
|-----------|--------|---------|---------|
| `event`   | cyan   | sphere  | a fact, event or command on the log |
| `content` | amber  | cube    | bytes: payloads, note bodies, textures |
| `read`    | green  | sphere  | a read path; nothing is written |
| `derive`  | grey   | sphere  | a fold, projection or plain call |

- Solid is live data moving. Dashed is a reference (a pointer, not a copy) or
  a planned path.
- Pulses move from `a` to `b`, so direction is visible without arrowheads,
  which do not read well on a curve in 3D. Cubes for bytes and spheres for
  facts let a reader tell payload from metadata at a glance even when the
  colour is washed out by distance.
- Edge labels are short mono chips at the midpoint. Use them for the
  crossings and the ordered steps ("① PUT bytes", "② append fact"), and
  leave plain calls unlabelled. They fade out when the camera is far, so
  they never clutter the overview.
- `bend` lifts or shifts the midpoint. Use it to separate two edges between
  the same pair, to route around a block, or to pull a return loop (drop and
  replay) out from the forward path.

## Columns are vertical slices

- A column is a tall glass box the height of the whole stack, with one small
  solid cell on each floor the slice owns code in. Its status colours it like
  a block; a planned column is dashed and dimmer.
- The block sitting on top of a column is the slice's trigger (its command,
  its view, its automation). Columns say "this piece of work cuts through
  every layer"; the cells say which layers it actually touches.
- A missing cell on one floor is information: the reference omitted the
  ports cell on planned slices because no port had been declared yet.

## Rooms are where it lands

- A `room: true` view replaces the grid with an opaque floor, a back wall and
  two side walls, plus a desk for scale. It is the only view that shows the
  user's space instead of the code's.
- Anchor points are small octahedra on the walls. A screen is a flat panel
  with a placeholder texture: a title bar and text bars, never real content.
  A card is a thin slab floating in the room for the record as the system
  sees it (an id and references, no text).
- The room view earns its place by showing the final hop: the one edge that
  carries bytes into the user's view, and the one fact that says where.

## Controls

The stage is driven by hand-written orbit code, not a library control, so
the behaviour is part of the grammar and the hint line must match it:

- Left-drag orbits. Right-drag, middle-drag or shift-drag translates in
  screen space: the target moves along the camera's right and up vectors,
  scaled so the point under the cursor stays under the cursor.
- Wheel zooms. Two-finger drag translates and pinch zooms.
- Keyboard, once the canvas has focus (click it or tab to it; it shows a
  focus ring): arrows or WASD pan, Q/E orbit, R/F or PageUp/PageDown move up
  and down, + and - zoom, 0 or Home resets the view. Block labels are
  focusable buttons: Tab to one and press Enter or Space to open its readout.
- Only a left click picks a block. Middle-click autoscroll and the context
  menu are suppressed on the canvas.
- Any manual move switches auto-orbit off; the button switches it back on.
  Reduced motion starts with it off and slows the pulses.

## The readout panel

- Overview (no selection): the view's number and title, two or three intro
  paragraphs, a "how to read it" list that names the colours in this view,
  and the legend.
- Selection: a back button, the status chip, the block's name and subline,
  "What it is", "Where it lives" as one mono chip per path, and optional
  "Notes" for the rules the block enforces or the open questions on it.
- The panel is the text half of the diagram. The scene says what is
  connected to what; the panel says why, and where to go read it.

## The set of views that covers a vertical

Six views covered a full vertical and its target in the reference. Reuse the
set when the system has the same shape:

1. **The full vertical.** Every floor, both halves, the long edges. The
   establishing shot.
2. **The boundary.** One record's facts along the front, the bytes they point
   at behind the wall, and two observers (log-only, log plus store) showing
   what each can read.
3. **Projections and rebuild.** The log, one pure fold, the read models, and
   the dashed loop that says drop and replay gives the same state.
4. **Slice anatomy.** Layer slabs with glass columns, one per slice, and the
   gate that checks the boundaries.
5. **The landing scene.** The room, its anchors, the screen, and the final
   hop.
6. **The target.** Where the architecture is headed: the same floors
   regrouped as packages and isolation units with toned framing walls, and
   planned blocks for the room the design must leave. Add this view when a
   design decision has been ruled and the code has not caught up; it is the
   one view where most blocks are `planned`.

Not every system has all six. A system with no trust boundary has no wall
and no boundary view; drawing one anyway invents a property the code does not
have.

## Theme

One deliberate dark console theme, not a light and dark pair. The scene is
lit for a dark ground: the hemisphere light, the cyan rim light and the
emissive tints all assume it. The page still declares `color-scheme: dark`
and tokens on `:root` so the host's theme rules are satisfied; it simply does
not redefine them for light.
