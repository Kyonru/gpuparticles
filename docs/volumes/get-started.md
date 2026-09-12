# Create a material volume

A volume world stores material in a 2D grid. It is the right model when density must persist, accumulate, spread, or react after an individual particle lifetime would end.

```lua
local gpu = require('gpuparticles')
local world, smoke, source

function love.load()
  local reason
  world, reason = gpu.newVolumeWorld {
    width = 1280,
    height = 800,
    cellSize = 8,
    renderStyle = 'pixel',
  }

  if not world then
    print('volume unavailable: ' .. reason)
    return
  end

  smoke = world:addMaterial {
    name = 'smoke',
    model = 'gas',
    buoyancy = 40,
    dissipation = 0.15,
    cooling = 0.3,
    color = {0.6, 0.6, 0.65, 0.7},
  }

  source = world:newSource {
    material = smoke,
    position = {400, 500},
    radius = 20,
    rate = 800,
    temperature = 2,
  }

  world:setWind(30, 0)
end

function love.update(dt)
  if world then world:update(dt) end
end

function love.draw()
  if world then world:draw() end
end

function love.quit()
  if world then world:release() end
end
```

## Resolution and cost

Grid dimensions are `ceil(width / cellSize)` by `ceil(height / cellSize)`. Smaller cells capture finer geometry but increase the cost of every full-grid pass. Start at 8 pixels per cell for a 1280 × 800 effect, then measure the real scene.

| Option | Default | Purpose |
| --- | --- | --- |
| `fixedStep` | `1/120` | Simulation time per step |
| `maxSubsteps` | `8` | Catch-up work permitted per update |
| `transportSteps` | `3` | Water relaxation passes, 1–4 |
| `pressureIterations` | `24` | Gas pressure iterations, 1–80 |
| `velocityDamping` | `0.1` | Gas velocity damping per second |
| `renderStyle` | `'pixel'` | Pixel or smooth presentation |

Pixel and smooth styles change appearance only. Simulation canvases always use nearest filtering.

## Add sources

Worlds support circular and rectangular sources:

```lua
local source = world:newSource {
  material = smoke,
  shape = 'rectangle',
  position = {300, 650},
  width = 80,
  height = 8,
  rate = 1200,
  temperature = 3,
}
```

`rate` is density × world-pixel² per second. Sources reject solid cells. They can start, stop, move, resize, emit an immediate amount, and release independently.

Volume worlds require GLSL 3, high-precision pixel shaders, and `rgba32f` canvases. They return `nil, reason` instead of falling back to native particles.
