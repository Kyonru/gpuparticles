# Particle Studio design notes

The person using this is a LÖVE developer tuning an effect, then taking it back into a game. The live effect is the focal point; the surrounding controls should feel like a compact animation workbench.

Domain: emitters, spawn cones, lifetime envelopes, burst events, force fields, collision surfaces, compositing, and replay. The color world comes from graphite drawing surfaces, smoke, hot amber sparks, pale ash, oxidized copper, and water. UI selection uses amber; particle colors identify layers.

The signature is one editable composition viewed three ways: emitter origins in the canvas, layered lifetime strips in the timeline, and size/color envelopes in the inspector. Avoid dashboard metric cards, a large settings form replacing the preview, and decorative gradients. The only gradient is the actual color-over-life curve.

All components use a 4 px spacing base, 12–16 px panel insets, a 40 px primary hit area, and tonal surfaces with subtle separators. Typography uses LÖVE's portable built-in face at 11, 13, 15, 19, and 24 px; size, alignment, and color distinguish values from labels. This keeps the standalone editor free of system-font paths and additional dependencies.

Component checkpoints:

- Preview: dominant open charcoal surface, quiet world grid, warm emitter gizmos, direct dragging; the effect provides the contrast and color.
- Layers: narrow supporting column, compact selectable rows, explicit visibility and solo controls, matched layer colors in the timeline.
- Inspector: consistent inset fields and amber keyboard focus, four tabs, independent scrolling, numeric entry as well as dragging.
- Envelopes: actual lifetime colors and editable size points; selected stops share input focus treatment and have numeric controls.
- Timeline: supporting bottom band, stable seconds ruler, emission spans and burst diamonds, one bright playhead.
- Dialogs: raised graphite surface, visible title, bounded scrolling, focus constrained to their controls; errors keep the user's document intact.

Buttons, fields, tabs, toggles, and curve handles share hover, active, keyboard-focus, and disabled states. The canvas uses scene-space coordinates regardless of window size. Document actions retain undo history, and destructive navigation offers save/discard/cancel inside the editor.
