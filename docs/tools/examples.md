# Examples and comparison

The repository contains runnable projects for individual forces, collision, the editor, persistent materials, and performance comparisons.

## Effect browser

```sh
love particle-gpu
```

Use the arrow keys to select an effect and Space to emit. Each named force is also a standalone project, for example:

```sh
love particle-gpu/examples/curl
love particle-gpu/examples/flow
love particle-gpu/examples/heightfield
love particle-gpu/examples/sdf
```

The example runner asserts that every effect selected the expected mode.

## Custom shaders

```sh
love particle-gpu/examples/custom-shaders
```

This example injects a seeded helix displacement with `gpu.forces.custom`, then draws the emitter through a regular LÖVE fragment shader for color separation and glow. Press **G** to disable the fragment pass and compare it with the raw analytic particles.

![Custom analytic movement with fragment glow](../assets/images/custom-shaders.gif)

## Moving colliders

```sh
love particle-gpu/examples/colliders
```

Press **1**, **2**, or **3** to attach a circle, axis-aligned box, or rotating capsule to the mouse. The example keeps the same stateful particle stream while each collider moves through uniforms.

![Circle, box, and capsule collision example](../assets/images/colliders.gif)

## SDF collision groups

```sh
love particle-gpu/examples/sdf-groups
# or: love particle-gpu sdf-groups
```

This scene combines a floor, circular pillar, and rounded shelf into one signed distance field. Three particle emitters share that static terrain while using different moving-object filters:

- beige particles collide only with the SDF;
- peach particles also collide with the mouse-controlled player circle;
- teal particles also collide with an animated enemy box and capsule.

Press **P** or **E** to toggle the player and enemy collision groups. The example demonstrates why emitters should be split by collision behavior rather than by individual actor.

![SDF terrain with player and enemy particle collision groups](../assets/images/sdf-collision-groups.gif)

## Native versus GPU

```sh
love particle-gpu comparison
```

The split-screen comparison matches texture, emission, lifetime, gravity, speed, colors, and pixel size between LÖVE's `ParticleSystem` and gpuparticles. Its large number is window FPS; smaller counters show CPU update and draw-submission time.

| Key | Action |
| --- | --- |
| `1` / `2` / `3` | Native alone / GPU alone / both |
| `B` | Benchmark each implementation in isolation |
| Up / Down | Change capacity from 1,000 to 250,000 |
| `[` / `]` | Change particle width from 2 to 24 pixels |
| `M` | Switch GPU analytic and stateful mode |
| `C` | Toggle the mouse circle demonstration |
| `S` | Compare stateful particles with contacts off and on |
| `I` | Cycle one to four contact iterations |

Self-collision comparison counts range from 256 to 10,000. Both panels use GPU stateful emitters in that view so the contact pass is the isolated difference.

## Waterfall

```sh
love particle-gpu waterfall
```

Basalt Falls combines stateful droplet collision, an optional particle contact pass, persistent water volume, mouse interaction, shader curtains, and responsive plant meshes. Distant vegetation stays cached; nearby ferns use GPU wind deformation and lightweight spring response for contact.

![Waterfall with shader-deformed plants](../assets/images/waterfall-plants.gif)

## Volume materials

```sh
love particle-gpu volume
```

Cycle water, smoke, and hot-water-to-steam presets and toggle pixel or smooth rendering.

![Pixel water volume](../assets/images/volume-water-pixel.gif)
