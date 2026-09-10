# Particle Studio

![Particle Studio with layered emitters and lifetime curve controls](../previews/editor.png)

A native LÖVE editor for layered GPU particle effects. Run either entry point from the directory containing `particle-gpu`:

```sh
love particle-gpu editor
love particle-gpu/editor
```

On macOS, the executable may be `/Applications/love.app/Contents/MacOS/love`. Press **E** in the root example picker to enter the editor. Both editor launchers use the same `gpuparticles-studio` save directory.

## Build an effect

Choose **Presets** for an ember fountain, arcane bloom, colliding rain, or a timed impact burst. Each is a composition of multiple emitters. The left column adds, duplicates, removes, reorders, hides, and solos layers. First in the list draws behind subsequent layers. Visibility is saved and exported; solo is a preview control.

The inspector has four tabs:

- **Emitter:** capacity, emission rate, deterministic seed, lifetime ranges, position, direction/spread, speed, and spawn-area geometry.
- **Motion:** gravity, damping, radial/tangential acceleration, turbulence, curl noise, an attractor, a procedural flow field, and circle/floor collision with bounce and friction.
- **Style:** additive/alpha blending, soft-disc/spark/ring/smoke shapes, up to 32 RGBA stops and 32 size stops, variation, rotation, and spin. Click the color ramp to select a stop, type an eight-digit `RRGGBBAA` value or edit channels, and drag size-curve points.
- **Timing:** emission start/duration and up to 32 timed bursts per layer. Set rate to zero for burst-only effects. Particles finish their lives after their emission window closes.

Click a number to type; drag its label to scrub. Scroll the inspector or use Page Up/Down. Tab changes keyboard focus, Enter activates a control, and arrow keys adjust focused numeric labels or curve points. Invalid values remain in the field until corrected or canceled with Escape.

Drag in the preview to position the selected emitter. Hold **Shift** to move its enabled circle collider, or **Alt/Option** to move its enabled attractor. These authoring edits commit once on release and replay the effect to the playhead. They do not modify particle buffers on every mouse event.

The bottom timeline shows emission windows, burst diamonds, and the playhead. Drag the playhead to seek. Analytic effects jump through scheduled events; stateful effects replay in batches of at most 32 simulation steps per editor update, keeping the interface responsive. **Project** changes the composition duration and looping. **Burst 256** auditions an unsaved burst; use Timing to author a persistent event.

## Save, import, and export

**Save** writes `projects/<name>.json` inside LÖVE's save directory. **Open** lists saved projects and opens that folder. You can also drop a saved project JSON onto the window. The import path parses bounded data; it does not evaluate Lua. Switching projects or quitting with edits prompts you to save, discard, or cancel.

On macOS the directory is usually:

```text
~/Library/Application Support/LOVE/gpuparticles-studio/
```

**Export Lua** writes `exports/<name>.lua`. Copy that file and the library's `gpuparticles/` directory into a LÖVE game. No editor files, external libraries, or texture assets are needed. The export embeds the same scheduler, configuration conversion, and procedural sprite generation used by the preview.

```lua
local effect
function love.load()
  effect = require('ember-fountain').new()
end
function love.update(dt) effect:update(dt) end
function love.draw() effect:draw() end -- optional x,y draw translation
function love.quit() effect:release() end
```

Exports expose `update(dt)`, `draw(x,y)`, `seek(seconds)`, `reset()`, `burst(layerIndex,count)`, and `release()`. Scene coordinates are 960×640 world pixels. `draw(x,y)` translates the complete effect, including the visible result of collisions simulated in that scene. Copy the entire `gpuparticles` folder, including shaders.

| Shortcut | Action |
| --- | --- |
| Space | Play / pause |
| R | Replay from the start |
| Cmd/Ctrl S | Save project |
| Cmd/Ctrl O | Open project |
| Cmd/Ctrl E | Export Lua |
| Cmd/Ctrl D | Duplicate selected layer |
| Cmd/Ctrl Z / Shift Z | Undo / redo |
| Delete / Backspace | Remove selected layer when not editing text |
| F1 | Help |

## Scope and limits

An effect can contain 12 layers with a total capacity of 500,000 particles, at most 250,000 per layer, and a timeline of 0.25–30 seconds. Each layer chooses its cheapest backend automatically; the preview displays the selected layer's actual backend. Collision, an attractor, or a flow field selects stateful simulation. The native fallback omits GPU-only forces and collision and resamples curves to eight stops.

Parameter changes rebuild the affected composition after a short debounce and replay to the playhead. Large stateful effects therefore take longer to edit than analytic ones. Scene capacity is displayed without per-frame GPU readback. The FPS counter includes the editor's UI and preview, so use the comparison/bench projects for performance measurements.

The editor authors the exposed controls above. It does not yet import arbitrary sprite sheets, paint SDFs, edit arbitrary GLSL, animate parameter keyframes, sort alpha particles, or emit new particles from GPU collision callbacks. Imported projects must use this editor's versioned schema. Lifetime curves use evenly spaced stops, matching the library. Collision retains the library's discrete-projection limits.

## Verification and source

```sh
love particle-gpu editor-test
python3 particle-gpu/scripts/verify.py --editor-only --mutations
love particle-gpu editor --smoke --capture
love particle-gpu editor --smoke --capture --compact
love particle-gpu editor --smoke --capture --preset=3
```

Tests cover real UI input, invalid entry, multi-stop editing, drag undo, document rollback, unsaved-change protection, exact burst boundaries, mode selection, bounded seeking, resource release, JSON/file round trips, and numeric/rendered export parity. The Python verifier runs an export in a separate LÖVE project containing only the generated effect and `gpuparticles/`, captures both editor sizes, and verifies tests fail when burst timing or automatic mode selection is deliberately broken.

The implementation is split into [document](../editor_support/document.lua), [runtime](../editor_support/runtime.lua), [model](../editor_support/model.lua), [storage](../editor_support/storage.lua), reusable [controls](../editor_support/ui.lua), [inspector](../editor_support/inspector.lua), [curves](../editor_support/curves.lua), [view](../editor_support/view.lua), and [application](../editor_support/app.lua). [Design notes](DESIGN.md) record the control and visual conventions.

The standalone editor uses relative symlinks for shared code, as the other example projects do. If your checkout does not preserve symlinks, use `love particle-gpu editor`. To copy the editor itself elsewhere, place real copies of `editor_support/` and `gpuparticles/` beside its `main.lua` and `conf.lua`.
