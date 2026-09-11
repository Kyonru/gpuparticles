# Appearance tools and responsive vegetation

This document tracks the additions requested after Particle Studio's first release.

## Scope

1. **Particle textures:** drop a PNG onto the editor's selected layer, preview it, choose nearest/linear filtering, and animate a regular sprite sheet over particle lifetime. Embed the image in JSON projects and exported Lua so effects remain portable. Keep generated shapes available.
2. **Pixel-art effects:** render selected layers to a lower-resolution canvas and enlarge with nearest filtering. Use an integer world-pixel grid; allow crisp sprites and stepped color palettes. Preserve particle motion and collision precision.
3. **Shader controls:** expose dissolve, outline, palette quantization/tint, distortion, and a soft halo. Apply these to the layer's rendered image; ordinary layers retain their existing direct draw path. These are appearance effects and must never select stateful particle simulation. Arbitrary GLSL authoring is a future extension.
4. **Responsive waterfall plants:** replace nearby cached ferns with rooted meshes. A vertex shader supplies varied wind; the existing mouse circle bends nearby stems. A damped spring per fern supplies smooth contact and recovery. Leaves follow the stem. Distant scenery remains cached.

## Design and behavior

Extend the existing charcoal and amber workbench: lifetime curves remain in Style; texture import and appearance controls have dedicated inspector tabs. Reuse the existing keyboard-editable numbers and buttons, spacing, focus states, and scrolling. The live effect remains the focal point. Sprite preview, sheet layout, and pixel-grid controls use the vocabulary of effects authoring rather than exposing shader implementation details.

Shader processing occurs after rendering one emitter into a transparent canvas. It affects the combined layer silhouette, rather than individual particles in isolation. Halo is a bounded local glow, not full-scene HDR bloom. Extra render passes have a cost; disabled appearance controls allocate no processing canvases. Pixel grids use world coordinates; an exported effect should be displayed at integer scale for consistent screen pixels. Editor previews fit the available viewport.

The preview uses its full drawable panel, showing additional world coordinates around the reference scene as needed. Appearance canvases follow these visible bounds, stay aligned to the pixel grid, include sampling padding, and are reused across stable frames. Numeric rendering checks cover particles above the former top edge, wide/compact layouts, pointer mapping, and shader-coordinate stability. A mutation that removes the preview bounds must make the clipping regression fail.

Plant interaction is a visual bending approximation, not a cloth solver. Roots stay attached and whole leaves remain connected. Deep overlap, very large circles, and rapid mouse movement need not resolve every leaf outside the obstacle. Wind and contact settings live with the waterfall example, independent of the standalone particle library. The water curtain remains its existing authored ribbon effect.

## Verification and progress

- [x] PNG import, malformed-input handling, sprite-sheet validation, save/load, and independent Lua export.
- [x] Pixel-grid and shader rendering checks, disabled-path behavior, automatic mode checks, and preview/export parity.
- [x] Root anchoring, wind deformation, circle response, spring recovery, and graphics-state preservation.
- [x] Editor and waterfall runtime checks, screenshots, documentation, and deliberate mutation checks.

Implemented in the **Texture** and **Effects** inspector tabs, the **Pixel embers** and **Spectral wisps** presets, and the waterfall's two reactive plant batches. PNGs are embedded, the original four presets remain available, and old projects receive neutral defaults. Native fallback now sizes and centers regular sprite-sheet particles using frame dimensions.

The Texture tab also offers built-in **pixel sparks, flame, smoke, and splash** sheets for every emitter. Frame counts and nearest filtering are automatic; selection preserves motion/colors and is undoable. The sheets are embedded just like imported PNGs, so exports have no dependency on the editor's sprite catalog. Tests render every frame, check animation changes, and compare preview/export pixels.

Verification on LÖVE 11.5 / Apple M3 Max:

```sh
python3 particle-gpu/scripts/verify.py
python3 particle-gpu/scripts/verify.py --editor-only --mutations
python3 particle-gpu/scripts/verify.py --demos-only --mutations
```

Rendered tests check sprite frames, palette values, silhouette expansion, distortion, a fully dissolved layer, four-pixel cell uniformity, premultiplied alpha, and native sheet dimensions. Export verification uses a separate project with only the exported Lua and `gpuparticles/`. Plant tests write production vertex-shader positions into a float canvas and assert root anchoring and tip displacement, then test spring contact/recovery and scene wiring. Deliberate defects in native sheet dimensions, texture filtering, alpha composition, dissolve, backend selection, scheduling, root anchoring, and circle contact must fail their corresponding tests. Normal and compact UI captures are in `previews/`; edited Lua passes luacheck.

**Future work:** arbitrary GLSL authoring, custom indexed palettes, packed atlases, parameter keyframes, full HDR bloom, and detailed leaf/cloth collision remain separate extensions. The current controls provide layer-level appearance effects and bounded visual plant bending.

## Optional particle contacts

Implemented `selfCollision` for selected effects: approximate equal-radius circles within one emitter, with 1–4 separation iterations and configurable radius/bounce/separation. The library supports up to 24000 slots, the comparison offers up to 10000, and the editor uses a 2048-slot limit. Each iteration packs live positions and resolves contacts on the GPU, reusing the state ping-pong buffers. Disabled effects keep their existing shader, resources, and update cost. Old editor projects default to off; the Motion toggle reports and records any capacity reduction as one undoable edit. Exports retain the setting.

The comparison's **S** mode compares two identically configured GPU stateful emitters, with contacts off/on. **B** isolates their window FPS at one fixed simulation step per frame. A separate completed-work benchmark separates simulation from overdraw and records results in [bench/SELF_COLLISION.md](bench/SELF_COLLISION.md). Dense piles can retain overlaps; this does not add fluid-volume conservation or cross-emitter contacts.

Verified with numeric pair separation/restitution, coincident centers, live/dead masks, padding, dense clusters, environment reprojection, graphics restoration, resource release, explicit limits, fallback, comparison isolation, editor undo, and preview/export state parity. Deliberate defects in pair separation, restitution, liveness, and environment reprojection all fail the tests.

The waterfall exposes **S** / `--self-collision` for its main droplets. Both modes use the original 24000 slots and 6000 droplets per simulated second, with the same seed, lifetime, and spawn settings, while retaining rock and mouse collision. Only droplets restart on toggling. Each rendered frame executes at most two 1/120-second simulation steps to bound catch-up under load. Its HUD reports the mode, capacity, rate, and window FPS. Spray and mist remain analytic. The editor places **Self collision** at the top of Motion and includes a **Colliding droplets** preset that opens those controls. Numeric waterfall tests cover equal emitted and warmed live counts, actual trajectory changes, simultaneous environment/mouse exclusion, resource release, and bounded catch-up; editor checks cover preset selection and visible controls.

The comparison adds 5000 and 10000 particles, selectable with Up/Down or `--self-collision --count=10000`. Preview catch-up is limited to two simulation steps per frame; isolated benchmarks retain one fixed step. Counts clamp without rebuilding at the endpoints. The numeric comparison test warms 10000 live particles on both sides, reads every colliding particle's state, verifies bounded positions/velocities and floor exclusion, and checks the catch-up limit. The completed-work benchmark accepts `--count=10000` for a focused run.

## Optional persistent water and temporary pools

Implemented in the waterfall under **F** / `--water-volume`, independent of particle self-collision. A conservative cellular grid spans the entire scene, with the same foreground rock geometry and the moving circle. Low areas fill, obstructed outlets retain upstream volume, and moving the obstacle releases it. **V** stops inflow while retaining pooled water; **R** empties the mode. A free-floating circle spills water around its sides. Particle layers pause and the grid replaces the fixed pool and authored water so downstream visuals follow the obstruction.

Three neighbor-flux/gather relaxations per scene tick run on a 160×100 GPU grid. Source volume is divided across relaxations and counted independently of particle emission. Rock solids exclude the original flat pool plane; sides/bottom contain water and the top accounts for overflow. Circle intrusion redistributes stored mass without deletion. Graphics state is restored and resources are allocated only when enabled, then explicitly released when disabled. Unsupported float canvases/shader compilation retain the default scene.

Verified through numeric mass budgets, gravity, spontaneous upstream pooling, drainage, spreading, source-off persistence, moving-collider displacement, overflow, scene rendering, controls, resource cleanup, and fallback. `--water-volume-only --mutations` checks the tests against reversible shader/transport defects and captures standalone previews. This remains a coarse compressible water approximation with visible grid edges and flow-dependent mounds, not incompressible fluid physics. Coupling volume to particle splashes, editor authoring, and a volume-versus-particle benchmark are future extensions.


## Reusable volume worlds

Implemented `gpuparticles.newVolumeWorld` with water and gas materials, multiple sources, fixed-step controls, wind, shared gas velocity/pressure, circle collision, terrain painting, heat and impulse brushes, and pixel/smooth rendering. Gas uses temperature-dependent buoyancy, advection, cooling, dissipation, and pressure projection. The waterfall delegates its volume simulation to this standalone API; particle emitters retain their existing behavior.

Materials accept cached custom GLSL acceleration/shading hooks with runtime uniform updates. Temperature-triggered conversion rules transfer density and heat from a material into gas. This supports stylized boiling without claiming general chemistry, incompressible liquid physics, or gas/liquid pressure coupling. The initial limits are one water material, eight total materials, 64 sources, and 16 conversion rules per world. Read [VOLUME_API.md](VOLUME_API.md) for units, capabilities, costs, resource ownership, and approximation limits.

Added the volume example (V in the picker, or `love particle-gpu volume`) with water, smoke, and steam, terrain brushes, mouse interaction, and both display styles. Numeric GPU tests cover source units, controls, heat/decay, smoke motion, pressure projection, thin walls, terrain displacement, conversion budgets, shader caching/uniform isolation, and rendering. The verification runner checks a copy containing only `gpuparticles/`, captures all six preset/style combinations, and catches twelve reversible defects. Existing water-volume, full waterfall, and particle-library regressions are also run. Volume authoring in Particle Studio and particle/volume coupling remain separate extensions.
