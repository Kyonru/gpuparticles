# Measurements — 2026-09-10

LÖVE 11.5.0, OpenGL 4.1 Metal - 90.5, Apple M3 Max. Lua 5.1; **JIT reported false**. FFI ByteData construction was available. These are actual runs of this implementation, not the brief's minimal-particle timings.

512×512, 3px soft discs, uniform coverage, 40 repeated draws:

| Capacity | Build Lua ms | Mesh upload ms | Submit/frame ms | Completed/frame ms | Total creation ms |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 7.918 | 0.106 | 0.009 | 0.237 | 21.475 |
| 50,000 | 39.137 | 0.398 | 0.007 | 0.152 | 46.841 |
| 100,000 | 77.445 | 0.826 | 0.008 | 0.293 | 86.207 |
| 250,000 | 195.372 | 2.142 | 0.008 | 0.765 | 205.086 |

1920×1080, 50,000 soft discs, uniform coverage, 12 repeated draws:

| Width px | Submit/frame ms | Completed/frame ms |
|---:|---:|---:|
| 3 | 0.017 | 0.615 |
| 16 | 0.015 | 0.656 |
| 48 | 0.015 | 1.408 |

The example plume at 1080p had 31,909 live particles: **0.013 ms submission**, **1.038 ms completed/frame**. It uses 50k capacity, variable 1–3 s lifetime, speeds 80–220, damping, and 4→10→0 px sizes.

On a 100k ring, a warmed 512-particle burst averaged **0.768 ms including record construction and sliced upload**. The isolated 512-record upload averaged **0.180 ms**. The implementation uses 13-float records, deterministic randomness, and CPU lifetime metadata; its construction cost exceeds the brief's five-float example. Keep large buffer creation and spawn-setting refreshes out of frame-sensitive code.

“Submit” times the Lua draw loop. It can include driver backpressure. “Completed” measures the same batch through an unbound canvas readback, divided by the draw count. This includes an amortized readback and is **not an isolated GPU timer query**. Texture/driver warmup, scheduling, and the readback explain non-monotonic small measurements. Neither column promises a frame rate for a different effect. No readback is used by the library itself.

A second run with `--no-ffi` built 250k records in 148.164 ms and uploaded them in 29.072 ms; its 512-particle burst averaged 0.652 ms. Tables trade faster interpreted construction on this runtime for more upload time and temporary Lua memory. The default FFI path keeps the upload small without enabling global JIT settings.

Run `love particle-gpu bench` or `love particle-gpu/bench` to regenerate the tables on the machine and driver you ship.
