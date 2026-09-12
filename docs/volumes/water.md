# Create accumulating water

A volume stores material in world cells, so water can spread, collect, and remain after individual particles would expire.

![Pixel-art water collecting around a mouse obstacle](../assets/images/waterfall-volume-mouse.gif)

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
    model = 'water',
    flowSpeed = 1,
    compression = 0.125,
    spread = 0.5,
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
| `transportSteps` | `3` | Water settling passes, 1–4 |
| `flowSpeed` | `1` | Downhill movement rate |
| `spread` | `0.5` | Supported lateral movement |
| `renderStyle` | `'pixel'` | Pixel or smooth display only |

Water is conservative but compressible. Small mounds, delayed settling, and cell-sized surface steps are expected. Pixel rendering treats filled interior rows as one continuous body and applies partial-cell smoothing only to the exposed surface. Use `smooth` when the surface should hide the grid entirely, or a coarse volume for the pooled body with particle emitters for droplets, mist, and spray.

## Block the stream

```lua
function love.update(dt)
  local x, y = love.mouse.getPosition()
  world:setCircleCollider(x, y, 55)
  world:update(dt)
end
```

The obstacle displaces covered water into nearby free cells. A blocked stream accumulates where terrain contains it and drains after the obstacle moves.

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
