-- Shared by the interactive comparison and completed-work benchmark.
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
    colors={{0.45,0.83,0.94,0.85},{0.65,0.93,0.99,0.85},{0.5,0.8,0.92,0.35}},
    collision={type='plane',y=472,radius=size/2,bounce=0.15,friction=0.05},
    selfCollision=enabled and {radius=size/2,bounce=0.2,strength=0.8,iterations=iterations} or nil}
end
return P
