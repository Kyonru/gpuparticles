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
    colors={{palette.waterLight[1],palette.waterLight[2],palette.waterLight[3],0.38},
      {palette.water[1],palette.water[2],palette.water[3],0.58},
      {palette.waterDeep[1],palette.waterDeep[2],palette.waterDeep[3],0}},blendMode='alpha',
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
  -- Each impact carries its surface angle and mist span. Decorative particles begin
  -- on the contact plane instead of forming free-floating clouds around it.
  local impacts={
    {x=596,y=327,rate=180,angle=0.22,span=23,mistSpan=31},
    {x=751,y=495,rate=160,angle=-0.40,span=25,mistSpan=38},
    {x=630,y=687,rate=430,angle=0,span=52,mistSpan=96},
  }
  for i,impact in ipairs(impacts) do
    self.spray[i]=emitter{
      max=math.ceil(impact.rate*0.9),rate=impact.rate,lifetime={0.35,0.78},seed=80+i,
      position={impact.x,impact.y},emissionArea={distribution='uniform',x=impact.span,y=1,angle=impact.angle},
      direction=-math.pi/2,spread=2.15,speed={30,105},gravity={0,280},damping=0.18,
      sizes={1.2,2.0,0},colors={{palette.foam[1],palette.foam[2],palette.foam[3],0.72},
        {palette.waterLight[1],palette.waterLight[2],palette.waterLight[3],0.34},
        {palette.water[1],palette.water[2],palette.water[3],0}},blendMode='alpha',
    }
    self.mist[i]=emitter{
      max=i==3 and 900 or 280,rate=i==3 and 320 or 90,lifetime={0.8,1.7},seed=140+i,
      position={impact.x,impact.y-3},
      emissionArea={distribution='uniform',x=impact.mistSpan,y=1.5,angle=impact.angle},
      direction=-math.pi/2,spread=math.pi,speed={2,10},gravity={0,7},damping=1.1,
      sizes={10,25,38},sizeVariation=0.35,
      colors={{palette.waterDeep[1],palette.waterDeep[2],palette.waterDeep[3],0},
        {palette.water[1],palette.water[2],palette.water[3],0.14},
        {palette.waterLight[1],palette.waterLight[2],palette.waterLight[3],0}},blendMode='alpha',
      forces={gpu.forces.turbulence{amplitude={3.5,0.8},frequency={1.25,0.9}}},
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
