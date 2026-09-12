-- Shared by the interactive comparison and completed-work benchmark.
local prefix=(...):gsub('example_support%.comparison%.particle_preset$','')
local palette=require(prefix..'example_support.palette')
local P={capacities={256,512,1024,2048,5000,10000}}
function P.texture()
  local data=love.image.newImageData(16,16)
  data:mapPixel(function(x,y)
    local t=math.max(0,1-math.sqrt((x+0.5-8)^2+(y+0.5-8)^2)/8)
    return 1,1,1,t*t*(3-2*t)
  end)
  local image=love.graphics.newImage(data);data:release();return image
end
function P.config(capacity,size,iterations,enabled,texture)
  return {max=capacity,texture=texture,mode='stateful',rate=capacity/4,lifetime=4,seed=2026,
    position={256,24},emissionArea={distribution='uniform',x=70,y=0},direction=math.pi/2,spread=0.15,
    speed={80,100},gravity={0,220},damping=0.1,sizes={size},blendMode='alpha',
    colors={{palette.purple[1],palette.purple[2],palette.purple[3],0.85},
      {palette.red[1],palette.red[2],palette.red[3],0.9},
      {palette.pink[1],palette.pink[2],palette.pink[3],0.35}},
    collision={type='plane',y=472,radius=size/2,bounce=0.15,friction=0.05},
    selfCollision=enabled and {radius=size/2,bounce=0.2,strength=0.8,iterations=iterations} or nil}
end
return P
