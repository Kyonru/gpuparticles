# Capabilities, limits, and performance

## Check the backend

Call this after graphics initialization:

```lua
local caps = gpu.getCapabilities()
print(caps.renderer[1], caps.renderer[2])
print('analytic', caps.analytic)
print('stateful', caps.stateful)
print('volume', caps.volume)
```

| Backend | Requires |
| --- | --- |
| Analytic emitter | Instancing, `drawInstanced`, GLSL 3 |
| Stateful emitter | Analytic support, high-precision pixels, `rgba32f`, four canvases |
| Volume world | GLSL 3, high-precision pixels, `rgba32f` |

LÖVE 11.x has no compute shaders. Stateful work runs fragment passes over float canvases; rendering uses instanced quads and vertex-stage texture reads.

Unsupported emitters fall back to `love.graphics.ParticleSystem`, log once, and report `getBackend() == 'native'`. The fallback keeps common controls but omits GPU collision and forces, reduces curves to eight stops, and cannot match deterministic GPU trajectories. Volume construction returns `nil, reason`.

## Fixed limits

| Feature | Limit |
| --- | ---: |
| Emitter capacity | 2²⁴ slots, memory permitting |
| Self-collision capacity | 24,000 slots |
| Editor self-collision capacity | 2,048 slots |
| Sprite-sheet frames | 256 |
| Volume cells | 1,048,576, texture size permitting |
| Volume materials | 8, including one liquid material |
| Sources / reactions | 64 / 16 |

Stateful emitters hold five `rgba32f` textures, 80 bytes per slot; simulated [depth](../particles/depth.md) adds 16 bytes per slot, and formula depth adds none. `emitter:getStateMemory()` reports the total. Settling liquid owns four `rgba32f` material canvases (64 bytes per cell); inertial liquid adds a velocity pair, divergence, and pressure pair (80 more bytes per cell), alongside world terrain and scratch fields. Particle and volume state use 32-bit floats. Keep coordinates near an effect and recreate very long-running systems before clock precision becomes visible. Particles retain ring-slot draw order; alpha sorting is unavailable.

## Measure the shipped effect

```sh
love particle-gpu bench
love particle-gpu self-collision-bench --count=10000
```

Tiny sprites can be submission-bound. Large translucent sprites become fill-rate-bound through overdraw. Compare the same resolution, size, shader, and blend mode.

Measured on an Apple M3 Max with LÖVE 11.5, a 512×512 target, and 3-pixel discs:

| Analytic slots | Build | Upload | Submit | Completed frame |
| ---: | ---: | ---: | ---: | ---: |
| 10,000 | 7.918 ms | 0.106 ms | 0.009 ms | 0.237 ms |
| 50,000 | 39.137 ms | 0.398 ms | 0.007 ms | 0.152 ms |
| 100,000 | 77.445 ms | 0.826 ms | 0.008 ms | 0.293 ms |
| 250,000 | 195.372 ms | 2.142 ms | 0.008 ms | 0.765 ms |

Build large emitters during loading. At 1920×1080 with 50,000 particles, completed time rose from 0.615 ms for 3-pixel sprites to 1.408 ms for 48-pixel sprites.

Self-collision cost grows approximately with `iterations × capacity²`:

| Slots | Off | 1 iteration | 2 iterations | 4 iterations |
| ---: | ---: | ---: | ---: | ---: |
| 256 | 0.047 ms | 0.161 ms | 0.186 ms | 0.368 ms |
| 1,024 | 0.050 ms | 0.342 ms | 0.598 ms | 1.123 ms |
| 2,048 | 0.051 ms | 0.939 ms | 1.714 ms | 3.353 ms |
| 10,000 | 0.055 ms | 6.718 ms | 12.267 ms | 24.519 ms |

Keep the collision buffer near the live count and begin with one iteration. Volume cost follows cell count, liquid transport and pressure steps, gas pressure iterations, active materials, and reactions.

Submission time measures Lua-to-driver work. Completed time forces synchronization and includes its overhead. Window FPS includes presentation, UI, and operating-system load.
