local prefix=(...):gsub('example_support%.waterfall%.scene$','')
local gpu=require(prefix..'gpuparticles')
local Terrain=require(prefix..'example_support.waterfall.terrain')
local Render=require(prefix..'example_support.waterfall.render')
local S={}
S.__index=S
S.step=1/120
function S.new(options)
  options=options or {}
  local self=setmetatable({time=0,accumulator=0,paused=false,showHud=true,wind=true,
    mouse={x=580,y=225,radius=45,inside=false,enabled=true},
    layers={curtain=true,drops=true,mist=true,field=false},emitters={},spray={},mist={}},S)
  self.terrain=Terrain.new()
  local function emitter(config)
    local e=gpu.newEmitter(config);self.emitters[#self.emitters+1]=e;return e
  end
  self.drops=emitter{
    max=24000,rate=6000,lifetime={3.0,3.9},seed=1701,
    position={580,96},emissionArea={distribution='uniform',x=27,y=4},
    direction=math.pi/2,spread=0.08,speed={95,145},gravity={0,480},damping=0.06,
    sizes={1.4,2.8,1.4,0},sizeVariation=0.5,
    colors={{0.55,0.87,0.9,0.28},{0.7,0.94,0.95,0.45},{0.53,0.79,0.84,0}},blendMode='alpha',
    collision={type='sdf',texture=self.terrain.field,size={Terrain.width,Terrain.height},radius=1.5,bounce=0.10,friction=0.025},
    circleCollider={radius=45,particleRadius=1.5,bounce=0.15,friction=0.025,enabled=false},
  }
  assert(self.drops:getMode()=='stateful','waterfall drops require GPU state')
  local impacts={{596,331,220},{751,504,190},{630,690,700}}
  for i,impact in ipairs(impacts) do
    self.spray[i]=emitter{
      max=math.ceil(impact[3]*0.9),rate=impact[3],lifetime={0.35,0.85},seed=80+i,
      position={impact[1],impact[2]},emissionArea={distribution='uniform',x=i==3 and 43 or 17,y=2},
      direction=-math.pi/2,spread=2.5,speed={35,125},gravity={0,300},damping=0.15,
      sizes={1.3,2.2,0},colors={{0.76,0.95,0.94,0.65},{0.65,0.88,0.89,0.22},{0.5,0.8,0.85,0}},blendMode='alpha',
    }
    self.mist[i]=emitter{
      max=i==3 and 1800 or 400,rate=i==3 and 550 or 110,lifetime={1.5,3.0},seed=140+i,
      position={impact[1],impact[2]-7},emissionArea={distribution='uniform',x=i==3 and 48 or 15,y=4},
      direction=-math.pi/2,spread=2.2,speed={6,24},gravity={4,-8},damping=0.6,
      sizes={14,49,87},sizeVariation=0.5,
      colors={{0.56,0.79,0.79,0},{0.61,0.83,0.82,0.027},{0.55,0.74,0.75,0}},blendMode='alpha',
      forces={gpu.forces.turbulence{amplitude={9,3},frequency={1.5,1.2}}},
    }
    assert(self.spray[i]:getMode()=='analytic' and self.mist[i]:getMode()=='analytic','impact decoration must remain analytic')
  end
  if options.render~=false then self.render=Render.new(self.terrain) end
  return self
end
function S:setPointer(x,y,inside)
  local m=self.mouse
  m.x,m.y,m.inside=x or m.x,y or m.y,inside
  if m.enabled and inside then self.drops:setCircleCollider(m.x,m.y,m.radius)
  else self.drops:setCircleCollider() end
end
function S:toggleMouse()
  self.mouse.enabled=not self.mouse.enabled
  self:setPointer(self.mouse.x,self.mouse.y,self.mouse.inside)
end
function S:changeRadius(delta)
  self.mouse.radius=math.max(8,math.min(140,self.mouse.radius+delta))
  self:setPointer(self.mouse.x,self.mouse.y,self.mouse.inside)
end
function S:toggleWind()
  self.wind=not self.wind
  if self.render then
    self.render.backPlants.wind=self.wind and 1 or 0;self.render.frontPlants.wind=self.wind and 1 or 0
  end
end
function S:stepOnce()
  self.time=self.time+self.step
  for _,e in ipairs(self.emitters) do e:update(self.step) end
  if self.render then self.render:updatePlants(self.step,self.time,self.mouse) end
end
function S:update(dt)
  if self.paused then return end
  -- Bound catch-up after a debugger pause; every executed collision step stays 1/120 s.
  self.accumulator=self.accumulator+math.min(dt,0.1)
  while self.accumulator>=self.step do self:stepOnce();self.accumulator=self.accumulator-self.step end
end
function S:warm(seconds)
  for _=1,math.floor(seconds/self.step+0.5) do self:stepOnce() end
end
function S:draw(hud)
  local g=love.graphics
  g.push('all');g.setBlendMode('alpha');g.setShader();g.setColor(1,1,1,1)
  self.render:base(self.time)
  if self.layers.curtain then self.render:water(self.time,self.mouse) end
  if self.layers.drops then self.drops:draw() end
  if self.layers.mist then for _,e in ipairs(self.spray) do e:draw() end end
  self.render:environment()
  if self.layers.mist then for _,e in ipairs(self.mist) do e:draw() end end
  self.render:foreground(self.time)
  if self.layers.field then self.render:debug() end
  self.render:mouseObstacle(self.mouse)
  if hud~=false and self.showHud then self.render:hud(self) end
  g.pop()
end
function S:release()
  if self.released then return end
  for _,e in ipairs(self.emitters) do e:release() end
  if self.render then self.render:release() end
  self.terrain:release();self.released=true
end
return S
