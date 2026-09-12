# Build your first effect

This emitter creates a deterministic ember fountain. It uses the analytic backend because every movement term can be evaluated from particle age.

```lua
local gpu = require('gpuparticles')
local emitter

function love.load()
  emitter = gpu.newEmitter {
    max = 50000,
    mode = 'auto',
    seed = 42,
    rate = 2000,
    lifetime = {1.0, 2.5},
    position = {400, 500},
    direction = -math.pi / 2,
    spread = math.pi / 6,
    speed = {80, 220},
    gravity = {0, 300},
    damping = 0.4,
    sizes = {8, 12, 0},
    colors = {
      {1, 0.8, 0.3, 1},
      {1, 0.2, 0, 0.6},
      {0.2, 0.2, 0.2, 0},
    },
    spin = {-2, 2},
    blendMode = 'add',
  }

  assert(emitter:getMode() == 'analytic')
  emitter:warm(1.5)
end

function love.update(dt)
  emitter:update(dt)
end

function love.draw()
  emitter:draw()
  love.graphics.print(emitter:getBackend(), 12, 12)
end

function love.keypressed(key)
  if key == 'space' then emitter:emit(256) end
end

function love.quit()
  emitter:release()
end
```

## Understand the units

- Position, speed, acceleration, offsets, and size use world pixels.
- Angles use radians. Direction `0` points right; `math.pi / 2` points down in LÖVE coordinates.
- Lifetime and update values use seconds.
- Colors use the LÖVE 11 range from `0` to `1`.
- `sizes` are billboard widths in pixels, not texture scale factors.

## Move the whole effect

`position` is the simulation origin. `draw(x, y)` adds a render translation and does not alter collision coordinates:

```lua
emitter:setPosition(400, 500)
emitter:draw(cameraX, cameraY)
```

For moving trails, emit explicit bursts at successive locations or select stateful mode. Analytic implicit particles follow their emitter when `setPosition` changes.

## Add a texture

Pass a LÖVE `Image` at construction. If omitted, the emitter creates a soft white disc.

```lua
local image = love.graphics.newImage('spark.png')
image:setFilter('nearest', 'nearest')

emitter = gpu.newEmitter {
  texture = image,
  max = 12000,
  rate = 4000,
  lifetime = 1.2,
  sizes = {12, 5, 0},
}
```

The game owns `image` and must release it separately.
