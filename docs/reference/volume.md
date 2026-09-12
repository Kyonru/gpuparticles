# Volume API

`gpu.newVolumeWorld(options)` returns `world` or `nil, reason`. A successful world reports `getBackend() == 'gpu'`.

## World methods

| Method | Behavior |
| --- | --- |
| `addMaterial(config)` | Add one water or gas material |
| `newSource(config)` | Add a circular or rectangular source |
| `addReaction(config)` | Convert material into gas above a threshold |
| `update(dt)` | Advance the fixed-step clock |
| `warm(seconds)` | Run all complete steps in a duration |
| `draw(x=0,y=0)` | Draw materials in creation order |
| `setWind(x,y)` | Change gas target velocity |
| `setCircleCollider(x,y,radius)` | Enable or move the circle obstacle |
| `setCircleCollider()` | Disable the circle obstacle |
| `setBoxCollider(x,y,width,height)` | Enable or move an axis-aligned box obstacle |
| `setBoxCollider()` | Disable the box obstacle |
| `setCapsuleCollider(x1,y1,x2,y2,radius)` | Enable or move an oriented capsule obstacle |
| `setCapsuleCollider()` | Disable the capsule obstacle |
| `paintTerrain(x,y,radius,solid)` | Add or erase solid terrain |
| `resetTerrain()` | Restore construction terrain |
| `addHeat(x,y,radius,amount,material?)` | Add temperature with radial falloff |
| `addForce(x,y,radius,vx,vy)` | Apply a one-time gas velocity impulse |
| `setRenderStyle(style)` | Select pixel or smooth presentation |
| `pause()` / `start()` | Control simulation |
| `reset()` | Clear fields and clocks while retaining configuration |
| `readback(material)` | Synchronize and return caller-owned `ImageData` |
| `release()` | Release all owned resources |

## Limits

- At most 1,048,576 cells, further limited by maximum texture size.
- At most eight materials, including one water material.
- At most 64 sources and 16 reaction rules per world.
- Custom hook uniform values are finite scalars or vectors of two to four components.
- World size, cell size, and solver structure require reconstruction to change.

Material handles support `set`, `setColor`, `setUniform`, `reset`, and `release`. Source handles support geometry, rate, temperature, start/stop, immediate `emit`, and release. Reaction handles support rate, start/stop, and release.

## Readback channels

The returned material image stores density or mass in red, cumulative admitted source in green, heat content in blue, and cumulative explicitly removed mass in alpha. Multiply grid sums by actual cell area for density-area units.

Readback does not account for gas interpolation error or per-material reaction transfers and forces a GPU pipeline stall.
