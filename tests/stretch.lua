local gpu=require('gpuparticles')
local M={}

-- Horizontal and vertical extent of everything lit on a canvas.
local function extent(canvas)
  local data=canvas:newImageData()
  local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
  data:mapPixel(function(x,y,r,g,b,a)
    if r+g+b>0.01 then
      minX,maxX=math.min(minX,x),math.max(maxX,x)
      minY,maxY=math.min(minY,y),math.max(maxY,y)
    end
    return r,g,b,a
  end)
  data:release()
  return minX,maxX,minY,maxY
end

local function render(e)
  local target=love.graphics.newCanvas(128,64,{format='rgba32f'})
  love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0)
  e:draw()
  love.graphics.pop()
  local minX,maxX,minY,maxY=extent(target)
  target:release()
  return minX,maxX,minY,maxY
end

-- One particle moving right at 100 px/s, drawn 4 px wide.
local function mover(mode,stretch)
  local e=gpu.newEmitter{max=1,mode=mode,lifetime=10,position={80,32},speed=100,direction=0,
    sizes={4},colors={{1,1,1,1}},stretch=stretch}
  e:emit(1);e:update(0.001)
  return e
end

function M.run()
  for _,mode in ipairs{'analytic','stateful'} do
    local plain=mover(mode,0)
    local plainMin,plainMax=render(plain)
    plain:release()
    local streaked=mover(mode,0.2)
    local streakMin,streakMax=render(streaked)
    streaked:release()
    assert(plainMax-plainMin<8,mode..': an unstretched particle should stay about its size')
    assert(plainMin-streakMin>=16,mode..': velocity stretch must extend 20 px behind a 100 px/s particle, got '..(plainMin-streakMin))
    assert(math.abs(streakMax-plainMax)<=1,mode..': velocity stretch must keep the head on the particle')
  end

  -- A particle stopped by a collision has no speed, so it has no streak.
  local falling={max=1,mode='stateful',lifetime=10,position={40,10},speed=200,direction=math.pi/2,
    sizes={4},colors={{1,1,1,1}},collision={type='plane',y=40},collisionResponse='stop'}
  local plain=gpu.newEmitter(falling)
  plain:emit(1);plain:update(0.3)
  local _,_,plainTop,plainBottom=render(plain)
  plain:release()
  falling.stretch=0.2
  local landed=gpu.newEmitter(falling)
  landed:emit(1);landed:update(0.3)
  local _,_,landedTop,landedBottom=render(landed)
  assert(math.abs(landedTop-plainTop)<=1 and math.abs(landedBottom-plainBottom)<=1,
    'a particle stopped by a collision must not keep a streak')

  landed:setStretch(0.5)
  assert(landed:getStretch()==0.5,'setStretch must be readable back')
  assert(not pcall(landed.setStretch,landed,-1),'a negative stretch must fail')
  assert(not pcall(gpu.newEmitter,{stretch=-0.1}),'a negative stretch must fail at construction')
  landed:release()
  print('Velocity stretch length / head / collision stop / setter PASS')
end
return M
