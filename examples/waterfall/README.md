# Basalt Falls

![Waterfall cascading over sloped rocks into a pool](../../previews/waterfall.png)

```sh
love particle-gpu waterfall
love particle-gpu waterfall --self-collision
# or
love particle-gpu/examples/waterfall
```

Three layers make the waterfall:

1. Shader-animated ribbons form the continuous water curtain.
2. Stateful GPU droplets collide with a signed-distance field containing the rocks and pool surface.
3. Analytic spray and mist decorate authored impact locations.

**1/2/3** toggle those layers. **D** shows the collision field, **Space** pauses, **R** restarts, **H** hides the HUD, and **Esc** exits. Hidden layers continue to simulate.

**S** toggles self-collision for the main droplet stream. Both modes use **24000 slots at 6000 droplets per simulated second**, with the same lifetime, seed, and spawn settings. Self-collision adds a **1.5 px contact radius** and one solver iteration alongside the rock and mouse collisions. Toggling restarts and warms only the droplets; scenery, spray, mist, wind, pause, and layer controls remain as set. **R** preserves the selected self-collision mode. The HUD shows contact status, droplet capacity, emission rate, and window FPS. Live count follows particle lifetimes; 24000 is the buffer capacity. For isolated timings, use the [comparison's S mode](../comparison/README.md).

At this density, self-collision can be expensive. The scene executes at most two fixed 1/120-second simulation steps per frame, dropping excess catch-up time under load. Motion and emission slow together rather than reducing the particle population.

The optional solver approximates contacts within the droplet emitter. Spray and mist stay analytic, and the shader ribbons remain the water curtain. Press **1** to hide the curtain and inspect droplets directly. Dense overlaps can remain; this does not conserve fluid volume. Native fallback labels contacts unavailable.

[Self-collision preview](../../previews/waterfall-self.png)

The mouse controls a circular obstacle while inside the scene. Scroll to change its radius; **C** toggles it. The circle and terrain both affect stateful droplets. Movement updates uniforms, without regenerating the terrain field or uploading particle records. The water curtain is visually clipped around the circle; decorative spray/mist do not collide. This is discrete projection, so fast mouse movement can skip particles and does not impart mouse velocity.

[Mouse collision preview](../../previews/waterfall-mouse.png)

The **51 nearby ferns** are two mesh batches. Their roots stay fixed while a vertex shader bends stems and attached leaves in varied wind. The same mouse circle drives a damped spring per fern, updated on the scene's 120 Hz clock; plants bend away and recover smoothly when contact ends. **W** toggles wind, and **C** also disables plant contact. Pause freezes wind and springs. Distant trees and scenery remain cached.

Move the circle over the ferns on the ledges or foreground to brush them. This is an artistic contact approximation, not cloth or per-leaf collision: deep overlap and very large circles can still intersect foliage. Spring displacement is bounded. Two plant draws upload spring offsets as uniforms; mesh vertices are built once, and there is no GPU readback.

[Plant contact preview](../../previews/waterfall-plants.png) · [Plant geometry and springs](../../example_support/waterfall/plants.lua) · [Wind/deformation shader](../../example_support/waterfall/shaders/plants.glsl)

Edit [terrain.lua](../../example_support/waterfall/terrain.lua) to move, resize, or rotate rocks. Drawing and the distance-field generator use the same shape definitions. The 640×400 float texture covers a 1280×800 world and stores signed distance in world pixels. Its linear filtering is intentional; particle-state canvases remain nearest-filtered. If the rocks move, rebuild the field and adjust the artistic ribbons/impact emitters to match.

[scene.lua](../../example_support/waterfall/scene.lua) contains emission settings, bounce/friction, and the fixed 120 Hz simulation clock. [render.lua](../../example_support/waterfall/render.lua) and its shaders provide the canyon, curtain, pool, and overlays. Emitters are released before their caller-owned distance texture.

This is an environmental effect, not a fluid solver. Optional self-collision separates droplets but does not accumulate fluid volume or generate CPU collision events. Spray is emitted at predefined locations. Collision uses discrete projection; very fast particles can cross thin obstacles between steps. When emitter fallback is active, droplets no longer collide, as labeled in the HUD. The demo's artwork itself requires GLSL 3 and float-texture support.

```sh
love particle-gpu waterfall-test
love particle-gpu waterfall --smoke --capture
love particle-gpu waterfall --mouse-collision --smoke --capture
love particle-gpu waterfall --plant-collision --smoke --capture
love particle-gpu waterfall --self-collision --smoke --capture
love particle-gpu waterfall --self-collision --mouse-collision --smoke --capture
python3 particle-gpu/scripts/verify.py --waterfall-only --mutations
```

The numeric tests shoot particles into both sloped ledges and assert corrected position and reflected velocity. A collision-disabled control must penetrate each ledge. They also inspect thousands of warmed particle states, require flow to the lower cascade, assert backend modes, and independently measure each visual layer's contribution. Capture mode prints the absolute path to `waterfall.png` in LÖVE's save directory.

Self-collision tests compare the full-density droplet stream with a matched emitter whose negligible radius removes pair contacts while retaining identical terrain projection passes. They verify numeric trajectory changes and rock/mouse exclusion, equal capacity/rate and warmed live counts across toggles, resource release, preserved decoration, and bounded updates after toggling. A deliberately negligible contact radius in the waterfall must make the trajectory-difference test fail.

Plant tests run the production vertex deformation shader into a float target and check numeric root/tip positions, wind, circle response, smooth recovery, bounded deep contact, and caller graphics-state restoration. `python3 particle-gpu/scripts/verify.py --demos-only --mutations` also verifies that breaking root anchoring and circle response makes those tests fail.

To copy this example out of the checkout, copy `main.lua`, `conf.lua`, `../../gpuparticles/`, and `../../example_support/` into a new folder as real directories; the checkout uses relative symlinks for shared code.
