# gpuparticles

A standalone GPU particle module for **LÖVE 11.x**, verified on 11.5. No compute shaders, no dependencies, and no changes to LÖVE's global graphics settings. Copy the **`gpuparticles/` directory** into another LÖVE project and use `require('gpuparticles')`.

The analytic backend draws hundreds of thousands of particles with one instanced draw. It stores spawn records once and evaluates motion in the vertex shader. The stateful backend adds a float-canvas simulation pass for flow fields, attractors, and collisions. Unsupported GPUs use LÖVE's native ParticleSystem.

## Quick start

```lua
local particles = require('gpuparticles')
local emitter

function love.load()
  emitter = particles.newEmitter {
    max = 50000, mode = 'auto', seed = 42,
    rate = 2000, lifetime = {1, 2.5}, position = {400, 500},
    direction = -math.pi/2, spread = math.pi/6, speed = {80, 220},
    gravity = {0, 300}, damping = 0.4,
    sizes = {8, 12, 0},
    colors = {{1, 0.8, 0.3, 1}, {1, 0.2, 0, 0.6}, {0.2, 0.2, 0.2, 0}},
    spin = {-2, 2}, blendMode = 'add',
  }
  emitter:warm(1.5)
end

function love.update(dt) emitter:update(dt) end
function love.draw() emitter:draw() end
function love.keypressed(key)
  if key == 'space' then emitter:emit(256) end
end
function love.quit() emitter:release() end
```

`texture = image` is optional. Each emitter owns a generated soft disc when no image is supplied. Caller-supplied Images, Canvases, and Quads remain the caller's responsibility. `release()` is idempotent and releases the emitter's buffers, canvases, LUTs, and references to cached shaders.

`draw(x, y)` adds an optional draw translation. `position` is the simulation origin. Sizes are **quad widths in pixels**, angles are radians, time is seconds, and colors use LÖVE 11's numeric color range. Quads currently render as square particle billboards; atlas viewports control the sampled rectangle.

## Run the projects

From the directory containing `particle-gpu`:

```sh
love particle-gpu/probe          # exact hardware probe from the implementation brief
love particle-gpu               # interactive examples; arrows select, Space emits
love particle-gpu editor        # Particle Studio: layered effects, curves, timeline, Lua export
love particle-gpu comparison    # matched native / GPU particles, live FPS, isolated benchmark
love particle-gpu comparison --self-collision # same GPU preset, particle contacts off / on
love particle-gpu comparison --self-collision --count=10000 # larger contact workload
love particle-gpu self-collision-bench # completed simulation cost by count and iterations
love particle-gpu waterfall     # rock collision; S toggles bounded particle self-collision
love particle-gpu test          # real GPU numeric tests
love particle-gpu fallback      # force missing capabilities and draw the native fallback
love particle-gpu examples-test # compile, assert modes, and render every example
love particle-gpu bench         # submission and completed-work measurements
love particle-gpu/bench         # bench is also a standalone LÖVE project
love particle-gpu/examples/curl # each named effect is its own LÖVE project
```

The individual example and bench directories share code through relative symlinks. If your checkout does not preserve symlinks (some Windows Git setups), use the root launcher commands, which need none. For a separate bench folder, copy `gpuparticles/` alongside its `main.lua`. The distributable library itself uses no symlinks or repository paths.

On macOS, `love` may be `/Applications/love.app/Contents/MacOS/love`.

```sh
python3 particle-gpu/scripts/verify.py --mutations
python3 particle-gpu/scripts/verify.py --portable-only
python3 particle-gpu/scripts/verify.py --demos-only
python3 particle-gpu/scripts/verify.py --editor-only --mutations
luacheck particle-gpu --globals love jit --no-max-line-length
```

The Python runner is a development tool, not a library dependency. It runs the suite, native fallback, twelve force examples, and numeric checks for the waterfall, comparison, and editor. `--demos-only` also opens both standalone demos, runs the isolated FPS benchmark, and captures previews. `--editor-only` verifies editor workflows and exports in a separate project. With `--mutations`, it deliberately breaks simulation invariants, shader caching, comparison isolation, collision, editor timing, and automatic mode selection; it requires the corresponding tests to fail, restores each file in `finally`, and runs the restored tests again. Do not edit those files concurrently with mutation verification.

See [bench/RESULTS.md](bench/RESULTS.md) for measurements on the current machine and [API.md](API.md) for every method and force configuration.

## Particle Studio editor

Run `love particle-gpu editor`, or press **E** in the root example picker. Build compositions from up to 12 emitter layers, import PNG sprites and regular sprite sheets, edit color/size curves, combine forces and collision, and arrange emission windows and bursts on a timeline. Texture and Effects tabs add pixel grids, dissolve, outlines, palette/tint, distortion, and a soft glow. The editor includes undo/redo, deterministic replay, seven presets, and JSON projects with embedded images.

**Export Lua** produces a self-contained effect module that needs only `gpuparticles/` in your game. Its playback code is shared with the editor preview and verified with numeric GPU state and rendered-output comparisons. See the [editor guide](editor/README.md) for controls, files, limits, and integration code.

The [development document](DEVELOPMENT.md) records the appearance tools and interactive vegetation scope, implementation choices, and verification.

## Native / GPU comparison

Run `love particle-gpu comparison` or `love particle-gpu/examples/comparison`. The main example picker also opens it with **C**.

Both panels use the same falling-water preset: one shared soft-disc texture, the same emission rate, two-second lifetime, gravity, speed, colors, and size in pixels. The left panel uses LÖVE's actual `ParticleSystem`; the right uses `gpuparticles`, initially in analytic mode. Random positions are sampled independently, so this compares matched effects rather than identical particle trajectories. Native buffer scheduling can leave a small fraction of slots empty; the displayed live counts make that difference visible. The GPU count uses its full-buffer steady-state schedule without scanning 250,000 records every frame.

| Key | Action |
| --- | --- |
| **1 / 2 / 3** | Run native alone / GPU alone / both |
| **B** | Benchmark each alone for three seconds, excluding initial settling time |
| **Up / Down** | Change capacity from 1,000 to 250,000 per system |
| **[ / ]** | Change particle size from 2 to 24 pixels |
| **M** | Switch GPU analytic / stateful mode |
| **C** | Toggle the mouse collision demonstration; automatically selects stateful mode |
| **S** | Compare GPU stateful simulation with particle collisions off / on; counts from 256 to 10000 |
| **I** | Cycle 1–4 contact iterations in the particle collision comparison |
| **Mouse / wheel** | Hover either panel to position the circle; scroll to change its radius |
| **Space / R / Esc** | Pause simulation / restart / quit |

The large counter is **window FPS**. When both systems run, that counter includes both. Isolated results are recorded while only the selected system updates and renders particles. Both fixed 512×512 targets and the same UI remain on screen; VSync is disabled. Smaller counters measure **CPU update and draw-submission time**, excluding GPU completion. The native draw measurement includes LÖVE's CPU work building particle quads. FPS includes the LÖVE event loop, presentation, UI, and other system load; it is not a GPU timer. Increase size as well as count to explore fill-rate costs.

Collisions start disabled in this matched preset because the native system has no particle/environment collision API. **C** enables a separate demonstration: GPU particles collide with a mouse-controlled circle while native particles pass through. It clears previous benchmark results and switches to stateful simulation. **B** turns the obstacle off and restores the previous mode before benchmarking matching effects. **M** explicitly enables the GPU simulation path to measure its overhead with the same effect. Unsupported GPU features show a clearly labeled native fallback. See [examples/comparison/README.md](examples/comparison/README.md) for source locations and automated capture commands.

For particle-to-particle contact, press **S** in the comparison: both sides use GPU stateful emitters with the same seed, stream, floor, and sizes. The left has particle contacts disabled, the right enabled. **B** measures them independently with one fixed 1/120 s step per frame. Contact can spread out dense particles and reduce overdraw, so a higher window FPS does not imply a cheaper simulation. `love particle-gpu self-collision-bench` measures completed simulation separately from rendering; [results and limits](bench/SELF_COLLISION.md) include measured costs through 10000 particles and 1–4 iterations. This optional feature is also available at the top of **Motion → Particles against particles** in the editor, with a **Colliding droplets** preset to try it.

## Colliding waterfall

Run `love particle-gpu waterfall` or `love particle-gpu/examples/waterfall`, or press **W** in the main example picker.

**F** enables optional water accumulation, also available with `love particle-gpu waterfall --water-volume`. A 160×100 GPU grid carries persistent water across the whole scene, allowing pools on ledges and behind mouse-circle obstructions. **V** stops inflow without deleting existing water; moving the circle lets a blocked pool drain. This coarse cellular approximation replaces and pauses the artistic particle layers while enabled; it does not require self-collision. **F** returns to particles and releases the grid. See the [volume controls, previews, and limits](examples/waterfall/README.md). Verify it with `python3 particle-gpu/scripts/verify.py --water-volume-only --mutations`.

Press **S** to toggle droplet self-collision, or launch with `love particle-gpu waterfall --self-collision`. Both modes use 24000 slots and 6000 droplets per simulated second, with identical lifetime and spawn settings. Rocks and the mouse circle still collide with droplets. The HUD reports contact status, capacity, emission rate, and window FPS; **1** hides the curtain to inspect the particles. Each frame executes at most two simulation steps, slowing motion under heavy load instead of reducing density. Spray/mist remain analytic. See the [waterfall controls and limits](examples/waterfall/README.md).

The scene combines animated water ribbons, 24,000 available stateful droplet slots, and analytic spray/mist. A signed-distance texture contains the same rounded, sloped rock geometry used for drawing plus the pool surface. Droplets sample it at their current positions, project out of solid surfaces, and lose normal/tangential velocity through bounce and friction. Simulation uses fixed 1/120-second steps, with bounded catch-up after stalls.

**1** toggles the water ribbons, **2** droplets, **3** spray/mist, and **D** the collision field. **Space** pauses, **R** restarts, **H** hides the controls, and **Esc** quits. Hiding a layer leaves its simulation running so you can inspect the visual contributions at the same scene time.

Move the mouse into the scene to place a circular obstacle. The wheel changes its radius; **C** toggles it. Droplets collide with both the circle and the existing rocks. The water ribbons are visually clipped at the circle; spray and mist remain decorative. Mouse movement changes uniforms and leaves the terrain texture intact.

Nearby ferns are rooted meshes: wind bends them on the GPU, and the same mouse circle drives a damped spring per plant for brushing and recovery. **W** toggles wind. This is visual bending, with cached distant scenery; it does not simulate cloth or guarantee leaf-level separation.

In the default particle mode, spray and mist emit from authored impact locations. They are decoration, not GPU collision callbacks. Droplet self-collision does not conserve fluid volume, and the default pool surface is animated artwork. When emitter fallback is active, droplets no longer collide; this demo's artwork itself requires GLSL 3 and float-texture support. See [examples/waterfall/README.md](examples/waterfall/README.md) for the scene's editable geometry and numeric tests.

## Choosing the backend

`mode = 'auto'` selects `analytic` unless `collision`, `circleCollider`, enabled `selfCollision`, a nonempty `attractors` list, `flowField`, or a force marked `stateful` requires simulation. Explicit `mode = 'analytic'` rejects those features. Explicit `stateful` is available for applications that want iterative integration.

```lua
local caps = particles.getCapabilities()
print(caps.analytic, caps.stateful)
print(emitter:getMode())            -- analytic | stateful (the selected motion model)
print(emitter:getBackend())         -- gpu | native
print(emitter:getFallbackReason())  -- nil unless degraded
```

The analytic path requires instancing and GLSL 3. The stateful path additionally requires high-precision pixel shaders, `rgba32f` canvases, and four simultaneous render targets for spawn uploads. All MRT attachments use the same format. GPU resource or shader initialization failure also triggers native fallback. Capability detection and the original supported/formats/limits tables are exposed; nothing assumes the M3's capabilities on another machine.

The fallback logs once per loaded module. It resamples color/size curves to eight stops and omits GPU-only forces, collision, and fields. It has native particle-count/CPU limits and uses native randomness. The selected motion model remains available through `getMode()` even when degraded; use `getBackend()` to detect degradation.

## Runtime work and emission

* **Analytic:** `update(dt)` advances scalar clocks. It does no per-particle loop, buffer upload, simulation pass, or readback. `warm(seconds)` advances those clocks once, independent of duration and capacity. `draw` sends uniforms and makes one `drawInstanced` call. The suite checks allocation-free steady-state **update and draw**.
* **Stateful:** each nonzero update draws one fullscreen quad into the next `rgba32f` canvas, then swaps the pair. Enabled self collision adds two GPU passes per iteration and one packed-neighbor canvas; disabled emitters keep the original path. State is `xy = position`, `zw = velocity`. Three additional immutable spawn-record canvases make GPU recycling possible. Rendering uses one instanced draw and samples texel centers in the vertex shader. Warmup steps at 1/60 s by default (`warmStep` is configurable).
* **Bursts:** only the affected record slice is constructed/uploaded, with a second slice on wrap. Stateful bursts also stamp just those texels through MRT. Overwriting a living ring slot is intentional. Other slots retain their state. Once a burst expires, its slot is available for the next scheduled implicit birth.
* **Count:** `getCount()` scans CPU spawn metadata on demand. It does not read back state, but it is **O(max)**; avoid calling it every frame for a large emitter. Counts follow the same lifetime schedule, subject to CPU/GPU floating-point boundary differences.

Implicit particle `i` first appears at `i/rate` (one-based). Its slot repeats every `max/rate`, keeping the configured rate meaningful with variable lifetimes. When the buffer is too small, recycling replaces still-living particles. Size it to at least `rate * maximumLifetime` when that replacement is undesirable. Recycles reuse the slot's deterministic random record.

`pause` and `stop` stop emission while live particles continue aging. `start` resumes without inventing births during the gap. A small texture maps emission time to wall time; it changes only on resume. Repeated control changes add history entries, so reset long-lived emitters periodically if they undergo thousands of pauses. `reset` clears particles and restarts deterministic records while retaining the active/stopped status.

## Compatibility boundaries

The module supports all requested native-style method names. It is an API migration target, with these intentional behavior differences:

* Sizes are pixels instead of native texture-scale factors. The native fallback converts them. Offsets are pixel offsets from the GPU billboard's center; native offsets are approximated relative to its texture center.
* GPU color, size, acceleration, and damping edits affect live particles. Spawn-setting edits rebuild implicit records outside the frame loop while preserving explicit burst records. Those edits can change existing implicit trajectories; native setters generally affect future births. See the setter costs in [API.md](API.md).
* **Analytic `setPosition` moves implicit trajectories together.** Explicit bursts snapshot their spawn origin. Stateful particles retain their existing positions and use the new origin for future births. Moving-emitter trails should use bursts or stateful mode.
* Analytic radial/tangential acceleration uses a fixed basis from the initial velocity (a seeded direction when velocity is zero). Stateful radial/tangential acceleration uses current position relative to the emitter. Native acceleration that continually turns toward the current radial direction, combined with arbitrary other forces, is not generally a composable closed-form trajectory.
* `setInsertMode` controls ring placement: ascending slots, descending slots, or a random starting slot. GPU drawing retains buffer-slot order. It does not reproduce the native linked-list draw order after wrapping.
* Rotation is initial rotation plus spin times age. `relativeRotation` follows ballistic/simulated velocity; analytic noise displacement is not included in that orientation.
* **No per-particle alpha/depth sorting.** Additive blending is the default. Ordinary alpha blending uses fixed slot order, including across ring wraps.

These differences are explicit rather than hidden behind an automatic promotion to the more expensive backend.

## Numerical and performance limits

Simulation always uses `replace, premultiplied` blending, nearest-filtered state canvases, texel-center fetches, and restored caller graphics state. Numeric tests read float canvases **after unbinding**; the library never reads GPU state back during normal operation.

Stateful integration is semi-implicit Euler: acceleration changes velocity, then velocity changes position. Damping is exponential per step. Use a fixed simulation timestep for repeatable collision/flow results; large timesteps can tunnel through thin surfaces. Collision is projection and restitution, not continuous collision detection. Analytic forces added to stateful effects contribute their displacement difference each step.

Spawn records use a private seeded generator, independent of `love.math.random`. Replays are deterministic for the same configuration and call sequence. GLSL transcendental/noise results and iterative simulation are not promised bit-identical across GPU vendors. GPU clocks and state use 32-bit floats: use world coordinates near the effect and reset/recreate effects before very large elapsed times lose useful precision. Native fallback is not seed-equivalent.

Construction includes richer records and deterministic sampling than the brief's five-float minimal benchmark. On this machine LÖVE reports **JIT disabled**. `love particle-gpu bench --no-ffi` compares table construction against the default FFI path. Build large emitters at load time; guarded LuaJIT FFI fills ByteData directly when available, and `noFFI = true` exercises the table fallback. No global JIT settings are changed.

Stateful memory is approximately `5 * ceil(sqrt(max))² * 16` bytes in canvases, plus the shared-format 52-byte spawn records and CPU metadata. Curve and timeline textures add small allocations. Large soft particles and overdraw dominate GPU work; the bench reports completed wall time as well as submission time so a cheap CPU submission is never presented as the GPU's frame cost.
