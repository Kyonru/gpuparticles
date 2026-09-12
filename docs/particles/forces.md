# Forces

Analytic forces return a displacement as a function of age. They compose without storing state. Stateful forces return acceleration from the particle's current position and velocity.

## Closed-form forces

```lua
local f = gpu.forces

local emitter = gpu.newEmitter {
  max = 50000,
  rate = 10000,
  lifetime = 3,
  forces = {
    f.acceleration(0, 40),
    f.turbulence {amplitude={25, 8}, frequency={3, 5}},
    f.curl {amplitude=35, frequency=0.8},
  },
}

assert(emitter:getMode() == 'analytic')
```

Base gravity and damping are integrated together exactly. Radial and tangential acceleration use a fixed basis from initial velocity in analytic mode. Curl and turbulence are deterministic displacement fields derived from seed and age.

## Custom analytic displacement

```lua
f.custom {
  name = 'sideways',
  code = 'return vec2(amplitude * age * age, 0.0);',
  uniforms = {amplitude=12},
}
```

The code receives `seed` and `age` and must return `vec2` displacement. Supply a function body, without a pragma or shader entry point. Uniform values may be numbers or vectors with two to four components.

## Custom stateful acceleration

```lua
f.custom {
  name = 'vortex',
  stateful = true,
  uniforms = {center={400, 300}, strength=120},
  code = [[
    vec2 d = p - center;
    return vec2(-d.y, d.x) / max(length(d), 20.0) * strength;
  ]],
}
```

Stateful code receives the current position `p`, velocity, age, and seed and returns acceleration. Marking the force stateful makes `mode='auto'` select the simulation backend.

The runnable [`custom-shaders` example](../tools/examples.md#custom-shaders) combines custom analytic movement with a separate LÖVE fragment shader.

## Flow fields

```lua
flowField = {
  texture = flowImage,
  origin = {0, 0},
  size = {1920, 1080},
  strength = 200,
  encoding = 'unorm',
}
```

The red and green channels encode acceleration. `unorm` maps an ordinary image from `[0,1]` to `[-1,1]`; float textures may use signed values directly. The field is sampled at current particle position, so it is stateful.

## Attractors

```lua
attractors = {
  {x=400, y=300, strength=500000, softening=20},
  {position={600, 300}, strength=-200000, softening=40},
}
```

Positive strength attracts and negative strength repels. Pull falls with squared distance; `softening` limits acceleration near the center. Particle Studio displays strength as acceleration at 100 pixels, which produces easier authoring values while exports retain the raw coefficient.

Shader variants are cached by force source and uniform types. Changing uniform values does not compile a shader per frame. Recreate an emitter when its force set or custom code changes.
