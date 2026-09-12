<div class="gp-hero">
  <p class="gp-kicker">LÖVE 11.x · GLSL 3 · no compute shaders</p>
  <h1>Particles that stay on the GPU.</h1>
  <p class="gp-lede">Draw immense analytic effects, add stateful collision when motion needs memory, or simulate persistent water and smoke on a grid. One standalone Lua library chooses the cheapest suitable path.</p>
  <div class="gp-actions">
    <a class="md-button md-button--primary" href="getting-started/first-effect/">Build an effect</a>
    <a class="md-button" href="getting-started/choose-a-system/">Choose a system</a>
  </div>
</div>

## Three ways to make an effect

<div class="gp-paths">
  <div class="gp-card">
    <h3>Analytic particles</h3>
    <p>Compute position from age and a spawn record. There is no per-frame particle state, and the whole emitter draws in one instanced call.</p>
    <a href="particles/configuration/">Configure an emitter →</a>
  </div>
  <div class="gp-card">
    <h3>Stateful particles</h3>
    <p>Ping-pong float textures retain position and velocity. Use this for flow fields, attractors, surfaces, mouse obstacles, and optional particle contact.</p>
    <a href="particles/collision/">Add collision →</a>
  </div>
  <div class="gp-card">
    <h3>Material volumes</h3>
    <p>A grid stores density, heat, and velocity so water can collect, smoke can rise, terrain can change, and materials can react.</p>
    <a href="volumes/get-started/">Create a volume →</a>
  </div>
</div>

## Start with the behavior

| You want | Use | Why |
| --- | --- | --- |
| Sparks, embers, trails, rain, stylized smoke | Analytic emitter | Lowest update cost; deterministic closed-form motion |
| Particles hitting a floor, SDF, heightfield, circle, box, or capsule | Stateful emitter | Each particle retains its current position and velocity |
| Approximate particles pushing one another | Stateful + self-collision | Optional bounded visual contact solver |
| A waterfall that spreads and accumulates in a basin | Water volume | Density persists in cells instead of expiring by lifetime |
| Smoke that rises, advects, cools, and dissipates | Gas volume | Shared velocity and pressure fields model bulk motion |
| Water heated into steam | Water + gas + reaction | Conserved per-cell conversion connects both materials |

`mode = 'auto'` performs this choice for emitters. Analytic effects stay analytic. Collision, attractors, flow fields, stateful custom forces, and self-collision select the stateful backend. Query `emitter:getMode()` and `emitter:getBackend()` whenever the distinction matters.

## What makes it different from LÖVE's ParticleSystem?

The library keeps the familiar emitter vocabulary while adding deterministic seeded replay, curves with more than eight stops, particle counts in the hundreds of thousands, GPU noise, environment collision, and persistent volumes. On unsupported emitter hardware it falls back to `love.graphics.ParticleSystem` behind the same API and reports that through `getBackend()`.

The tradeoffs are explicit. Stateful work costs simulation passes. Self-collision scales quadratically and has a capacity limit. Volume simulation costs scale with grid cells and pressure iterations. Particles are not alpha-sorted, collision is discrete, and volume worlds have no native fallback.

Next: [install the library](getting-started/install.md), [make your first effect](getting-started/first-effect.md), or open [Particle Studio](tools/editor.md).
