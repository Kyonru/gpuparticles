# Textures and pixel art

Every particle is a textured square billboard. Supply an `Image` or let the library generate a soft disc.

![Pixel-art particles in Particle Studio](../assets/images/editor-pixel.png)

## Use an image

```lua
local splash = love.graphics.newImage('splash.png')
splash:setFilter('nearest', 'nearest')

local emitter = gpu.newEmitter {
  texture = splash,
  sizes = {16, 16, 8, 0},
  colors = {{0.7, 0.9, 1, 1}, {0.3, 0.6, 1, 0}},
}
```

White or grayscale sprites are easy to tint with the lifetime color curve. Use premultiplied artwork only when your surrounding blend pipeline expects it.

## Animate a sprite sheet

Create LÖVE `Quad` objects and pass them in frame order. The emitter advances across them once over particle life:

```lua
local image = love.graphics.newImage('flame-sheet.png')
image:setFilter('nearest', 'nearest')
local frames = {}
local frameWidth, frameHeight = 16, 16

for i = 0, 3 do
  frames[#frames + 1] = love.graphics.newQuad(
    i * frameWidth, 0,
    frameWidth, frameHeight,
    image:getDimensions()
  )
end

local emitter = gpu.newEmitter {texture=image, quads=frames}
```

Up to 256 frames are supported. The billboard remains square, so square source frames preserve their proportions best. Add padding around linear-filtered atlas frames to prevent neighboring-frame bleed.

## Keep a stable pixel grid

Nearest filtering keeps sprite texels crisp. For rotating or subpixel-moving sprites to share one consistent screen grid, draw the complete effect into a low-resolution canvas, then enlarge the canvas by an integer scale with nearest filtering.

Particle Studio exposes this as **World pixels / cell** with values 1, 2, 4, 8, and 16. Its built-in Pixel sparks, Pixel flame, Pixel smoke, and Pixel splash sheets automatically choose their frame grid and nearest filtering.

## Appearance shader effects

Particle Studio can apply pixel-grid quantization, dissolve, outlines, palette levels, tint, distortion, and glow to the composited layer. These add an appearance canvas pass but do not change the emitter's analytic or stateful simulation mode.

![Dissolve, outline, palette, distortion, and glow controls](../assets/images/editor-shaders.png)
