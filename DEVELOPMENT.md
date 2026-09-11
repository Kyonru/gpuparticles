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
