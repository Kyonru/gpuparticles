# Performance

Measure the shape and resolution you plan to ship. A draw call with tiny particles can be submission-bound while large translucent sprites at 1080p become fill-rate-bound.

```sh
love particle-gpu bench
love particle-gpu self-collision-bench
love particle-gpu self-collision-bench --count=10000
```

## Analytic measurements

Measured on LÖVE 11.5, Apple M3 Max, OpenGL 4.1 Metal, using a 512 × 512 target and 3-pixel soft discs:

| Capacity | Build Lua | Upload | Submit/frame | Completed/frame |
| ---: | ---: | ---: | ---: | ---: |
| 10,000 | 7.918 ms | 0.106 ms | 0.009 ms | 0.237 ms |
| 50,000 | 39.137 ms | 0.398 ms | 0.007 ms | 0.152 ms |
| 100,000 | 77.445 ms | 0.826 ms | 0.008 ms | 0.293 ms |
| 250,000 | 195.372 ms | 2.142 ms | 0.008 ms | 0.765 ms |

Construction uses richer deterministic 13-float records than a minimal particle benchmark. Build large emitters during loading. Spawn-setting edits perform the same kind of record refresh.

At 1920 × 1080 with 50,000 particles, completed time grew from 0.615 ms for 3-pixel sprites to 1.408 ms for 48-pixel sprites. Overdraw and shader appearance dominate before vertex count on this hardware.

## Self-collision measurements

Completed simulation cost at a fixed 1/120-second step:

| Slots | Off | 1 iteration | 2 iterations | 4 iterations |
| ---: | ---: | ---: | ---: | ---: |
| 256 | 0.0471 ms | 0.1608 ms | 0.1862 ms | 0.3684 ms |
| 1,024 | 0.0503 ms | 0.3424 ms | 0.5977 ms | 1.1226 ms |
| 2,048 | 0.0512 ms | 0.9392 ms | 1.7139 ms | 3.3532 ms |
| 10,000 | 0.0552 ms | 6.7175 ms | 12.2668 ms | 24.5191 ms |

Each iteration adds two draws and compares all allocated slots, including inactive ones. Cost grows approximately with capacity squared. Keep the buffer close to the actual live count and start with one iteration.

## Volume cost

Volume work scales with grid area, active materials, sources, reactions, water transport steps, and gas pressure iterations. Water uses two grid draws per transport relaxation. Gas adds shared force, divergence, pressure, projection, and per-material transport passes. A reaction adds three passes.

Regular simulation never visits each particle or grid cell in Lua and performs no readback. `readback()` and completed-work benchmarks intentionally synchronize the GPU.

## Interpret benchmark numbers

Submission time measures how fast Lua hands commands to the driver. Completed time ends a batch with a readback and includes synchronization overhead; it is not a hardware timer query. Window FPS also includes presentation, UI, and operating-system load. Compare results on the same machine, driver, resolution, and effect.
