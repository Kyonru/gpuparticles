# SDF collision groups

This scene shares one static signed distance field between three emitters. Beige particles collide only with the terrain. Peach particles also collide with the mouse-controlled player circle. Teal particles also collide with an animated enemy box and capsule.

```sh
love particle-gpu/examples/sdf-groups
```

Press **P** to toggle the player collider, **E** to toggle enemy colliders, and **Space** for a burst. The example uses separate emitters as collision layers, which is the recommended way to make moving objects affect selected particle families.
