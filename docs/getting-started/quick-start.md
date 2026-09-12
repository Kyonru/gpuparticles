# Quick start

Copy the complete `gpuparticles/` directory into your LÖVE project. The module has no runtime dependencies.

```text
my-game/
├── main.lua
└── gpuparticles/
    ├── init.lua
    ├── emitter.lua
    ├── volume/
    └── shaders/
```

## Draw an effect

This complete `main.lua` draws a deterministic ember fountain. `mode='auto'` selects the analytic backend because its motion needs no stored particle state.

```lua
local gpu = require('gpuparticles')
local emitter

function love.load()
  emitter = gpu.newEmitter {
    max = 6000,
    mode = 'auto',
    seed = 42,
    rate = 2000,
    lifetime = {1, 2.5},
    position = {400, 500},
    direction = -math.pi / 2,
    spread = math.pi / 6,
    speed = {80, 220},
    gravity = {0, 300},
    damping = 0.4,
    sizes = {8, 12, 0},
    colors = {
      {1, 0.835, 0.118, 1},
      {1, 0.275, 0.478, 0.7},
      {0.314, 0.012, 0.753, 0},
    },
  }
  emitter:warm(1.5)
  assert(emitter:getMode() == 'analytic')
end

function love.update(dt) emitter:update(dt) end
function love.draw() emitter:draw() end

function love.keypressed(key)
  if key == 'space' then emitter:emit(256) end
end

function love.quit() emitter:release() end
```

Run the directory with LÖVE:

```sh
love my-game
```

## Change one behavior

These changes are independent. Add only what the effect needs.

| Goal | Configuration |
| --- | --- |
| Falling rain | `direction=math.pi/2`, `spread=0.05`, `gravity={0,500}` |
| Circular burst | `rate=0`, `spread=math.pi*2`, then `emit(1000)` |
| Floor collision | `collision={type='plane',y=600,radius=3,bounce=0.3}` |
| Mouse obstacle | Reserve `circleCollider={radius=50}`, then call `setCircleCollider` |
| Pixel sprite | Supply `texture=image` and use nearest filtering |
| Persistent pool | Create a [water volume](../volumes/water.md) |

Collision makes `auto` choose the stateful backend. Check the decision with `getMode()` and hardware fallback with `getBackend()`.

## Coordinate and ownership rules

- Positions, speeds, acceleration, offsets, and sizes use world pixels.
- Angles use radians; `0` points right and `math.pi/2` points down.
- Lifetime and `update` use seconds. Colors use values from `0` to `1`.
- `draw(x,y)` translates rendering; simulation and collision coordinates stay local.
- The emitter owns its generated GPU resources. Your game retains ownership of supplied images, canvases, and quads.

Always release finished systems:

```lua
emitter:release() -- safe to repeat
```

Next: [choose a system](choose-a-system.md), [configure the emitter](../particles/emitter.md), or open [Particle Studio](../tools/editor.md).
