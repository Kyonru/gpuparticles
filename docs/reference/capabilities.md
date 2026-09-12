# Capabilities and limits

Call `gpu.getCapabilities()` after graphics initialization. It returns the raw LÖVE support and limit tables plus derived backend flags.

```lua
local caps = gpu.getCapabilities()

print(caps.version[1], caps.version[2], caps.version[3])
print(caps.renderer[1], caps.renderer[2])
print('analytic', caps.analytic)
print('stateful', caps.stateful)
print('volume', caps.volume)
```

## Derived requirements

| Backend | Required capabilities |
| --- | --- |
| Analytic particles | Instancing, `drawInstanced`, GLSL 3 |
| Stateful particles | Analytic requirements, high-precision pixel shaders, `rgba32f`, at least four simultaneous canvases |
| Material volumes | GLSL 3, high-precision pixel shaders, `rgba32f` |

LÖVE 11.x has no compute shaders. Every GPU simulation here uses fragment shader passes over float canvases, and rendering uses instanced quads with vertex-stage texture fetch where state is required.

## Degradation

An emitter whose selected GPU backend is unavailable constructs a native `love.graphics.ParticleSystem`, logs the fallback once, and reports:

```lua
if emitter:getBackend() == 'native' then
  print(emitter:getFallbackReason())
end
```

Native fallback preserves common emitter controls but omits GPU-only forces and collision, resamples curves to eight stops, and cannot reproduce seeded trajectories exactly.

Volume construction returns `nil, reason`; there is no native substitute for persistent density, pressure, terrain editing, or reactions.

## Hard limits

| Feature | Limit |
| --- | ---: |
| Emitter capacity | 2²⁴ slots, subject to memory |
| Self-collision emitter capacity | 24,000 slots |
| Editor self-collision capacity | 2,048 slots |
| Sprite-sheet frames | 256 |
| Volume cells | 1,048,576, subject to texture size |
| Materials per volume | 8, with one water material |
| Sources per volume | 64 |
| Reactions per volume | 16 |

GPU particle state uses 32-bit floats. Keep world coordinates near the effect and recreate very long-running systems before elapsed-time precision becomes visible.

## Rendering limits

Particles retain fixed ring-slot drawing order. There is no per-particle alpha or depth sorting. Additive blending is the safest default for overlapping effects; ordinary alpha blending can expose order changes after ring-buffer wrap.
