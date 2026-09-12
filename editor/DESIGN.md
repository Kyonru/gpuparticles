# Particle Studio design notes

The person using this is a LÖVE developer tuning an effect, then taking it back into a game. The live effect is the focal point; the surrounding controls should feel like a compact animation workbench.

Domain: emitters, spawn cones, lifetime envelopes, burst events, force fields, collision surfaces, compositing, and replay. The color world comes from graphite drawing surfaces, smoke, hot amber sparks, pale ash, oxidized copper, and water. UI selection uses amber; particle colors identify layers.

The signature is one editable composition viewed three ways: emitter origins in the canvas, layered lifetime strips in the timeline, and size/color envelopes in the inspector. Avoid dashboard metric cards, a large settings form replacing the preview, and decorative gradients. Gradients represent the actual color-over-life curve or the colors available in a picker.

All components use a 4 px spacing base, 12–16 px panel insets, a 40 px primary hit area, and tonal surfaces with subtle separators. Typography uses LÖVE's portable built-in face at 11, 13, 15, 19, and 24 px; size, alignment, and color distinguish values from labels. This keeps the standalone editor free of system-font paths and additional dependencies.

Component checkpoints:

- Preview: dominant dark ink surface, peach emitter gizmos, direct dragging, and no decorative background grid. The surrounding editor uses dark blue surfaces with beige text and teal secondary labels. Fill the drawable panel beneath its 56 px control strip and above its 32 px status strip. Preserve world proportions and expand visible world bounds, keeping particles, shader canvases, and hit testing aligned without an inner letterbox.
- Layers: narrow supporting column, compact selectable rows, explicit visibility and solo controls, matched layer colors in the timeline.
- Inspector: consistent inset fields and amber keyboard focus, six tabs arranged in two rows, independent scrolling, numeric entry as well as dragging.
- Numbers: click to type; drag either the value or its label along the initial horizontal/vertical axis (right/up increases). A 3 px threshold separates clicks from drags, Shift reduces sensitivity tenfold, and bounds clamp continuously with immediate reversal. Values follow each field's displayed precision. Release creates one undo step; Escape restores the previous value. Attractor strength shows pull at 100 px with a nearby units explanation.
- Particle contacts: the first Motion group makes the optional cost visible without scrolling. Its Self collision toggle states the 2048-slot cap before enabling; capacity reduction is reported and undone with the toggle. Radius, bounce, separation, and iteration fields reuse the numeric controls and their bounds. The Colliding droplets preset opens this group. Other layers retain their selected motion model.
- Texture: four built-in pixel sheets use a two-column grid of 40 px buttons above the selected sprite preview; amber marks the selected sheet. A dark preview well, readable drop instructions, and adjacent sheet dimensions make selection and import concrete. Reuses the 4 px spacing, 13 px labels, and keyboard focus state.
- Effects: pixel grid leads, followed by layer appearance controls. Optional outline colors and glow radius appear with their effect. Wrapped explanatory text preserves meaning at compact widths. Settings reuse existing tonal surfaces and keyboard-editable fields.
- Envelopes: actual lifetime colors and editable size points; selected stops share input focus treatment and have numeric controls.
- Color pickers: inline under the selected stop, with a 40 px swatch/hex row, a 112 px saturation/brightness area and 40 px-wide hue strip, plus an opacity track over checkerboard. Both solid and transparent color remain visible. Tint and enabled outline colors reuse the RGB picker. The full lifetime picker fits the compact inspector before numeric channels, which remain available by scrolling. Drag, keyboard focus, undo, and cancellation follow the shared input behavior.
- Timeline: supporting bottom band, stable seconds ruler, emission spans and burst diamonds, one bright playhead.
- Dialogs: raised graphite surface, visible title, bounded scrolling, focus constrained to their controls; errors keep the user's document intact.

Buttons, fields, tabs, toggles, and curve handles share hover, active, keyboard-focus, and disabled states. The canvas uses scene-space coordinates regardless of window size. Document actions retain undo history, and destructive navigation offers save/discard/cancel inside the editor.
