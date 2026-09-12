# Moving colliders

This example compares the three uniform-driven obstacle shapes: circle, axis-aligned box, and arbitrarily oriented capsule.

```sh
love examples/colliders
```

Press **1**, **2**, or **3** to choose a shape and move the mouse to reposition it. Capsules rotate to demonstrate non-axis-aligned segments. Each setter updates uniforms without rebuilding particle buffers, shaders, canvases, or collision textures.

![Particles colliding with a moving capsule](../../previews/colliders.gif)
