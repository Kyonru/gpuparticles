# Accumulating water

Water volumes preserve density across cells. A stream can hit terrain, spread, fill a basin, and form a temporary pool when a moving obstacle blocks its path.

![Pixel-art water collecting around a mouse obstacle](../assets/images/waterfall-volume-mouse.gif)

## Create the basin

Provide a signed-distance callback when the world is constructed. It runs once per cell; negative distance is solid.

```lua
local function terrainDistance(x, y)
  local floor = 680 - y
  local leftWall = x - 120
  local rightWall = 1160 - x
  return math.min(floor, leftWall, rightWall)
end

local world, reason = gpu.newVolumeWorld {
  width = 1280,
  height = 720,
  cellSize = 6,
  distance = terrainDistance,
  transportSteps = 3,
  renderStyle = 'pixel',
}
assert(world, reason)

local water = world:addMaterial {
  name = 'water',
  model = 'water',
  flowSpeed = 1,
  compression = 0.125,
  spread = 0.5,
  color = {0.18, 0.68, 0.95, 0.9},
}

local fall = world:newSource {
  material = water,
  shape = 'rectangle',
  position = {640, 40},
  width = 48,
  height = 0,
  rate = 15000,
}
```

The sides and bottom contain water; the top permits accounted overflow. Water is conservative but compressible, so small mounds, delayed settling, and grid-edge artifacts are expected.

## Form a temporary pool with the mouse

```lua
function love.update(dt)
  local x, y = love.mouse.getPosition()
  world:setCircleCollider(x, y, 55)
  world:update(dt)
end
```

The circle displaces covered water. Blocking the fall redirects incoming volume into nearby free cells; removing the circle lets the pool drain according to terrain and solver resolution.

## Tune its look and motion

- Lower `cellSize` for smaller features and a more expensive simulation.
- Raise `transportSteps` toward 4 for more settling work per step.
- Lower `flowSpeed` for slow or viscous stylization.
- Adjust `spread` for supported lateral movement.
- Use `renderStyle='pixel'` for hard cells or `'smooth'` for interpolated display.

This solver is designed for responsive visual material, not incompressible engineering fluid dynamics. Use a coarser volume for the pooled body and ordinary particle emitters for mist, droplets, and bright spray.
