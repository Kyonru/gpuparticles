# API

For persistent water, smoke, editable terrain, custom volume shaders, and thermal conversion, see the separate [volume-world API](VOLUME_API.md). Particle emitters retain the API below.

## Construction

`gpuparticles.newEmitter(config)` creates an active emitter. Defaults:

| Setting | Default | Meaning |
|---|---|---|
| `max` | `1000` | Ring capacity; integer from 1 through 2²⁴, subject to device memory |
| `mode` | `'auto'` | `'analytic'`, `'stateful'`, or automatic selection |
| `rate` | `0` | Births/second; zero is burst-only |
| `lifetime` | `{1,1}` | Particle lifetime; scalar or `{min,max}`, positive |
| `position` | `{0,0}` | Emitter position |
| `speed` | `{0,0}` | Initial speed; scalar or range |
| `direction`, `spread` | `0`, `0` | Direction and full angular spread, radians |
| `gravity` | `{0,0}` | Constant acceleration |
| `acceleration` | derived from gravity | `{minX,minY,maxX,maxY}` |
| `damping` | `0` | Nonnegative exponential damping, scalar or range |
| `radialAcceleration`, `tangentialAcceleration` | `0` | Scalar or range; see compatibility notes |
| `sizes` | `{8,0}` | Evenly spaced width stops in pixels |
| `colors` | white → transparent | Evenly spaced RGB/RGBA stops |
| `sizeVariation`, `spinVariation` | `0` | Values from 0 to 1 |
| `spin`, `rotation` | `0` | Scalar or range in radians/sec and radians |
| `relativeRotation` | `false` | Orient to velocity |
| `stretch` | `0` | Seconds of travel a velocity streak covers: each billboard lengthens behind its particle by `speed × stretch` and aligns to velocity |
| `carry` | `{0, 0}` | Stateful only: velocity moving particles are carried by on top of their own, such as a camera's; velocity and streaks are unchanged and stopped particles stay put |
| `emissionArea` | `{distribution='none',x=0,y=0}` | Area settings below |
| `emitterLifetime` | `-1` | Negative means unlimited; otherwise seconds of active emission |
| `offset` | `{0,0}` | Pixel offset from billboard center |
| `quads` | `{}` | Texture-atlas animation, progressing over lifetime |
| `insertMode` | `'top'` | Ring placement: `'top'`, `'bottom'`, `'random'` |
| `blendMode` | `'add'` | A LÖVE blend mode |
| `seed` | `1` | Private deterministic record generator seed |
| `forces` | `{}` | Force descriptors below |
| `selfCollision` | disabled | Optional equal-radius particle contacts; see below; maximum 24000 slots |
| `circleCollider`, `boxCollider`, `capsuleCollider` | disabled | Optional movable uniform obstacles; each selects stateful mode |
| `collisionResponse` | `'bounce'` | Emitter-wide contact action: bounce, slide, stop, disappear, or respawn |
| `depth` | disabled | Optional per-particle z: depth code, or simulated z that selects stateful mode; see [Depth](#depth) |

`texture`, `collision`, `flowField`, and `attractors` are optional. The library does not take ownership of caller textures or quads. Construct after LÖVE graphics initialization.

## Methods

All setters and controls return the emitter for chaining. `update`, `draw`, and `release` do not.

| Method | Operation / GPU cost |
|---|---|
| `update(dt)` | Advance time / one stateful pass, plus two passes per self-collision iteration when enabled; dt must be nonnegative and finite |
| `draw(x=0,y=0,options)` | One instanced draw with optional translation; `options` selects a depth half and cues on `depth` emitters |
| `getStateMemory()` | Bytes held in particle state and spawn-record textures; `0` for analytic and native emitters |
| `emit(n)` | Burst, clamped to capacity; O(n) build/upload; ignored while stopped/paused |
| `warm(seconds)` | O(1) analytic; repeated simulation steps stateful |
| `setColors(c1,c2,...)` | RGBA tables, a list of tables, or flat RGBA groups; upload curve LUT |
| `setSizes(s1,s2,...)` | Numbers or one list; upload curve LUT |
| `setSizeVariation(v)` | Set seeded size variation; refresh implicit records |
| `setSpeed(min,max=min)` | Refresh implicit records |
| `setSpread(radians)` | Refresh implicit records |
| `setDirection(radians)` | Refresh implicit records |
| `setLinearAcceleration(x,y,maxX=x,maxY=y)` | Uniforms; applies to live GPU particles |
| `setRadialAcceleration(min,max=min)` | Uniforms |
| `setTangentialAcceleration(min,max=min)` | Uniforms |
| `setLinearDamping(min,max=min)` | Uniforms |
| `setSpin(min,max=min)` | Refresh implicit records |
| `setSpinVariation(v)` | Refresh implicit records |
| `setRotation(min,max=min)` | Refresh implicit records |
| `setRelativeRotation(boolean)` | Uniform |
| `setStretch(seconds)` | Uniform; nonnegative |
| `setCarry(vx, vy)` | Uniform; cheap to call every frame; stateful only |
| `setEmissionArea(distribution,x=0,y=0,angle=0,directionRelative=false)` | Refresh implicit records |
| `setEmitterLifetime(seconds)` | Reset remaining active emission time |
| `setParticleLifetime(min,max=min)` | Refresh implicit records |
| `setPosition(x,y)` | Origin uniform; burst records keep their captured origin |
| `setCircleCollider(x,y,radius)` | Move/resize and enable a circular obstacle in simulation coordinates; O(1), no uploads or shader rebuild |
| `setCircleCollider()` | Disable the circle; keep its configured bounce/friction |
| `setBoxCollider(x,y,width,height)` | Move/resize and enable an axis-aligned box obstacle; O(1) uniforms |
| `setBoxCollider()` | Disable the box |
| `setCapsuleCollider(x1,y1,x2,y2,radius)` | Move/resize/rotate a capsule segment obstacle; O(1) uniforms |
| `setCapsuleCollider()` | Disable the capsule |
| `setCollisionResponse(mode)` | Change the emitter-wide contact action through one uniform update |
| `setOffset(x,y)` | Billboard offset uniform |
| `setQuads(q1,q2,...)` | Quads or one list; upload atlas LUT; no arguments clears it |
| `setInsertMode(mode)` | Change ring placement/cursor, without sorting |
| `setBufferSize(n)` | Reallocate and clear particles; maximum 24000 with self collision enabled |
| `setEmissionRate(rate)` | Refresh implicit records and phase from current emission clock |
| `start()` | Resume emission; update clock mapping if needed |
| `stop()` | Stop emission and reset remaining emitter lifetime |
| `pause()` | Stop emission while preserving remaining emitter lifetime |
| `reset()` | Clear particles and replay from seed; retain active/stopped state |
| `release()` | Release owned resources and cached shader references; idempotent |

Implicit-record refresh is **O(max)** and performs a full mesh upload. Explicit burst records are preserved. Stateful refresh updates spawn templates without overwriting current simulated state. Construct with the final configuration, or make these changes outside latency-sensitive frame paths. Curves have the hardware texture-width limit; GPU curves support more than eight stops without a shader recompile.

Diagnostics: `getMode()`, `getBackend()`, `getStateMemory()`, `getFallbackReason()`, `getCount()` (O(max)), `getPosition()`, `getBufferSize()`, `getEmissionRate()`, `getEmitterLifetime()`, `getParticleLifetime()`, `getStretch()`, `getCarry()`, `isActive()`, `isPaused()`, `isStopped()`, `isEmpty()`, and `isFull()`.

Area distributions: `none`, `uniform` (rectangle), `normal`, `ellipse`, `borderellipse`, and `borderrectangle`. `x,y` are half-extents or normal standard deviations. The area rotates by `angle`. With `directionRelative`, each initial direction is rotated by its sampled position's angle.

## Analytic forces

```lua
local f = require('gpuparticles').forces
local emitter = require('gpuparticles').newEmitter {
  max = 50000, rate = 10000, lifetime = 3,
  forces = {
    f.acceleration(0, 40),
    f.turbulence { amplitude = {25, 8}, frequency = {3, 5} },
    f.curl { amplitude = 35, frequency = 0.8 },
  },
}
assert(emitter:getMode() == 'analytic')
```

Acceleration contributes `a*t²/2`. Turbulence contributes `amplitude * (sin(frequency*t + seed*2π) - sin(seed*2π))`; frequency is radians/sec. Curl uses central derivatives of a smooth scalar value-noise potential evaluated at a seeded coordinate plus time, and subtracts its birth value. These are deterministic displacement terms, not forces sampled at current particle position.

Gravity/damping in the base trajectory are integrated together exactly:

```
D = (1 - exp(-k*t))/k
position = origin + velocity0*D + acceleration*(t-D)/k
```

The zero-damping branch is the ballistic formula. Independent force displacements compose additively; base damping does not damp those added displacement terms.

```lua
f.custom {
  name = 'sideways',             -- valid GLSL identifier
  code = 'return vec2(amplitude * age * age, 0.0);',
  uniforms = { amplitude = 12 }, -- numbers or 2–4 component vectors
}
```

Analytic custom code receives `seed` and `age` and must return a `vec2` displacement. It must be stateless; no Lua callback runs per particle. Unknown force kinds are rejected. Uniform names are namespaced before shader assembly. Shader variants are shared by canonical force/source set, independent of parameter values and list ordering, and released when their final emitter is released. Editing a configuration table after construction is not a supported force-update API; construct a new effect when its force set changes.

## Stateful forces

### Optional particle-to-particle collision

```lua
local particles = require('gpuparticles')
local emitter = particles.newEmitter {
  max = 1024, mode = 'auto', rate = 256, lifetime = 4,
  position = {300, 40}, emissionArea = {distribution='uniform', x=70, y=0},
  direction = math.pi/2, speed = 90, gravity = {0,220}, sizes = {12},
  collision = {type='plane', y=460, radius=6, bounce=0.15},
  selfCollision = {radius=6, bounce=0.2, strength=0.8, iterations=1},
}
assert(emitter:getMode() == 'stateful')
```

`selfCollision = true` uses defaults: radius **3 px**, bounce **0.2**, separation strength **0.8**, and **1 iteration**. `false`, omission, or `{enabled=false}` disables it. Automatic mode then depends on the remaining effect settings. Explicit analytic mode rejects enabled self collision. Configuration is fixed at construction; recreate the emitter to enable/disable contacts or change their settings.

The radius must be positive; bounce and separation strength range from 0 to 1; iterations must be an integer from 1 to 4. Enabled emitters have a hard capacity limit of **24000**, exposed as `gpuparticles.selfCollisionLimit`. Construction and `setBufferSize` reject larger buffers with a clear error. The limit applies to allocated slots, including slots that are not currently alive. The waterfall uses 24000 slots to keep its density identical with contacts on or off; the comparison offers up to 10000 and the editor uses a 2048-slot authoring limit. GPU work grows quadratically with capacity.

Each live particle is an equal-mass circle with this fixed radius, independent of sprite shape, size curves, or transparency. It interacts only with live particles in **the same emitter**. Each iteration reads a snapshot of current positions, separates overlapping pairs, and exchanges approaching normal velocity using restitution. Corrections are averaged across contacts to keep dense clusters bounded. A deterministic opposing direction handles coincident centers. Environment/circle projection is reapplied after contacts.

This is an approximate visual solver: overlaps can remain in piles, dense contacts can lose energy, and it does not provide rigid-body accuracy, fluid pressure/volume conservation, friction between particles, cross-emitter collisions, or continuous collision detection. Use small fixed timesteps (the comparison uses 1/120 s), avoid spawning many particles at precisely one point, and try more iterations when needed. Very fast particles can tunnel between steps.

The optional path adds one nearest-filtered `rgba32f` canvas and two cached shaders. Each iteration packs position/liveness, then resolves contacts using the existing state ping-pong pair: **two extra draws per iteration**, with worst-case GPU work **O(iterations × capacity²)**. CPU work remains independent of particle count and there is no readback. Disabled emitters allocate none of these resources or passes and keep the existing simulation shader. Native fallback draws particles but omits contacts; inspect `getBackend()`.

Run `love particle-gpu comparison --self-collision` for an interactive GPU off/on comparison, or `love particle-gpu self-collision-bench` for completed simulation/update-and-draw timings across capacities and iterations. See [measured results](bench/SELF_COLLISION.md).

### Fields and environment

### Flow field

```lua
flowField = {
  texture = flowImage,
  origin = {0,0}, size = {1920,1080},
  strength = 200,
  encoding = 'unorm', -- map RG from [0,1] to [-1,1]; default is signed RG
}
```

RG represents acceleration. Sampling uses `(currentPosition - origin) / size`. `size` defaults to the texture dimensions, `strength` to 1. Supply a float texture for signed/unbounded values, or use `unorm` for ordinary images. The caller controls the field texture's filtering and wrapping. Updating the contents of a supplied Canvas updates the field without recreating the emitter.

### Attractors

```lua
attractors = {
  {x=400, y=300, strength=500000, softening=20},
  {position={600,300}, strength=-200000, softening=40},
}
```

Each acceleration is `delta * strength / max(distance², softening²)^(3/2)`; the denominator has a small nonzero floor. Negative strength repels. Entries are packed into a texture at construction; an empty list leaves auto mode analytic.

### Collision

```lua
collision = {type='plane', y=600, radius=3, bounce=0.7, friction=0.1}

collision = {
  type='heightfield', texture=heightImage,
  origin={0,0}, size={1920,1080},
  scale=1080, bias=0, radius=3, bounce=0.7,
}

collision = {
  type='sdf', texture=signedDistanceImage,
  origin={0,0}, size={1920,1080},
  scale=1, bias=0, radius=3, bounce=0.7,
}
```

The plane is horizontal, solid below `y`. A heightfield's red channel encodes `height = origin.y + red*scale + bias`; it samples the middle texture row and estimates the surface normal with neighboring samples. An SDF's red channel encodes signed distance in world pixels (`red*scale+bias`), **positive outside** the solid. The gradient determines its normal. Both texture collision types require positive world dimensions.

Penetration projects the particle center to the surface plus `radius`. `bounce` is restitution (default 0.5); `friction` removes that fraction of tangent velocity (default 0). Particle visual size does not automatically change collision radius.

### Moving uniform obstacles

```lua
local emitter = require('gpuparticles').newEmitter {
  max=20000, rate=5000, lifetime=3,
  position={400,40}, direction=math.pi/2, speed=100, gravity={0,300},
  circleCollider={x=400, y=250, radius=45, particleRadius=2, bounce=0.2, friction=0.03},
  boxCollider={x=240, y=320, width=120, height=60, particleRadius=2, enabled=false},
  capsuleCollider={x1=520, y1=280, x2=650, y2=340, radius=24, particleRadius=2, enabled=false},
  -- An existing collision plane, heightfield, or SDF may also be configured.
}
local accumulator=0
function love.update(dt)
  local x,y=love.mouse.getPosition()
  emitter:setCircleCollider(x,y,45)
  -- Alternatives:
  -- emitter:setBoxCollider(x,y,120,60)
  -- emitter:setCapsuleCollider(x-60,y-20,x+60,y+20,24)
  accumulator=accumulator+math.min(dt,0.1)
  while accumulator>=1/120 do
    emitter:update(1/120)
    accumulator=accumulator-1/120
  end
end
```

Any dynamic collider automatically selects stateful mode. `enabled=false` reserves it without enabling contact. Circles use a center and radius. Boxes use a center with positive width and height and stay axis-aligned. Capsules use two segment endpoints and a positive radius, so moving the endpoints also rotates and resizes the obstacle. `particleRadius` defaults to zero, `bounce` to 0.5, and `friction` to zero.

The shader evaluates the signed distance to each enabled shape, chooses the deepest contact, projects the particle outside, and applies restitution/friction. One circle, one box, and one capsule can coexist with each other and with `collision`. This remains discrete collision, so rapid obstacle motion can skip particles and overlapping obstacles can require subsequent steps to resolve. Obstacle velocity is not transferred to particles.

The three setters change scalar uniforms without reading particle state, uploading spawn records, or rebuilding collision textures. Their first use on an explicitly stateful emitter allocates a small configuration table; subsequent movement is allocation-free. Analytic emitters reject them; construct with a dynamic collider or explicit stateful mode. The native fallback accepts the setters but omits collision.

Coordinates must be in the emitter's simulation space: undo any camera, draw translation, or viewport scaling before passing pointer coordinates. Calling a setter with no arguments disables that shape. Run `love . colliders` for a mouse-driven comparison.

### Custom acceleration

```lua
forces = {
  f.custom {
    name='vortex', stateful=true,
    uniforms={center={400,300}, strength=120},
    code=[[
      vec2 d = p - center;
      return vec2(-d.y,d.x) / max(length(d),20.0) * strength;
    ]],
  },
}
```

Stateful code receives `p`, `velocity`, `seed`, and `age` and returns acceleration. `stateful=true` drives automatic mode selection. These descriptors share the same source-based cache as analytic forces.

## Depth

`depth` gives each particle a z value, positive in front of z = 0 and negative behind it, so an effect can be drawn in two passes around a sprite and pass behind it. It is opt-in: emitters without it allocate nothing extra and use the same shader variants as before.

Formula depth computes z while drawing and adds no memory. The emitter keeps its mode:

```lua
depth = {
  code = 'return sin(seed*6.2831853 + age*0.9) * 130.0;', -- receives seed and age, returns z
  tilt = 0.3,                                              -- screen y per unit of z
}
```

Simulated depth adds z and z velocity to particle state and selects stateful mode. `mode='analytic'` rejects it, and it cannot be combined with `code`:

| Setting | Default | Meaning |
|---|---|---|
| `axis` | emitter x | World x of the vertical axis particles orbit |
| `orbit` | `0` | Orbit rate, radians/sec; scalar or `{min,max}` sampled per particle |
| `gravity` | `0` | Constant z acceleration |
| `emission` | `0` | Random z spread at birth |
| `speed` | `0` | Extra z velocity at birth; scalar or range |
| `tilt` | `0` | Screen y per unit of z |

A particle is born with z velocity `(x - axis) * orbit` and a spring of strength `orbit²` pulls it towards the axis in x/z, so it circles the axis. Damping applies to z. A `respawn` collision restores birth z. Attractors, colliders, flow fields, and self-collision act in x/y only.

Simulated z uses two `rg32f` textures (**16 bytes per slot**), or `rgba32f` (32 bytes) where the driver cannot bind render targets of different formats together. Position and z are written in the same simulation pass.

Draw options, valid only on `depth` emitters:

| Option | Default | Meaning |
|---|---|---|
| `cut` | none | `'behind'` or `'front'`: draw only that half |
| `range` | `1` | z distance counted as fully behind or in front; halves blend within a quarter of it |
| `size` | `0` | Scale sizes by `1 + size*depth`, where depth is `z/range` clamped to ±1 |
| `dim` | `0` | The back loses up to this fraction of its brightness |

```lua
emitter:draw(0, 0, {cut='behind', range=40, size=0.35, dim=0.6})
drawSprite()
emitter:draw(0, 0, {cut='front', range=40, size=0.35, dim=0.6})
```

The behind and front weights are complementary, so the two passes add up to one full draw. Each cut is an extra instanced draw, not an extra simulation pass. The native fallback has no z: a behind pass draws nothing and a front pass draws everything.
