# Lifecycle and bursts

Continuous emission and explicit bursts share a fixed-size ring buffer. Overwriting an occupied slot is intentional. Increase capacity when live particles should rarely be replaced.

## Continuous emission

An implicit slot is scheduled from the configured emission rate and recycles every `max / rate` seconds. Analytic emission requires no per-frame record upload.

```lua
local emitter = gpu.newEmitter {
  max = 6000,
  rate = 2000,
  lifetime = {1, 2.5},
}
```

For this example, `rate * maximumLifetime = 5000`, so 6000 slots leave room before recycling.

## Bursts

```lua
emitter:emit(256)
```

Only the written ring slice is built and uploaded. A wrap is split into two slices. Cost therefore follows burst size rather than total capacity.

Set `rate=0` for a burst-only effect. `emit` is ignored while the emitter is paused or stopped.

## Warmup

```lua
emitter:warm(1.5)
```

Analytic warmup offsets the effect clock in `O(1)` and is exact. Stateful warmup performs fixed simulation steps and costs proportionally to the requested duration.

## Control emission

| Method | Behavior |
| --- | --- |
| `start()` | Resume emission without inventing births during the gap |
| `pause()` | Suspend emission and preserve remaining emitter lifetime |
| `stop()` | Suspend emission and reset remaining emitter lifetime |
| `reset()` | Clear particles and replay deterministic records from the seed |
| `setEmitterLifetime(seconds)` | Limit how long the emitter creates particles; negative is unlimited |
| `setParticleLifetime(min, max)` | Change particle life and rebuild implicit spawn records |

Living particles continue to age after pause or stop. Reset long-lived emitters that accumulate thousands of start/pause history entries.

## Deterministic replay

Spawn records use a private seeded generator independent of `love.math.random`. The same configuration and call sequence recreates the same records. Stateful integration is repeatable with the same fixed timestep, though GLSL noise and iterative simulation are not guaranteed bit-identical across GPU vendors.
