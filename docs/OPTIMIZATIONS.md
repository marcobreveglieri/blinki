# Blinki — Optimization Opportunities

This document collects the results of a code review focused on performance and
code quality. No code changes are included here; each item points to the
relevant source location and sketches a possible fix. Items are grouped by
expected impact.

Context: Blinki renders at ~20 fps through `TTuiApp.Run`, which every tick
clears the canvas, renders the whole widget tree, and flushes a diff of the
double buffer to the terminal. Most of the findings below concern that loop.

## High priority — the render hot path

### 1. The render loop never consults the existing dirty-tracking

The widget layer implements full dirty propagation: `TTuiWidget.FDirty`, the
`Invalidate` method that propagates to the parent and short-circuits when
already dirty (`Source/Blinki.Core.Widget.pas:415`), and the public `Dirty`
property. Animated widgets correctly call `Invalidate` from their `DoTick`.
However, nothing in the render path reads that state:

- `TTuiApp.RenderFrame` (`Source/Blinki.Core.App.pas:534`) unconditionally
  performs `FCanvas.Clear` → `FRoot.Render` (full tree) → `FCanvas.Flush`
  on every tick, even when nothing changed.
- `TTuiWidget.Render` (`Source/Blinki.Core.Widget.pas:364`) clears `FDirty`
  but clean subtrees are never culled.
- Because every `Clear` sets the canvas dirty flag
  (`Source/Blinki.Core.Canvas.pas:282`), `Flush` always proceeds to
  `BuildFlushSequence`, which scans the entire W×H buffer every frame
  (`Source/Blinki.Core.Canvas.pas:390`) even for a fully static screen.

**Suggested fix:** in `Run`/`RenderFrame`, skip the whole
`Clear + Render + Flush` sequence when `FRoot.Dirty` is false, no modal
overlay is dirty, and no resize occurred. A static UI goes from ~20 full-tree
renders plus full-buffer diffs per second to essentially zero. This is the
single biggest win and makes several items below moot for static frames.

### 2. Diff loop: redundant bounds checks and record copies per cell

`TTuiFrameBuffer.GetCell`/`SetCell` call `RaiseIfOutOfBounds` on every access
(`Source/Blinki.Core.Render.pas:192`). The flush diff loop
(`Source/Blinki.Core.Canvas.pas:393`) reads both buffers through the checked
property getter:

```pascal
var LCell := FBack[LX, LY];          // bounds check + full record copy
if LCell = FFront[LX, LY] then       // second bounds check + record copy
```

This runs W×H times per frame with loop bounds that already guarantee
validity. **Suggested fix:** add a fast unchecked internal accessor (or
compare by flat index on `FCells`, as `CopyFrom` already does). The same
checked indexer is also used in the inner loops of `FillRect`, `DimRect`,
and `DrawBox`.

### 3. A large `TStringBuilder` is allocated on every flush

`BuildFlushSequence` (`Source/Blinki.Core.Canvas.pas:383`) creates a
`TStringBuilder` sized `Width * Height * 8` on every call and frees it right
after. **Suggested fix:** keep it as a reusable field on the canvas and reset
it between frames, avoiding a large per-frame heap allocation.

### 4. `TTuiTable.ComputeWidths` rescans all rows every frame

`ComputeWidths` (`Source/Blinki.Widgets.Table.pas:411`) is called from
`DoRender` on every frame. For any auto-width column it scans **every row**,
computing `TTuiAnsi.VisibleLength` of every cell, and `VisibleLength` itself
walks each string character by character (`Source/Blinki.Core.Ansi.pas:505`).
That is O(rows × columns × cell length) per frame, independent of the
viewport and repeated even when the data is unchanged. **Suggested fix:**
cache the computed widths and recompute only when rows, columns, size, or
theme change. This is the biggest per-widget hot spot in data-heavy demos
(Dashboard, SysMonitor).

## Medium priority

### 5. ANSI generation allocates many transient strings per changed cell

Each changed cell in the diff loop calls `TTuiAnsi.CursorTo`
(`Source/Blinki.Core.Ansi.pas:404`) and `ApplyStyleDelta` (`:387`), which
build intermediate strings via `IntToStr` and concatenation —
`SetForeground`/`SetBackground` (`:322`) use up to three `IntToStr` calls
plus several concatenations for an RGB colour. A full-screen RGB repaint
produces thousands of short-lived string allocations per frame.
**Suggested fix:** append integers directly into the shared `TStringBuilder`
(small int→ASCII helper) instead of building intermediate strings, and/or
cache common sequences.

### 6. `WriteAt` recomputes the clip rect for every character

`WriteAt` (`Source/Blinki.Core.Canvas.pas:291`) calls `WriteCell` per
character, and `WriteCell` consults `ActiveClipRect` (clip stack access) on
every call. `FillRect`/`DimRect` compute their clamped rect once;
**suggested fix:** cache the active clip once at the top of `WriteAt` and
test inline. Text is written cell-by-cell across the whole UI every frame,
so this is real per-character overhead.

### 7. O(n²) string concatenation in `DrawBox`

The top border is built with `LTopLine := LTopLine + LChars.Horizontal`
inside `for`/`while` loops (`Source/Blinki.Core.Canvas.pas:343` and `:353`).
**Suggested fix:** `StringOfChar` (or a string builder).

### 8. `TTuiFrameBuffer.Clear` assigns cell by cell

`Clear` (`Source/Blinki.Core.Render.pas:177`) assigns each of the W×H cells
in a loop every frame. **Suggested fix:** keep a pre-built blank row and
`Move` it per row (or fill by doubling). Combined with item 1, most `Clear`
calls disappear entirely for static frames.

### 9. Per-frame layout allocations

`TTuiStackPanel.DoRender` allocates the constraints array on every render
(`Source/Blinki.Layout.Stack.pas:122`), and the solver allocates the sizes
array (`Source/Blinki.Layout.Solver.pas:80`) — for every stack, every frame,
even though layout only changes on resize or constraint change. With the
dirty-skip from item 1 these vanish for static frames; otherwise consider
caching results keyed on the rect size and child constraints.

### 10. FX and animated widgets

- `TTuiGradient.DrawGradient` calls `LerpColor` per character, and
  `LerpColor` (`Source/Blinki.FX.Gradient.pas:82`) re-validates
  `Kind = ckRGB` (with `raise`) on every character even though
  `DrawGradient` already validated the endpoints up front. Hoist an
  unchecked lerp for the loop.
- `TTuiMatrixRain.DoRender` (`Source/Blinki.Widgets.MatrixRain.pas:174`)
  computes a float lerp plus a colour record per trail cell across the full
  screen every frame. The trail gradient depends only on the position within
  the trail: precompute a small colour lookup table per trail length.
- `TTuiWaveAnimation` (`Source/Blinki.Widgets.WaveAnimation.pas:162`)
  computes `Sin` + `LerpColor` per character per frame — fine for typical
  text lengths, but a precomputed sine table would remove the per-char `Sin`.

## Low priority / cleanup

### 11. Resize polling performs a syscall every tick

`PollResize` (`Source/Blinki.Core.App.pas:519`) calls `FBackend.GetSize` —
i.e. `GetConsoleScreenBufferInfo`
(`Source/Blinki.Core.Console.Windows.pas:265`) — 20 times per second purely
to detect a rare event. On Windows, react to `WINDOW_BUFFER_SIZE_EVENT` from
the input queue instead.

### 12. `Tick` recurses the whole tree every frame

`TTuiWidget.Tick` (`Source/Blinki.Core.Widget.pas:408`) invokes `DoTick` on
every widget in the tree each frame; most `DoTick` bodies are empty, so this
is pure virtual-call overhead proportional to widget count. A "needs-tick"
flag or a registered list of animated widgets would eliminate it.

### 13. Table sort parses floats on every comparison

The sort comparer (`Source/Blinki.Widgets.Table.pas:376`) calls
`TryStrToFloat` on both operands for every comparison — O(n log n) parses.
For large tables, pre-parse a numeric sort key. Only runs on sort, so low
priority.

### 14. Dead code

Commented-out `var` blocks remain in `DrawBox`
(`Source/Blinki.Core.Canvas.pas:319`) and `ComputeWidths`
(`Source/Blinki.Widgets.Table.pas:412`).

### 15. Duplicated logic

- `TryReadKey` (`Source/Blinki.Core.Console.Windows.pas:389`) largely
  duplicates `TryReadEvent` (`:341`) and is marked "kept for compatibility";
  candidate for removal or delegation.
- The modifier-decoding block is duplicated verbatim in `DecodeInputRecord`
  (`Source/Blinki.Core.Console.Windows.pas:286`) and `DecodeMouseRecord`
  (`:435`) — extract a helper.
- The focus-structure-changed closure is registered identically in `SetRoot`
  (`Source/Blinki.Core.App.pas:349`) and `PushModal` (`:617`).

### 16. Stale documentation

- The declaration comment for `ApplyDimOverlay`
  (`Source/Blinki.Core.App.pas:150`) says it "fills the entire canvas with a
  light-shade character", but the implementation applies the `taDim`
  attribute via `DimRect` (`:500`).
- The README refers to `BlinkiUnitTests.dproj`, but the actual unit-test
  runner is `Tests/UnitTests/Core/Blinki.UnitTests.Core.dpr`.

### 17. Build configuration

Under `IMPLICITBUILDING`, `Source/Blinki.dpk` sets `{$OPTIMIZATION OFF}`,
`{$RANGECHECKS ON}`, `{$OVERFLOWCHECKS ON}`, and `{$DEFINE DEBUG}`. Whenever
range checking is compiled in, the per-cell checks in the diff renderer
(item 2) are paid on every frame — verify that release builds of consumers
actually disable these checks on the hot paths.

## A note on tests

Current unit-test coverage is minimal: a single fixture (`TGeometryTests`,
8 tests) in `Tests/UnitTests/Core/Blinki.UnitTests.Core.Geometry.pas`. The
diff renderer, ANSI builder, layout solver, and widgets are untested. Before
optimizing items 1–5 it would be prudent to add unit tests for those modules
(the flush sequence and the layout solver are pure enough to test without a
real console), so regressions are caught by CI rather than by eye.

## Suggested implementation order

Best benefit/risk ratio first:

1. Dirty-skip of the render loop (item 1)
2. Unchecked diff loop (item 2)
3. Reusable string builder in flush (item 3)
4. Table width caching (item 4)

The remaining items are incremental and can be tackled independently.
