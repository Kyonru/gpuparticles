# Changelog

## v0.2.0 — 2026-10-16

This release expands gpuparticles from particle emitters into a broader GPU effects toolkit, while keeping existing v0.1.0 emitter configurations compatible.

### Highlights

- Added reusable volume worlds for settling and inertial liquids, smoke, steam, heat, reactions, terrain, sources, runtime colliders, and custom shader hooks.
- Added particle self-collision, configurable collision responses, velocity stretching and carry, and formula-driven or simulated particle depth.
- Added source exclusion zones plus velocity-coupled and non-displacing volume colliders.
- Expanded Particle Studio with embedded PNG and sprite-sheet textures, pixel-art rendering, appearance effects, color editing, self-collision authoring, and portable exports.
- Added the effect library, volume, depth, SDF collision groups, custom shader, and expanded waterfall examples.
- Added numeric GPU coverage, standalone export checks, mutation checks, documentation, and automated release packaging.

### Migration from v0.1.0

No migration is required. Existing emitter configurations and Particle Studio projects retain their previous defaults. New particle and volume features are opt-in, and added collider parameters have backward-compatible defaults.

