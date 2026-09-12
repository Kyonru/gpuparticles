# Contributing

Thank you for improving gpuparticles. Keep changes compatible with LÖVE 11.x and preserve the standalone `gpuparticles/` module boundary.

## Before opening a pull request

Run the checks relevant to the change:

```sh
love . test
love . fallback
love . examples-test
python3 scripts/verify.py --portable-only
luacheck . --globals love jit --no-max-line-length
zensical build --clean --strict
```

GPU behavior must be verified numerically where possible. Tests should unbind canvases before readback and should fail when the invariant they cover is deliberately broken. Record hardware, renderer, resolution, particle size, and whether a measurement reports submission or completed work when contributing benchmarks.

## Pull requests

- Explain the behavior change and the effect that exercises it.
- Add or update task documentation when the public API changes.
- Assert the expected analytic or stateful mode in new examples.
- Avoid per-frame readback, particle-sized Lua loops, and shader recompilation.
- Release every resource owned by a new object.

The issue tracker is appropriate for focused bugs and proposals. Large API additions should describe their behavior, limits, fallback story, and verification plan before implementation.
