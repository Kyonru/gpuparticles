# Optional particle collision: measured cost

Measured on **2026-09-10**, LÖVE **11.5.0**, **Apple M3 Max**, OpenGL **4.1 Metal - 90.5**.

```sh
love particle-gpu self-collision-bench
love particle-gpu self-collision-bench --count=10000
# Or from the standalone comparison project:
love particle-gpu/examples/comparison --self-bench

# Interactive FPS comparison; B isolates each side:
love particle-gpu comparison --self-collision
love particle-gpu comparison --self-collision --benchmark --smoke --capture
```

The completed-work benchmark uses the same deterministic falling stream, floor, 12 px soft-disc texture, four-second lifetime, and full live capacity as the interactive comparison. Both configurations are stateful; only particle contacts differ. Each step advances 1/120 s. Results are **completed wall milliseconds**, the median of three batches of 30 steps; each batch ends with an amortized GPU readback. This includes CPU submission and synchronization overhead and is **not a hardware GPU timer query**. No readback is used in normal particle updates.

| Slots | Simulation off | 1 iteration | 2 iterations | 4 iterations |
|---:|---:|---:|---:|---:|
| 256 | 0.0471 ms | 0.1608 ms | 0.1862 ms | 0.3684 ms |
| 512 | 0.0533 ms | 0.1913 ms | 0.3225 ms | 0.5663 ms |
| 1024 | 0.0503 ms | 0.3424 ms | 0.5977 ms | 1.1226 ms |
| 2048 | 0.0512 ms | 0.9392 ms | 1.7139 ms | 3.3532 ms |

Update plus drawing to a **512 × 512** target:

| Slots | Contacts off | 1 iteration | 2 iterations | 4 iterations |
|---:|---:|---:|---:|---:|
| 256 | 0.1419 ms | 0.2124 ms | 0.2712 ms | 0.4562 ms |
| 512 | 0.1034 ms | 0.2276 ms | 0.3510 ms | 0.6026 ms |
| 1024 | 0.1054 ms | 0.3843 ms | 0.6392 ms | 1.1177 ms |
| 2048 | 0.1233 ms | 1.0566 ms | 1.8732 ms | 3.5203 ms |

Additional **10000-particle** run on the same machine, using `--count=10000` and the same methodology:

| Contact iterations | Simulation | Update + draw |
|---:|---:|---:|
| Off | 0.0552 ms | 0.3738 ms |
| 1 | 6.7175 ms | 7.9918 ms |
| 2 | 12.2668 ms | 14.0332 ms |
| 4 | 24.5191 ms | 25.2551 ms |

The two tables are measured in separate batches. Small inversions are timing noise. These values characterize this GPU, preset, and resolution; they are not a promised frame budget. At 120 simulation steps per second, a 60 Hz rendered frame can contain two simulation steps.

The interactive comparison shows shared window FPS and isolated off/on FPS, plus CPU update and draw-submission timings. Its **B** benchmark runs each side alone for three seconds, excludes settling, and performs exactly one 1/120 s simulation step per measured frame. Window FPS includes presentation, UI, and system load. Contact can reduce overdraw by spreading a dense pile, so the FPS comparison includes that visual consequence; use the simulation-only table to see solver overhead.

Implementation: one extra float canvas, two extra draws per iteration, all-pairs neighbor checks within one emitter, worst-case **O(iterations × slots²)**. The comparison supports up to **10000** slots and **1–4** iterations; the library allows **24000** so the waterfall keeps the same density in both modes. The benchmark includes 5000 and 10000, or accepts `--count=10000` for a focused run. The original analytic/stateful path has no extra collision cost when disabled. Fixed-radius circles and averaged contact corrections are intended for visual effects; dense piles can retain overlap. See [API](../API.md) for configuration and approximation limits.
