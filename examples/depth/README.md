# Depth and occlusion

This example gives particles a depth so they can pass behind a solid shape, drawn in two passes around it: the half behind, then the shape, then the half in front.

```sh
love examples/depth
```

- **Obelisk (left):** stateful sparks with simulated z. A spring round the obelisk's vertical axis makes each spark orbit it while an attractor lifts them. The z pair costs 16 bytes per particle slot and exists only because the emitter asks for `depth`.
- **Planet (right):** an analytic ring whose z is a formula (`depth.code`) using the same angle as its custom force. It holds no particle state at all.

Press **C** to toggle the cut (without it the particles draw over the shapes), **V** to toggle the size and brightness cues, and **T** to tint the behind half red with the shapes drawn as outlines.

![Sparks orbiting behind an obelisk and a ring passing behind a planet](../../docs/assets/images/depth-occlusion.png)
