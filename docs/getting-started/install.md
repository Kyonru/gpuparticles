# Install

gpuparticles is a standalone Lua module. It has no runtime dependency beyond LÖVE 11.x.

## Copy the module

Copy the complete `gpuparticles/` directory into your game:

```text
my-game/
├── main.lua
└── gpuparticles/
    ├── init.lua
    ├── emitter.lua
    ├── volume/
    └── shaders/
```

Do not copy only `init.lua`: both particle and volume backends load sibling Lua files and GLSL files at runtime.

Require it after LÖVE has initialized graphics:

```lua
local gpu = require('gpuparticles')

function love.load()
  local capabilities = gpu.getCapabilities()
  print('analytic', capabilities.analytic)
  print('stateful', capabilities.stateful)
  print('volume', capabilities.volume)
end
```

Particle emitters automatically fall back to LÖVE's native `ParticleSystem` when the required GPU features are unavailable. Volume worlds return `nil, reason` because the native system has no equivalent.

## Run the included projects

From the directory that contains `particle-gpu`:

```sh
love particle-gpu                  # effect browser
love particle-gpu editor           # Particle Studio
love particle-gpu comparison       # native and GPU comparison
love particle-gpu waterfall        # collision and persistent pool
love particle-gpu volume           # water, smoke, and steam
love particle-gpu test             # numeric GPU tests
love particle-gpu bench            # local benchmark
```

On macOS, replace `love` with `/Applications/love.app/Contents/MacOS/love` when it is not on `PATH`.

## Build these docs

Zensical is a documentation-only dependency:

```sh
cd particle-gpu
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
zensical serve
```

The preview opens at `http://127.0.0.1:8000`. Build the static site with:

```sh
zensical build --clean --strict
```

The generated `site/` directory can be hosted by any static file server.

## Release resources

Every emitter and volume world owns GPU resources. Release it when the game no longer needs it:

```lua
function love.quit()
  if emitter then emitter:release() end
  if world then world:release() end
end
```

Releasing is idempotent. Textures, canvases, and quads supplied by your game remain your responsibility.
