# Configure an emitter

`gpu.newEmitter(config)` creates an active emitter after graphics initialization. The API mirrors the naming of `love.graphics.ParticleSystem` where the concepts match.

## Core settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `max` | `1000` | Ring-buffer capacity |
| `mode` | `'auto'` | Automatic, analytic, or stateful selection |
| `rate` | `0` | Continuous births per second |
| `lifetime` | `{1,1}` | Particle life as a scalar or range |
| `position` | `{0,0}` | Simulation origin |
| `speed` | `{0,0}` | Initial speed scalar or range |
| `direction`, `spread` | `0`, `0` | Heading and full angular spread |
| `gravity` | `{0,0}` | Constant acceleration |
| `damping` | `0` | Exponential linear damping |
| `sizes` | `{8,0}` | Width stops over normalized life |
| `colors` | white to transparent | RGB or RGBA stops over life |
| `blendMode` | `'add'` | LÖVE blend mode used for drawing |
| `seed` | `1` | Private deterministic random seed |

Use `rate * maximumLifetime` as a minimum capacity when continuously emitted particles should not be overwritten while alive.

## Spawn area

```lua
emissionArea = {
  distribution = 'uniform',
  x = 80,
  y = 12,
  angle = 0,
  directionRelative = false,
}
```

Supported distributions are `none`, `uniform`, `normal`, `ellipse`, `borderellipse`, and `borderrectangle`. Rectangle values are half-extents. For `normal`, they are standard deviations.

## Curves and variation

Color and size stops are evenly spaced across particle life and may contain more than LÖVE's native eight-stop limit:

```lua
emitter:setSizes(2, 8, 12, 8, 0)
emitter:setColors(
  {0.8, 0.95, 1, 0},
  {0.3, 0.7, 1, 0.9},
  {0.1, 0.25, 0.6, 0}
)
emitter:setSizeVariation(0.35)
```

GPU color, size, acceleration, and damping changes affect living particles. Setters that change spawn records rebuild and upload the implicit record buffer, an `O(max)` operation. Make those changes during loading or editor interactions rather than every frame.

## Rotation

```lua
emitter:setRotation(-0.2, 0.2)
emitter:setSpin(-3, 3)
emitter:setSpinVariation(0.5)
emitter:setRelativeRotation(true)
emitter:setOffset(8, 8)
```

Relative rotation follows ballistic or simulated velocity. Analytic noise displacement is not included in its orientation.

## Diagnostics

Use `getMode()`, `getBackend()`, and `getFallbackReason()` to explain which implementation is active. `getCount()` checks CPU spawn metadata and is `O(max)`; avoid calling it every frame on a very large emitter.
