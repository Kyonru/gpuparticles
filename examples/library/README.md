# Effect library

A browsable collection of fifteen copyable recipes covering particles, custom shaders, sprite sheets, particle and volume collisions, water, smoke, editable terrain, and thermal reactions.

```sh
love particle-gpu/examples/library
# or
love particle-gpu library
```

Use the arrow keys or mouse wheel to browse. The lower instruction bar explains each recipe’s action: fire and weather cycle isolated layers, explosions burst at the pointer, and volume recipes demonstrate soft water push plus moving circle, box, and capsule solids.

The implementation is split into `example_support/library/particles.lua` and `volumes.lua`. Each recipe constructs ordinary public `gpuparticles` objects and explicitly releases them when switching scenes.
