# Create accumulating water

A volume stores material in world cells, so water can spread, collect, and remain after individual particles would expire.

![Pixel-art water responding to a soft mouse push](../assets/images/waterfall-volume-mouse.gif)

## Build a basin

This example creates terrain, water, and a rectangular waterfall source. Negative distance is solid.

```lua
local gpu = require('gpuparticles')
local world, water

local function terrain(x, y)
  local floor = 680 - y
  local leftWall = x - 120
  local rightWall = 1160 - x
  return math.min(floor, leftWall, rightWall)
end

function love.load()
  local reason
  world, reason = gpu.newVolumeWorld {
    width = 1280,
    height = 720,
    cellSize = 8,
    distance = terrain,
    transportSteps = 3,
    renderStyle = 'pixel',
  }
  assert(world, reason)

  water = world:addMaterial {
    name = 'water',
    model = 'liquid',
    behavior = 'water',
    color = {0.40, 0.64, 0.77, 0.9},
  }

  world:newSource {
    material = water,
    shape = 'rectangle',
    position = {640, 40},
    width = 48,
    height = 0,
    rate = 15000,
  }
end

function love.update(dt) world:update(dt) end
function love.draw() world:draw() end
function love.quit() world:release() end
```

Construction returns `nil, reason` when GLSL 3, high-precision pixel shaders, or `rgba32f` canvases are unavailable. Volume worlds have no native fallback.

## Choose resolution

Grid size is `ceil(width/cellSize) × ceil(height/cellSize)`. Start with 8 pixels per cell, then reduce it only when terrain or motion needs more detail.

| Option | Default | Effect |
| --- | --- | --- |
| `cellSize` | `8` | Smaller cells capture finer shapes and cost more |
| `fixedStep` | `1/120` | Simulation step duration |
| `maxSubsteps` | `8` | Maximum catch-up steps per update |
| `transportSteps` | `3` | Conservative mass transfers per step, 1–4 |
| `liquidPressureIterations` | `10` | Inertial-liquid pressure passes |
| `renderStyle` | `'pixel'` | Pixel or smooth display only |

Inertial liquids retain velocity, conservatively carry momentum with their mass, and project velocity pressure. They can coast, wake, rebound, and slosh, but remain a stylized free-surface grid rather than an engineering fluid simulation. Pixel rendering treats filled interior rows as one continuous body and applies partial-cell smoothing only to the exposed surface. Use `smooth` when the surface should hide the grid entirely, or a coarse volume for the pooled body with particle emitters for droplets, mist, and spray.

## Choose a liquid behavior

```lua
local oil = world:addMaterial {name='oil', model='liquid', behavior='oil'}
```

`water` (also named `fluid`) is quick and lightly damped. `oil` has more viscosity, `slime` is slower and cohesive, and `lava` is the heaviest preset. Presets expand into ordinary properties: `viscosity`, `velocityDamping`, `pressure`, `surfaceTension`, `gravity`, `solidFriction`, `maxSpeed`, `volumeRelaxation`, and `sleepSpeed`. Pass any of those fields to override its preset or change them later with `material:set`.

`volumeRelaxation` conservatively packs supported mass toward full cells after inertial transport, so pooled liquid fills a volume instead of remaining a perpetually moving mist of partial cells. `sleepSpeed` zeros small velocities only where liquid is supported by solid or a substantially filled neighboring cell. The water preset uses `volumeRelaxation=12` and `sleepSpeed=2`; use zero for either control to disable that part of settling. Relaxation adds three fragment passes per fixed simulation step when enabled.

The former cellular behavior is deliberately preserved:

```lua
local mud = world:addMaterial {name='mud', model='liquid', behavior='settling'}
-- Existing model='water' configurations select the same solver and remain unchanged.
```

Settling liquids use `flowSpeed`, `compression`, and `spread`. They store mass but no velocity, making them useful for mud, granular pours, and deliberately sluggish effects. Small mounds and delayed settling are expected from that mode.

## Block the stream

```lua
function love.update(dt)
  local x, y = love.mouse.getPosition()
  world:setCircleCollider(x, y, 55)
  world:update(dt)
end
```

Solid colliders displace covered water into nearby free cells. A blocked stream accumulates where terrain contains it and drains after the obstacle moves. Use `setCirclePush` when interaction should move water without creating a solid cavity.

## Add another source

Sources can be circular or rectangular and move independently:

```lua
local tap = world:newSource {
  material = water,
  position = {300,100},
  radius = 14,
  rate = 2000,
}

tap:setPosition(500, 100)
tap:stop()
tap:start()
tap:emit(400) -- immediate amount
```

`rate` uses density × world-pixel² per second. Sources reject solid cells. Continue with [runtime terrain and colliders](runtime-interaction.md) or [smoke and steam](smoke-and-reactions.md).
