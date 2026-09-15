# Roadmap

This document tracks capabilities that would materially expand gpuparticles. Items are ordered by player-facing value, implementation risk, and how many effects they unlock. Completed work must include public API documentation, numeric GPU tests, an example, fallback behavior, and explicit resource ownership.

## Highest-value particle features

### 1. Collision responses — in progress

Particles should choose what happens on contact:

- [x] bounce
- [x] slide
- [x] stop
- [ ] persistently stick or attach to a surface
- [x] disappear until the slot recycles
- [x] respawn from the particle's spawn record
- [ ] change color or size on contact

GPU-side visual responses are practical. Arbitrary Lua callbacks for every contact would require a synchronous GPU readback and are outside the real-time path.

Acceptance criteria: one uniform-only response setting per emitter; numeric tests for every response; no readback or per-particle CPU work; deterministic recycling; editor and example coverage. Per-collider responses and persistent event metadata can follow after the first emitter-wide implementation.

### 2. Multiple moving colliders

The API currently supports one circle, box, and capsule per emitter. Collider arrays would allow characters, doors, moving platforms, and multiple interactive objects.

Acceptance criteria: bounded documented capacity, collision groups or masks, batched GPU upload, stable overlap selection, and performance measurements across collider counts.

### 3. Collider velocity

Moving objects currently displace particles without transferring momentum. Velocity transfer would let a paddle throw water droplets or a character push smoke and leaves.

Acceptance criteria: linear velocity for all dynamic shapes, endpoint-derived angular motion for capsules, configurable influence, and fixed-step numeric tests.

### 4. Velocity-stretched particles

Stretch sprites along velocity for rain, sparks, projectiles, and waterfall droplets. This is a low-cost vertex-shader feature with broad visual value.

Acceptance criteria: length scale, maximum stretch, minimum-speed threshold, correct relative rotation, and sprite-sheet compatibility.

### 5. Trails and ribbons

Connected trails would support lasers, lightning, projectile streaks, smoke trails, and flowing magic. This requires stored history or generated ribbon geometry and is a separate rendering path.

### 6. Better sprite animation

- Frame ranges
- Playback speed
- Looping and one-shot animation
- Random starting frames
- Non-square atlas frames
- Random sprite selection

### 7. Depth-aware rendering

Implemented: optional per-particle z, from depth code or simulated orbits, with behind/front draw passes around a sprite ([depth guide](docs/particles/depth.md)). Depth testing against scene depth, scene-depth collision, and several occluders at different depths remain open. Full transparent sorting remains a separate, expensive problem.

## Volume simulation opportunities

- Inertial water, oil, slime, and lava are implemented alongside the original settling-liquid behavior
- Sand, granular materials, and angle-of-repose controls
- Fire that consumes fuel and produces smoke
- Freezing, melting, and evaporation
- Water pushing smoke or steam
- Bubbles and foam
- Liquid coloration and material mixing
- Drains, pumps, and directional emitters
- Save and restore volume state
- Particle-to-volume coupling

Particle-to-volume coupling has the highest priority in this group. Droplets could add water when they enter a pool; the pool could emit splash, foam, and mist particles. That would connect the waterfall's decorative emitters to its persistent material simulation.

## Particle Studio

- Custom GLSL authoring with compiler errors
- SDF and terrain painting
- Keyframed parameter curves
- Texture importing
- Better sprite-sheet slicing
- Performance estimates while authoring
- Exported effect previews

## Compatibility and operations

- Test Windows, Linux, integrated GPUs, and older mobile-class hardware
- Add numeric GPU tests for every collision shape and volume reaction
- Publish versioned releases and migration notes
- Recover cleanly when canvas allocation fails
- Replace quadratic self-collision with a bounded spatial approximation
- Add an optional LÖVE 12 compute backend while retaining the LÖVE 11 renderer
- Report estimated GPU memory and runtime diagnostics

## Implementation order

1. Finish collision responses and expose them in Particle Studio.
2. Add velocity stretching.
3. Design collider arrays and collision masks together.
4. Add collider velocity transfer.
5. Prototype particle-to-volume coupling.
6. Extend sprite animation and authoring tools.
7. Explore trails, depth, spatial self-collision, and a LÖVE 12 backend behind measured prototypes.
