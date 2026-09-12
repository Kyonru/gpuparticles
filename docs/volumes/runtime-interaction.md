# Runtime interaction

Volume controls mutate GPU fields without reading every cell into Lua. Coordinates are local to the world, independent of `draw(x, y)` translation.

## Moving obstacles

```lua
world:setCircleCollider(x, y, radius)
world:setCircleCollider() -- disable
world:setBoxCollider(x, y, width, height)
world:setBoxCollider() -- disable
world:setCapsuleCollider(x1, y1, x2, y2, radius)
world:setCapsuleCollider() -- disable
```

Water is displaced from covered cells and gas is excluded. Boxes stay axis-aligned; capsule endpoints can move and rotate freely. The three shapes can be enabled together. Transform screen or mouse coordinates into world coordinates before calling them.

## Soft water push

```lua
world:setCirclePush(x, y, radius, strength)
world:setCirclePush() -- disable
```

This biases water flux away from the circle with a smooth falloff. The circle never becomes solid, and every outgoing amount is gathered by a neighboring cell, so the operation conserves mass and does not cut a collider-shaped hole. A strong sustained push can still form a natural low-density depression. Use a solid collider when an object must block water or form a dam.

For directional interaction, apply a one-time flux impulse in world pixels per second:

```lua
world:addWaterForce(x, y, radius, forceX, forceY)
```

Call it while dragging to stir water from pointer velocity, or use it for pumps, wind, explosions, and character movement. The current liquid model stores density rather than velocity, so the impulse biases the next transport step and does not retain inertia after that step. It conserves mass and never creates solid space.

## Paint terrain

```lua
world:paintTerrain(x, y, 24, true)  -- add solid
world:paintTerrain(x, y, 16, false) -- erase solid
world:resetTerrain()                -- restore construction field
```

Painted solids evacuate water along the distance gradient and absorb gas already occupying the edited cells. Concave or sealed water pockets can retain hidden material until opened.

## Inject heat and motion

```lua
world:addHeat(x, y, 40, 2.5, smoke)
world:addForce(x, y, 60, 120, -40)
```

Heat changes temperature with radial falloff. Omitting the material affects all materials. `addForce` is a one-time gas velocity impulse in pixels per second and requires at least one gas material.

## Control and inspect

| Method | Operation |
| --- | --- |
| `pause()` / `start()` | Stop or resume simulation |
| `warm(seconds)` | Run complete fixed steps without catch-up limits |
| `reset()` | Clear fields and clocks; retain sources, controls, and terrain edits |
| `setWind(x, y)` | Change the target gas velocity |
| `setRenderStyle(style)` | Switch pixel or smooth display without clearing state |
| `readback(material)` | Force a GPU sync and return caller-owned `ImageData` |

Reserve `readback` for tests and tools. It stalls the graphics pipeline and should not drive per-frame game logic. Keep gameplay collision state on the CPU when the game must query it every frame.
