# Contributing

Thank you for improving gpuparticles. Keep changes compatible with LÖVE 11.x and preserve the standalone `gpuparticles/` module boundary.

## Development setup

Clone the repository and run projects from its root. LÖVE may be installed as `/Applications/love.app/Contents/MacOS/love` on macOS.

```sh
love .                         # effect browser
love probe                     # hardware capability probe
love . editor                  # Particle Studio
love . comparison              # native/GPU comparison
love . waterfall               # collision and volume demonstration
love . volume                  # material-volume examples
love . bench                   # performance benchmark
```

Named force examples under `examples/` can also run directly, such as `love examples/curl`. These directories use relative symlinks for shared code. Use the root launcher when a checkout does not preserve symlinks.

## Documentation

The Zensical site lives in `docs/`, with navigation and theme configuration in `zensical.toml`. Create an isolated environment and install the pinned documentation dependency:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
zensical serve
```

The preview is available at `http://127.0.0.1:8000`. Build the static site with:

```sh
zensical build --clean --strict
```

Generated files are written to the ignored `site/` directory. The `Documentation site` GitHub workflow builds that directory and deploys it to GitHub Pages on documentation changes. Keep task guides in `docs/`; update `API.md` or `VOLUME_API.md` alongside public API changes.

Animated examples are captured directly from LÖVE and encoded with `ffmpeg`. Regenerate the documented GIFs after changing their visuals or motion:

```sh
python3 scripts/capture_gifs.py
# Regenerate one preview while iterating:
python3 scripts/capture_gifs.py --only sdf-collision-groups
```

The script writes 24-frame, 12 FPS loops to both `previews/` and `docs/assets/images/`, then removes its temporary PNG frames.

## Before opening a pull request

Run the checks relevant to the change:

```sh
love . test
love . fallback
love . examples-test
python3 scripts/verify.py --portable-only
python3 scripts/verify.py --editor-only --mutations
python3 scripts/verify.py --volume-api-only --mutations
luacheck . --globals love jit --no-max-line-length
zensical build --clean --strict
```

GPU behavior must be verified numerically where possible. Tests should unbind canvases before readback and should fail when the invariant they cover is deliberately broken. Record hardware, renderer, resolution, particle size, and whether a measurement reports submission or completed work when contributing benchmarks.

The Python runner executes LÖVE projects and portability checks; it is not a runtime dependency. `--mutations` introduces reversible defects, requires the relevant tests to catch them, restores the original source in `finally`, and reruns the fixed test. Do not edit mutation targets while it runs.

For a complete local verification:

```sh
python3 scripts/verify.py
```

## Pull requests

- Explain the behavior change and the effect that exercises it.
- Add or update task documentation when the public API changes.
- Assert the expected analytic or stateful mode in new examples.
- Avoid per-frame readback, particle-sized Lua loops, and shader recompilation.
- Release every resource owned by a new object.

The issue tracker is appropriate for focused bugs and proposals. Large API additions should describe their behavior, limits, fallback story, and verification plan before implementation.
