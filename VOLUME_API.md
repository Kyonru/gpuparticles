# GPU volume API

`gpuparticles.newVolumeWorld` creates a reusable simulation independent of particle emitters. Copy `gpuparticles/` into any LÖVE 11.x project; no waterfall or editor files are required. Construct after graphics initialization.

```lua
local gpu = require('gpuparticles')
local world, smoke, source

function love.load()
  local reason
  world, reason = gpu.newVolumeWorld {
    width = 1280, height = 800, cellSize = 8,
    renderStyle = 'pixel', -- or 'smooth'; independent of simulation
  }
  if not world then print(reason); return end
  smoke = world:addMaterial {
    name = 'smoke', model = 'gas',
    buoyancy = 40, dissipation = 0.15, cooling = 0.3,
    color = {0.6, 0.6, 0.65, 0.7},
  }
  source = world:newSource {
    material = smoke, position = {400, 500}, radius = 20,
    rate = 800, temperature = 2,
  }
  world:setWind(30, 0)
end
function love.update(dt)
  if not world then return end
  world:setCircleCollider(love.mouse.getX(), love.mouse.getY(), 50)
  -- Or: world:setBoxCollider(x,y,width,height)
  -- Or: world:setCapsuleCollider(x1,y1,x2,y2,radius)
  world:update(dt)
end
function love.draw() if world then world:draw() end end
function love.quit() if world then world:release() end end
```

Run `love particle-gpu volume` to compare inertial water, settling material, oil, slime, smoke, and hot-water-to-steam examples, or press **V** in the main example picker. [Controls and previews](examples/volume/README.md).

## World configuration

| Field | Default | Meaning |
|---|---|---|
| `width`, `height` | 1280, 800 | Positive simulation extent in world pixels |
| `cellSize` | 8 | Nominal cell size, minimum 0.25 px |
| `fixedStep` | 1/120 | Simulated seconds per step; 1/1000–1/30 |
| `maxSubsteps` | 8 | Maximum steps per `update`, integer 1–64 |
| `transportSteps` | 3 | Settling relaxations or inertial mass transfers per step, integer 1–4 |
| `pressureIterations` | 24 | Gas pressure iterations per step, integer 1–80 |
| `liquidPressureIterations` | 10 | Inertial-liquid pressure iterations per step, integer 1–80 |
| `velocityDamping` | 0.1 | Gas velocity damping, 0–20 per second |
| `wind` | `{0,0}` | Target gas velocity in px/s |
| `renderStyle` | `'pixel'` | `'pixel'` or `'smooth'` |
| `distance` | none | `function(x,y)` returning signed terrain distance in world pixels; negative is solid |

Grid dimensions are `ceil(width/cellSize)` × `ceil(height/cellSize)`; actual cell dimensions fit the world exactly. Maximum capacity is **1048576 cells**, further restricted by device texture-size limits. Recreate the world to change dimensions or solver structure; this starts a new simulation. `setRenderStyle` preserves all state.

`distance` runs once per cell at construction and must return finite numbers. The world owns the resulting field and supports GPU terrain painting. All simulation inputs use local world coordinates. Draw translation does not change them; transform mouse input yourself.

Requires GLSL 3, high-precision pixel shaders, and `rgba32f` canvases; no instancing or compute shaders. `gpu.getCapabilities().volume` reports support. Construction returns `nil, reason` for missing capabilities or resource/shader initialization failure, releasing partial resources. Native ParticleSystem cannot reproduce volume physics, so there is no native substitution. Invalid configuration raises a descriptive error.

## Materials

`world:addMaterial(config)` returns a material. A world supports **8 materials**, with **one liquid material** and remaining slots for gases. Names must be unique. All gases share velocity/pressure and contribute buoyancy and custom forces. Materials share terrain, circle/box/capsule collision, and reaction rules. Gas can occupy liquid cells; gas/liquid pressure coupling and bubbles are not simulated.

| Field | Models | Default | Meaning |
|---|---|---|---|
| `name` | all | required | Unique material name |
| `model` | all | `'water'` | `'water'` (legacy settling), `'liquid'` (selectable behavior), or `'gas'` |
| `behavior` | liquid | `'water'` | `'water'`/`'fluid'`, `'oil'`, `'slime'`, `'lava'`, or `'settling'` |
| `color` | all | teal liquid / gray smoke | RGBA components, each 0–1 |
| `dissipation` | all | liquid 0, gas 0.15 | Density decay, 0–20 per second; retention is `exp(-rate*t)` |
| `cooling` | all | 0.3 | Temperature decay toward zero, 0–20 per second |
| `buoyancy` | gas | 40 | −1000–1000; upward acceleration is `buoyancy * temperature * min(density,1)` px/s² |
| `flowSpeed` | settling | 1 | Transport multiplier, 0–1; zero stops flow, retaining injection and reactions |
| `compression` | settling | 0.125 | Artificial per-pair pressure compression, 0.001–1 |
| `spread` | settling | 0.5 | Supported-water lateral transport coefficient, 0–0.5 |
| `viscosity` | inertial liquid | preset | Neighbor-velocity mixing rate, 0–20 per second |
| `velocityDamping` | inertial liquid | preset | Bulk velocity damping, 0–20 per second |
| `pressure` | inertial liquid | preset | Pressure-projection strength, 0–2 |
| `surfaceTension` | inertial liquid | preset | Attraction toward occupied neighbors, 0–100 |
| `gravity` | inertial liquid | preset | Downward acceleration in px/s², −5000–5000 |
| `solidFriction` | inertial liquid | preset | Tangential damping at solid neighbors, 0–20 per second |
| `maxSpeed` | inertial liquid | preset | Velocity safety limit in px/s, 1–10000 |
| `volumeRelaxation` | inertial liquid | preset | Conservative rate that fills supported cells toward density 1, 0–100 per second |
| `sleepSpeed` | inertial liquid | preset | Supported velocities below this px/s threshold settle to rest, 0–100 |
| `force` | gas | none | Custom GLSL acceleration hook |
| `render` | all | none | Custom GLSL shading hook |

`material:set {buoyancy=80, cooling=0.1}` changes applicable numeric parameters. `setColor(rgba)` changes rendering. Neither rebuilds resources. Unsupported fields/models and parameters for the wrong model are rejected. Hook code and uniform types are construction settings; values can change with `setUniform` below.

`material:reset()` clears its fields but retains shared gas velocity. `material:release()` releases its fields and sources, removes reactions referring to it, and frees shared gas canvases when the last gas material is released. `world:release()` releases every remaining owned object and cached shader reference. Releases are idempotent; mutating released handles is rejected.

## Sources and units

`world:newSource {material=..., position={x,y}, radius=..., rate=..., temperature=...}` creates an active source. Maximum **64 sources per world**, with multiple sources per material.

- Positions and sizes use world pixels. Position defaults to `{0,0}`. `shape='circle'` is the default, with radius 0 meaning a point cell. Positive-radius circles select cells by their centers; very small circles can miss all centers.
- `shape='rectangle', width=..., height=...` selects a grid-aligned rectangular region. Zero height makes a source row; dimensions default to 0. Bounds snap to containing cells.
- `rate` is **density × world px² / second**, default 0. For water, density 1 is one nominal uncompressed full cell. Adding 64 units to an 8×8 cell adds one density unit, subject to admission limits.
- `temperature` uses a nonphysical heat scale, 0–1000, default water 0 / gas 1. Stored heat content is density × temperature; these are not Kelvin or physical energy units.

Injection is uniform across selected in-bounds cells. Solid locations reject injection. Liquid sources admit up to density 1 at their locations; submerged/full locations admit less. Gas injection caps density at 1000. Actual admitted rate can therefore be below the requested rate, and is recorded for verification.

## Liquid behaviors

Existing `model='water'` configurations continue to select the original settling solver with the same shaders, resources, defaults, and results. The explicit equivalent is `model='liquid', behavior='settling'`. It stores density and temporary directional flux, but no persistent velocity.

`model='liquid'` defaults to `behavior='water'`, an inertial solver. It stores velocity between steps, applies gravity and interactions to that velocity, projects its divergence, then transports mass and momentum conservatively. A final conservative occupancy relaxation fills supported cells toward density 1, while a supported-cell sleep threshold removes tiny residual velocities. These make a poured liquid settle into a filled volume without discarding momentum during active motion. Set `volumeRelaxation=0` and `sleepSpeed=0` for the pure inertial behavior. `fluid` is an alias of `water`; `oil`, `slime`, and `lava` supply progressively more viscous and damped defaults. Every preset value can be overridden at construction or through `material:set`:

```lua
local water = world:addMaterial {
  name = 'water', model = 'liquid', behavior = 'water',
  viscosity = 0.04,
  surfaceTension = 14,
  volumeRelaxation = 100,
  sleepSpeed = 2,
}
water:set {velocityDamping = 0.2, solidFriction = 0.1}
```

One world still supports one liquid. Use separate worlds when two independently drawn liquids need different behaviors. Interacting or mixing liquids require a multiphase solver and are not provided.

Source methods: `setPosition(x,y)`, `setRadius(r)` (circles), `setSize(width,height)` (rectangles), `setRate(rate)` / `setEmissionRate(rate)`, `setTemperature(value)`, `start()`, `stop()`, `isActive()`, `emit(amount)`, and `release()`. Controls return the source. Stopping/removing a source retains its emitted material. `emit` injects immediately, even while continuous emission or world simulation is stopped.

Moving/resizing circular sources counts coverage in Lua over their bounding region. This runs only when geometry changes, not on ordinary simulation updates; moving very large sources can cost CPU time.

## Runtime world controls

| Method | Behavior |
|---|---|
| `update(dt)` | Advance the fixed clock; finite, nonnegative dt |
| `warm(seconds)` | Run full fixed steps without catch-up limits, even when paused; fractional steps round down |
| `draw(x=0,y=0)` | Draw materials in creation order |
| `setWind(x,y)` | Change gas wind target; no effect on cellular water |
| `setCircleCollider(x,y,radius)` | Move/resize the circular obstacle |
| `setCircleCollider()` | Disable the circle |
| `setCirclePush(x, y, radius, strength)` | Bias settling flux or accelerate inertial liquid radially without creating a solid mask; requires a liquid |
| `setCirclePush()` | Disable the soft water push |
| `setBoxCollider(x,y,width,height)` | Move/resize an axis-aligned box obstacle |
| `setBoxCollider()` | Disable the box |
| `setCapsuleCollider(x1,y1,x2,y2,radius)` | Move/resize/rotate a capsule obstacle |
| `setCapsuleCollider()` | Disable the capsule |
| `paintTerrain(x,y,radius,solid)` | Add solid terrain when true, erase when false |
| `resetTerrain()` | Restore original terrain |
| `addHeat(x,y,radius,amount,material?)` | Temperature delta with radial falloff, clamped to 0–1000; omit material to affect all |
| `addForce(x,y,radius,vx,vy)` | One-time gas **velocity impulse** in px/s with radial falloff; requires gas |
| `addWaterForce(x,y,radius,forceX,forceY)` | One-time conservative flux impulse for settling liquid or persistent velocity impulse for inertial liquid, with radial falloff |
| `setRenderStyle('pixel' or 'smooth')` | Change only appearance |
| `pause()` / `start()` | Pause/resume simulation |
| `reset()` | Clear material, velocity, pressure, and clocks; retain sources, terrain edits, controls, and pause state |
| `readback(material)` | Explicit GPU sync; returns caller-owned ImageData for tests/tools |
| `getBackend()` | `'gpu'` for a successfully constructed world |
| `release()` | Release all owned resources |

Controls return the world; `update`, `draw`, and `release` do not. Simulation and drawing restore caller graphics state. Excess time beyond `maxSubsteps * fixedStep` is dropped and recorded in `world.droppedTime`. Gas backtraces limit displacement to 0.75 cell per tick and check intervening solids; excessive velocities saturate transport speed. Smooth display leaves all state canvases nearest-filtered and does not improve physical resolution.

## Custom GLSL

```lua
local smoke = world:addMaterial {
  name = 'curling-smoke', model = 'gas',
  force = {
    code = 'return vec2(sin(position.y * 0.04 + time) * strength, 0.0);',
    uniforms = {strength = 30},
  },
  render = {
    code = 'return vec4(mix(color.rgb, hotColor, clamp(temperature, 0.0, 1.0)), color.a);',
    uniforms = {hotColor = {1, 0.4, 0.1}},
  },
}
smoke:setUniform('force', 'strength', 60)
smoke:setUniform('render', 'hotColor', {0.4, 0.8, 1})
```

Force code receives `position` (world px), `velocity` (px/s), `density`, `temperature`, and `time` (seconds). Return a `vec2` acceleration in px/s². It executes in gas-occupied, non-solid cells and adds to buoyancy; components are bounded to ±10000 before integration. Render code receives computed `color` (RGBA), `density`, `temperature`, `position`, and `time`; return RGBA. Geometry masking still applies after shading. Supply a function body without a pragma or `effect` declaration.

Uniforms accept finite numbers or 2–4 component vectors with fixed types. Names must be identifiers, cannot start with `u_`, and cannot shadow hook arguments. They are namespaced before compilation. Variants are cached and reference-counted by shader kind, code, and uniform types, independently of values. Each pass supplies its material's current values, including across worlds sharing a shader. Changing values never recompiles. GLSL compile errors release partial material resources and raise an error; custom code remains responsible for finite results and meaningful mathematics.

## Thermal conversion rules

```lua
local water = world:addMaterial {name='water', model='liquid', behavior='water', cooling=0.05}
local steam = world:addMaterial {name='steam', model='gas', buoyancy=90}
local boil = world:addReaction {
  from = water, to = steam,
  temperatureAbove = 1, rate = 0.7,
}
world:addHeat(400, 600, 50, 2, water)
```

Rules convert material into gas when temperature is **at least** the threshold. The per-step fraction is `1-exp(-rate*dt)`; rate is 0–100 per second and threshold 0–1000. Converted density and proportional heat move between materials in the same cell. This pass conserves combined mass and heat; later gas advection/dissipation can change totals. Up to **16 rules**, processed in insertion order, may exist. Handles support `setRate`, `start`, `stop`, and `release`.

Targets must be gas; both materials must belong to the world and differ. This is a configurable conversion mechanism, not arbitrary chemistry. Fuel, combustion, sand, freezing, latent heat, steam expansion, and pressure-driven phase changes are not implemented. Gas can overlap water so converted vapor can rise from it; liquid receives no equal/opposite gas forces.

## Numerical and performance limits

Settling liquid retains the conservative but compressible waterfall model: bounded outgoing fluxes, neighbor gathers, and source admission divided across relaxations. Inertial liquid adds persistent momentum and a finite pressure projection while retaining conservative mass transfers. Sides/bottom contain liquid; the top allows accounted overflow. Circle intrusion displaces mass; painted terrain evacuates it along the distance gradient. Sealed/concave pockets may retain hidden material until opened. Both modes remain stylized grid models rather than engineering fluid dynamics.

Gas uses shared velocity advection, buoyancy/custom forces, a pressure solve/projection, and density/heat transport with exponential dissipation/cooling. It uses a collocated grid and finite pressure iterations: divergence decreases but need not reach zero. Semi-Lagrangian sampling can lose or gain density; moving solids absorb covered gas and boundaries introduce diffusion. Gas does not have water's mass-conservation guarantee. Gas world edges are closed.

Cost scales with cells, materials, sources, reactions, and solver iterations. Settling liquid takes two grid draws per relaxation. Inertial liquid adds a velocity pair, divergence, and a pressure pair plus its pressure passes; momentum transport reuses the velocity pair. Gas adds a shared pressure solve and per-material transport/rendering. Sources add bounded-region draws; active reactions add three passes. Regular updates do not visit cells in Lua or read GPU state back. Resources are allocated at construction/material changes and explicitly released. Volume worlds are separate from particle count/self-collision and are not yet authored in Particle Studio.

Readback channels: **R density/mass, G cumulative admitted source, B heat content, A cumulative explicitly removed mass** (water overflow/decay; gas absorption/decay). Multiply grid sums by actual cell area for density-area units. G/A do not account for gas interpolation errors or per-material reaction transfers.

## Verification

```sh
love particle-gpu volume-test
love particle-gpu waterfall-test
python3 particle-gpu/scripts/verify.py --volume-api-only --mutations
```

Numeric tests cover source units, controls, settling compatibility, inertial momentum and conservation, liquid presets, smoke motion/cooling/decay, thin-wall/circle exclusion, pressure projection, terrain editing, heat/reactions, custom shader uniforms/cache lifetime, rendering styles, and resource cleanup. The runner copies only the library into a temporary project, captures all six presets in both styles, and checks tests against deliberate reversible defects.

The gas model follows the texture-pass approach in [GPU Gems: Fast Fluid Dynamics Simulation on the GPU](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-38-fast-fluid-dynamics-simulation-gpu), with bounded backtraces and a finite pressure solve.
