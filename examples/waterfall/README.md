# Basalt Falls

Water volume now uses the reusable [`gpuparticles.newVolumeWorld` API](../../VOLUME_API.md). The waterfall's `fluid.lua` keeps scene settings and compatibility accessors; simulation shaders live in `gpuparticles/volume/`. The public API also supports gas smoke, custom forces/shading, multiple sources, terrain editing, and thermal conversion. Try `love particle-gpu volume` for those features.

![Waterfall cascading over sloped rocks into a pool](../../previews/waterfall.png)

```sh
love particle-gpu waterfall
love particle-gpu waterfall --self-collision
love particle-gpu waterfall --water-volume
# or
love particle-gpu/examples/waterfall
```

Three layers make the waterfall:

1. Shader-animated ribbons form the continuous water curtain.
2. Stateful GPU droplets collide with a signed-distance field containing the rocks and pool surface.
3. Analytic spray and mist decorate authored impact locations.

**F** switches to optional **water volume**. This runs a separate, persistent water grid across the entire scene: water falls from the source, spreads over rocks, fills low areas, and rises as more arrives. It does not require particle self-collision. Place the mouse circle against the right end of the first ledge (around **674, 306**, radius **55**) to obstruct the outlet. Water collects upstream and finds another route; moving the circle releases the obstruction. A circle suspended in open air redirects water around its sides. A temporary pool needs supporting geometry.

In volume mode, **V** stops/resumes inflow; accumulated water remains and continues settling. **R** empties and restarts the scene, **1** hides/shows the water, **D** shows the grid's actual collision mask, and the existing mouse, wheel, pause, and wind controls still work. Switching **F** off releases the grid and resumes the original particle emitters. Switching it on again starts empty. Particle capacity, rate, and self-collision selection are retained; **S** applies in particle mode.

The volume grid replaces the fixed pool, ribbons, droplets, and authored spray/mist while enabled. Those particle emitters pause, so an obstructed stream cannot leave a decorative waterfall running downstream. This is an alternative waterfall representation, not particle-to-grid fluid coupling or a new `gpuparticles.newEmitter` option. The editor and comparison continue to use their particle systems.

[Accumulation preview](../../previews/waterfall-volume.png) · [Mouse dam preview](../../previews/waterfall-volume-mouse.gif)

The implementation in [fluid.lua](../../example_support/waterfall/fluid.lua) uses **160×100 cells** at **8 world pixels per cell**, with three transport relaxations per 1/120-second scene step. Each relaxation computes four outgoing neighbor fluxes and then gathers them into the next state canvas. Outgoing mass is bounded by available mass, and neighbor transfers conserve volume. The nominal source supplies **12000 world px² per simulated second**, divided across relaxations; a submerged or blocked source admits only available space. The source is independent of decorative particle counts and lifetimes.

The four foreground rocks are solid; the old y=694 artwork surface is excluded. The scene edges and bottom contain water, and the top permits overflow. Moving the circle displaces stored water outward instead of clearing it. Volume temporarily covered by the circle stays in the grid and is redistributed over subsequent steps; a completely sealed pocket can retain it until the obstacle moves. All passes use nearest float canvases and replace blending. No GPU readback occurs during play, and disabling the feature frees its canvases/shaders. Unsupported hardware keeps the original waterfall with an unavailable label.

This is a coarse, compressible cellular approximation, not a Navier–Stokes or incompressible-liquid solver. Pressure is approximated by extra mass in filled cells; occupied screen area is therefore not an exact volume measurement. Sloping/mounded surfaces, cell-sized edges, and delayed redistribution are expected under strong inflow. It has no velocity advection, surface tension, particle splashes, or leaf-level water collision. Thin gaps and obstacles smaller than a cell are unresolved. Work scales with grid size and relaxation count, not all pairs of particles; the HUD reports window FPS for the current mode. The existing catch-up cap still slows simulation under load.

**1/2/3** toggle those layers. **D** shows the collision field, **Space** pauses, **R** restarts, **H** hides the HUD, and **Esc** exits. Hidden layers continue to simulate.

**S** toggles self-collision for the main droplet stream. Both modes use **24000 slots at 6000 droplets per simulated second**, with the same lifetime, seed, and spawn settings. Self-collision adds a **1.5 px contact radius** and one solver iteration alongside the rock and mouse collisions. Toggling restarts and warms only the droplets; scenery, spray, mist, wind, pause, and layer controls remain as set. **R** preserves the selected self-collision mode. The HUD shows contact status, droplet capacity, emission rate, and window FPS. Live count follows particle lifetimes; 24000 is the buffer capacity. For isolated timings, use the [comparison's S mode](../comparison/README.md).

At this density, self-collision can be expensive. The scene executes at most two fixed 1/120-second simulation steps per frame, dropping excess catch-up time under load. Motion and emission slow together rather than reducing the particle population.

The optional solver approximates contacts within the droplet emitter. Spray and mist stay analytic, and the shader ribbons remain the water curtain. Press **1** to hide the curtain and inspect droplets directly. Dense overlaps can remain; this does not conserve fluid volume. Native fallback labels contacts unavailable.

[Self-collision preview](../../previews/waterfall-self.png)

The mouse controls a circular obstacle while inside the scene. Scroll to change its radius; **C** toggles it. The circle and terrain both affect stateful droplets. Movement updates uniforms, without regenerating the terrain field or uploading particle records. The water curtain is visually clipped around the circle; decorative spray/mist do not collide. This is discrete projection, so fast mouse movement can skip particles and does not impart mouse velocity.

[Mouse collision preview](../../previews/waterfall-mouse.png)

The **51 nearby ferns** are two mesh batches. Their roots stay fixed while a vertex shader bends stems and attached leaves in varied wind. The same mouse circle drives a damped spring per fern, updated on the scene's 120 Hz clock; plants bend away and recover smoothly when contact ends. **W** toggles wind, and **C** also disables plant contact. Pause freezes wind and springs. Distant trees and scenery remain cached.

Move the circle over the ferns on the ledges or foreground to brush them. This is an artistic contact approximation, not cloth or per-leaf collision: deep overlap and very large circles can still intersect foliage. Spring displacement is bounded. Two plant draws upload spring offsets as uniforms; mesh vertices are built once, and there is no GPU readback.

[Plant contact preview](../../previews/waterfall-plants.gif) · [Plant geometry and springs](../../example_support/waterfall/plants.lua) · [Wind/deformation shader](../../example_support/waterfall/shaders/plants.glsl)

Edit [terrain.lua](../../example_support/waterfall/terrain.lua) to move, resize, or rotate rocks. Drawing and the distance-field generator use the same shape definitions. The 640×400 float texture covers a 1280×800 world and stores signed distance in world pixels. Its linear filtering is intentional; particle-state canvases remain nearest-filtered. If the rocks move, rebuild the field and adjust the artistic ribbons/impact emitters to match.

[scene.lua](../../example_support/waterfall/scene.lua) contains emission settings, bounce/friction, and the fixed 120 Hz simulation clock. [render.lua](../../example_support/waterfall/render.lua) and its shaders provide the canyon, curtain, pool, and overlays. Emitters are released before their caller-owned distance texture.

The default particle mode is an environmental effect. Optional self-collision separates droplets but does not accumulate fluid volume or generate CPU collision events; use **F** for the separate volume approximation described above. Spray is emitted at predefined locations. Particle collision uses discrete projection; very fast particles can cross thin obstacles between steps. When emitter fallback is active, droplets no longer collide, as labeled in the HUD. The demo's artwork itself requires GLSL 3 and float-texture support.

```sh
love particle-gpu waterfall-test
love particle-gpu waterfall --smoke --capture
love particle-gpu waterfall --mouse-collision --smoke --capture
love particle-gpu waterfall --plant-collision --smoke --capture
love particle-gpu waterfall --self-collision --smoke --capture
love particle-gpu waterfall --self-collision --mouse-collision --smoke --capture
python3 particle-gpu/scripts/verify.py --waterfall-only --mutations
love particle-gpu water-volume-test
python3 particle-gpu/scripts/verify.py --water-volume-only --mutations
```

The numeric tests shoot particles into both sloped ledges and assert corrected position and reflected velocity. A collision-disabled control must penetrate each ledge. They also inspect thousands of warmed particle states, require flow to the lower cascade, assert backend modes, and independently measure each visual layer's contribution. Capture mode prints the absolute path to `waterfall.png` in LÖVE's save directory.

Water-volume tests read float state to check gravity transfer, total mass against admitted source and overflow, upstream storage behind a circle dam, drainage when it moves, lateral spreading, persistence with inflow off, and conservation when the circle enters a pool. They check actual scene geometry/rendering, particle suspension/resumption, controls, resource cleanup, and unsupported-device fallback. Deliberate defects in blending, mass subtraction, circle blocking, displacement, and inflow scaling must fail. `--water-volume-only` runs these tests and captures both standalone volume scenes; capture mode warms this otherwise initially empty scene for 12 seconds.

Self-collision tests compare the full-density droplet stream with a matched emitter whose negligible radius removes pair contacts while retaining identical terrain projection passes. They verify numeric trajectory changes and rock/mouse exclusion, equal capacity/rate and warmed live counts across toggles, resource release, preserved decoration, and bounded updates after toggling. A deliberately negligible contact radius in the waterfall must make the trajectory-difference test fail.

Plant tests run the production vertex deformation shader into a float target and check numeric root/tip positions, wind, circle response, smooth recovery, bounded deep contact, and caller graphics-state restoration. `python3 particle-gpu/scripts/verify.py --demos-only --mutations` also verifies that breaking root anchoring and circle response makes those tests fail.

To copy this example out of the checkout, copy `main.lua`, `conf.lua`, `../../gpuparticles/`, and `../../example_support/` into a new folder as real directories; the checkout uses relative symlinks for shared code.
