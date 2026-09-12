# Motion, forces, and lifetime

Analytic motion computes displacement from age. Stateful motion integrates acceleration from each particle’s current position and velocity. `mode='auto'` chooses between them.

## Compose analytic motion

```lua
local f = gpu.forces
local emitter = gpu.newEmitter {
  gravity = {0, 40},
  damping = 0.3,
  forces = {
    f.turbulence {amplitude={25,8}, frequency={3,5}},
    f.curl {amplitude=35, frequency=0.8},
  },
}
assert(emitter:getMode() == 'analytic')
```

Gravity and damping integrate exactly. Radial and tangential acceleration use a fixed basis from initial velocity. Curl and turbulence are deterministic functions of seed and age.

## Add custom GLSL

An analytic force returns displacement and receives `seed` and `age`:

```lua
f.custom {
  name = 'sideways',
  uniforms = {amplitude=12},
  code = 'return vec2(amplitude * age * age, 0.0);',
}
```

A stateful force returns acceleration and receives `p`, `velocity`, `age`, and `seed`:

```lua
f.custom {
  name = 'vortex',
  stateful = true,
  uniforms = {center={400,300}, strength=120},
  code = [[
    vec2 d = p - center;
    return vec2(-d.y, d.x) / max(length(d), 20.0) * strength;
  ]],
}
```

Supply a function body without a pragma or shader entry point. Scalar and two-to-four-component vector uniforms are supported. Shader variants cache by source and uniform types; changing values does not recompile.

## Sample the world

Flow fields encode acceleration in red and green and sample at current position, so they are stateful:

```lua
flowField = {
  texture = flowImage,
  origin = {0,0},
  size = {1920,1080},
  strength = 200,
  encoding = 'unorm',
}
```

`unorm` maps `[0,1]` to `[-1,1]`. Float textures may contain signed values directly.

Attractors also use current position:

```lua
attractors = {
  {x=400, y=300, strength=500000, softening=20},
  {x=600, y=300, strength=-200000, softening=40},
}
```

Positive strength attracts; negative strength repels. `softening` limits force near the center.

## Emit continuously or in bursts

```lua
local emitter = gpu.newEmitter {max=6000, rate=2000, lifetime={1,2.5}}
emitter:emit(256) -- uploads only this ring-buffer slice
```

Set `rate=0` for burst-only effects. Ring slots recycle and may overwrite living particles when capacity is too small.

## Warm and control

```lua
emitter:warm(1.5)
emitter:pause()
emitter:start()
emitter:stop()
emitter:reset()
```

Analytic warmup is exact `O(1)` clock offsetting. Stateful warmup runs simulation steps. Pause and stop suspend new births while living particles keep aging; reset clears particles and restores deterministic seeded replay.

Use `setEmitterLifetime(seconds)` to stop continuous births after a duration and `setParticleLifetime(min,max)` to rebuild the lifetime range. Stateful replay is repeatable with a fixed timestep, though GPU vendors need not produce bit-identical noise and iteration results.

See the runnable [custom shader animation](../tools/examples.md#custom-shaders) and [collision guide](collision.md).
