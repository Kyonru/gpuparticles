# Emitter API

Create an emitter with `gpu.newEmitter(config)`. Setters and control methods return the emitter for chaining; `update`, `draw`, and `release` do not.

## Methods

| Method | Behavior |
| --- | --- |
| `update(dt)` | Advance the clock and stateful simulation |
| `draw(x=0, y=0)` | Draw all slots in one instanced call on the GPU backend |
| `emit(n)` | Upload an explicit burst into the ring buffer |
| `warm(seconds)` | Offset analytic time or step stateful simulation |
| `setColors(...)` | Upload RGB/RGBA lifetime stops |
| `setSizes(...)` | Upload size stops in pixels |
| `setSizeVariation(v)` | Change deterministic size variation, 0–1 |
| `setSpeed(min, max=min)` | Change initial speed range |
| `setDirection(radians)` | Change initial heading |
| `setSpread(radians)` | Change full angular spread |
| `setLinearAcceleration(x,y,maxX=x,maxY=y)` | Change acceleration range |
| `setRadialAcceleration(min,max=min)` | Change radial acceleration |
| `setTangentialAcceleration(min,max=min)` | Change tangential acceleration |
| `setLinearDamping(min,max=min)` | Change exponential damping |
| `setSpin(min,max=min)` | Change angular speed |
| `setSpinVariation(v)` | Change deterministic spin variation |
| `setRotation(min,max=min)` | Change initial rotation |
| `setRelativeRotation(boolean)` | Follow velocity direction |
| `setEmissionArea(kind,x,y,angle,relative)` | Change spawn distribution |
| `setEmitterLifetime(seconds)` | Limit continuous emission duration |
| `setParticleLifetime(min,max=min)` | Change lifetime range |
| `setPosition(x,y)` | Change the emitter origin |
| `setCircleCollider(x,y,radius)` | Enable or move a stateful circle obstacle |
| `setCircleCollider()` | Disable the circle obstacle |
| `setOffset(x,y)` | Change billboard origin offset |
| `setQuads(...)` | Set lifetime sprite-sheet frames; no arguments clears |
| `setInsertMode(mode)` | Use top, bottom, or random ring placement |
| `setBufferSize(n)` | Reallocate, clear, and change capacity |
| `setEmissionRate(rate)` | Change implicit births per second |
| `start()` / `pause()` / `stop()` | Control new emission |
| `reset()` | Clear and replay from the configured seed |
| `release()` | Release owned resources; safe to repeat |

## Diagnostics

`getMode()`, `getBackend()`, `getFallbackReason()`, `getCount()`, `getPosition()`, `getBufferSize()`, `getEmissionRate()`, `getEmitterLifetime()`, `getParticleLifetime()`, `isActive()`, `isPaused()`, `isStopped()`, `isEmpty()`, and `isFull()` are available.

`getCount()` is `O(max)` and should remain a diagnostic rather than a per-frame counter for large effects.

## Ownership and mutation cost

The emitter owns generated sprites, meshes, canvases, LUTs, and cached shader references. It does not own a supplied texture, flow texture, collision texture, or quads.

Spawn-setting changes rebuild implicit records in `O(max)`. Uniform and curve changes remain much cheaper. Self-collision settings and custom force source are construction-time choices; recreate the emitter to change them.
