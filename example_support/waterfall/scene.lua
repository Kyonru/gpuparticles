local prefix=(...):gsub('example_support%.waterfall%.scene$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local Terrain=require(prefix..'example_support.waterfall.terrain')
local Render=require(prefix..'example_support.waterfall.render')
local Fluid=require(prefix..'example_support.waterfall.fluid')
local S={}
S.__index=S
S.step=1/120
local function droplets(terrain,selfCollision)
  return gpu.newEmitter{
    max=24000,rate=6000,lifetime={3.0,3.9},seed=1701,warmStep=S.step,
    position={580,96},emissionArea={distribution='uniform',x=27,y=4},
    direction=math.pi/2,spread=0.08,speed={95,145},gravity={0,480},damping=0.06,
    sizes={1.4,2.8,1.4,0},sizeVariation=0.5,
    colors={{palette.blue[1],palette.blue[2],palette.blue[3],0.32},
      {palette.teal[1],palette.teal[2],palette.teal[3],0.52},
      {palette.beige[1],palette.beige[2],palette.beige[3],0}},blendMode='alpha',
    collision={type='sdf',texture=terrain.field,size={Terrain.width,Terrain.height},radius=1.5,bounce=0.10,friction=0.025},
    circleCollider={radius=45,particleRadius=1.5,bounce=0.15,friction=0.025,enabled=false},
    selfCollision=selfCollision and {radius=1.5,bounce=0.1,strength=0.8,iterations=1} or nil,
  }
end
function S.new(options)
  options=options or {}
  local self=setmetatable({time=0,accumulator=0,paused=false,showHud=true,wind=true,inflow=true,selfCollision=not not options.selfCollision,
    mouse={x=580,y=225,radius=45,inside=false,enabled=true},
    layers={curtain=true,drops=true,mist=true,field=false},emitters={},spray={},mist={}},S)
  self.terrain=Terrain.new()
  local function emitter(config)
    local e=gpu.newEmitter(config);self.emitters[#self.emitters+1]=e;return e
  end
  self.drops=droplets(self.terrain,self.selfCollision);self.emitters[1]=self.drops
  assert(self.drops:getMode()=='stateful','waterfall drops require GPU state')
  local impacts={{596,331,220},{751,504,190},{630,690,700}}
  for i,impact in ipairs(impacts) do
    self.spray[i]=emitter{
      max=math.ceil(impact[3]*0.9),rate=impact[3],lifetime={0.35,0.85},seed=80+i,
      position={impact[1],impact[2]},emissionArea={distribution='uniform',x=i==3 and 43 or 17,y=2},
      direction=-math.pi/2,spread=2.5,speed={35,125},gravity={0,300},damping=0.15,
      sizes={1.3,2.2,0},colors={{palette.beige[1],palette.beige[2],palette.beige[3],0.68},
        {palette.teal[1],palette.teal[2],palette.teal[3],0.25},
        {palette.blue[1],palette.blue[2],palette.blue[3],0}},blendMode='alpha',
    }
    self.mist[i]=emitter{
      max=i==3 and 1800 or 400,rate=i==3 and 550 or 110,lifetime={1.5,3.0},seed=140+i,
      position={impact[1],impact[2]-7},emissionArea={distribution='uniform',x=i==3 and 48 or 15,y=4},
      direction=-math.pi/2,spread=2.2,speed={6,24},gravity={4,-8},damping=0.6,
      sizes={14,49,87},sizeVariation=0.5,
      colors={{palette.blue[1],palette.blue[2],palette.blue[3],0},
        {palette.teal[1],palette.teal[2],palette.teal[3],0.045},
        {palette.beige[1],palette.beige[2],palette.beige[3],0}},blendMode='alpha',
      forces={gpu.forces.turbulence{amplitude={9,3},frequency={1.5,1.2}}},
    }
    assert(self.spray[i]:getMode()=='analytic' and self.mist[i]:getMode()=='analytic','impact decoration must remain analytic')
  end
  if options.render~=false then self.render=Render.new(self.terrain) end
  if options.waterVolume then self:setWaterVolume(true) end
  return self
end
function S:setWaterVolume(enabled)
  if enabled and not self.fluid then
    local reason
    self.fluid,reason=Fluid.new{transportSteps=3,distance=function(x,y) return self.terrain:rockDistance(x,y) end}
    self.volumeUnavailable=reason
    if self.fluid then self.fluid.inflow=self.inflow
    elseif not self.volumeWarned then print(reason);self.volumeWarned=true end
  elseif not enabled and self.fluid then self.fluid:release();self.fluid=nil end
  return self.fluid~=nil,self.volumeUnavailable
end
function S:toggleInflow()
  self.inflow=not self.inflow
  if self.fluid then self.fluid.inflow=self.inflow end
end
function S:setSelfCollision(enabled)
  enabled=not not enabled
  if self.selfCollision==enabled then return end
  local previous=self.drops
  self.drops=droplets(self.terrain,enabled);self.emitters[1]=self.drops;self.selfCollision=enabled
  self:setPointer(self.mouse.x,self.mouse.y,self.mouse.inside)
  -- Restart just the droplet stream; retain the scene clock, decoration, and controls.
  self.drops:warm(math.min(self.time,4))
  previous:release()
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
  if self.fluid then self.fluid:update(self.step,self.mouse)
  else for _,e in ipairs(self.emitters) do e:update(self.step) end end
  if self.render then self.render:updatePlants(self.step,self.time,self.mouse) end
end
function S:update(dt)
  if self.paused then return end
  -- Bound catch-up at the full droplet count; slow simulated time rather than accumulating work.
  self.accumulator=math.min(self.accumulator+dt,2*self.step)
  while self.accumulator>=self.step do self:stepOnce();self.accumulator=self.accumulator-self.step end
end
function S:warm(seconds)
  for _=1,math.floor(seconds/self.step+0.5) do self:stepOnce() end
end
function S:draw(hud)
  local g=love.graphics
  g.push('all');g.setBlendMode('alpha');g.setShader();g.setColor(1,1,1,1)
  self.render:base(self.time,self.fluid~=nil)
  if self.fluid then
    if self.layers.curtain then self.fluid:draw() end
  else
    if self.layers.curtain then self.render:water(self.time,self.mouse) end
    if self.layers.drops then self.drops:draw() end
    if self.layers.mist then for _,e in ipairs(self.spray) do e:draw() end end
  end
  self.render:environment()
  if not self.fluid and self.layers.mist then for _,e in ipairs(self.mist) do e:draw() end end
  self.render:foreground(self.time)
  if self.layers.field then
    if self.fluid then self.fluid:draw(true) else self.render:debug() end
  end
  self.render:mouseObstacle(self.mouse)
  if hud~=false and self.showHud then self.render:hud(self) end
  g.pop()
end
function S:release()
  if self.released then return end
  for _,e in ipairs(self.emitters) do e:release() end
  if self.render then self.render:release() end
  if self.fluid then self.fluid:release() end
  self.terrain:release();self.released=true
end
return S
