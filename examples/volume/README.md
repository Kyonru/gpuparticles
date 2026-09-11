# Material volumes

```sh
love particle-gpu volume
love particle-gpu/examples/volume
love particle-gpu volume --preset=water
love particle-gpu volume --preset=steam --smooth
```

This example uses the public [`gpuparticles.newVolumeWorld` API](../../VOLUME_API.md). **1** selects cellular water, **2** gas smoke with a custom GLSL force, and **3** water converting to steam above a temperature threshold. Sources, collision, and terrain editing all use the public API.

| Control | Action |
|---|---|
| F | Pixel / smooth display; preserve simulation state |
| V | Stop / resume inflow |
| Space | Pause / resume |
| R | Empty simulation and restore terrain |
| C | Toggle mouse circle |
| Wheel | Resize mouse radius |
| Left / Right | Change gas wind |
| Right drag | Paint solid terrain |
| Shift + right drag | Erase terrain |
| Left drag | Stir gas; heat water in the steam preset |
| Esc | Exit |

The 960×480 world uses a 160×80 grid and scales into the viewport. Water is conservative but compressible. Smoke has velocity, pressure, density, and temperature transport. Reactions are thermal conversions, not a chemistry engine. Gas is not mass-conservative and does not exchange pressure forces with water. See the API's units, costs, and limitations before using it for gameplay.

[Pixel smoke](../../previews/volume-smoke-pixel.png) · [Smooth smoke](../../previews/volume-smoke-smooth.png) · [Water](../../previews/volume-water-pixel.png) · [Steam](../../previews/volume-steam-smooth.png)

```sh
love particle-gpu volume-test
python3 particle-gpu/scripts/verify.py --volume-api-only --mutations
```

`--smoke --capture` warms and renders the selected preset, prints its capture path, and quits. Add `--preset=water`, `--preset=steam`, or `--smooth` for other configurations. For a standalone demo, copy its `main.lua` and `conf.lua` plus `gpuparticles/` and `example_support/`; this checkout uses relative symlinks. Applications using only the API need `gpuparticles/` alone.
