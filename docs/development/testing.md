# Testing and verification

The test suite renders into float canvases, unbinds them, reads exact values, and checks simulation invariants numerically. It also verifies examples, fallback behavior, editor export portability, and resource cleanup.

```sh
love particle-gpu test
love particle-gpu fallback
love particle-gpu examples-test
love particle-gpu volume-test
love particle-gpu editor-test
```

Run the complete Python orchestrator from the repository root:

```sh
python3 particle-gpu/scripts/verify.py
python3 particle-gpu/scripts/verify.py --portable-only
python3 particle-gpu/scripts/verify.py --editor-only --mutations
python3 particle-gpu/scripts/verify.py --volume-api-only --mutations
```

The Python runner is a development tool, not a library dependency. Portability checks copy only `gpuparticles/` into a temporary LÖVE project before exercising particle and volume APIs.

## Mutation verification

`--mutations` temporarily introduces known defects, requires the relevant test to fail, restores the original bytes in a `finally` block, and reruns the fixed suite. Mutations cover state blend mode, texel behavior, collision projection, mode selection, shader caching, editor input, water conservation, gas buoyancy, pressure projection, and thermal conversion.

Do not edit mutation targets while that runner is active.

## Critical GPU invariants

- Simulation passes use `replace, premultiplied` blending.
- Every state texture uses nearest filtering.
- State is sampled at texel centers.
- A canvas is unbound before test readback.
- `#pragma language glsl3` is the first shader line.
- Tests assert the expected analytic or stateful mode.
- Normal runtime paths never read particle state back to the CPU.

## Static checks

```sh
luacheck particle-gpu --globals love jit --no-max-line-length
zensical build --clean --strict
```

The docs build runs in strict mode so broken navigation and internal links fail validation.
