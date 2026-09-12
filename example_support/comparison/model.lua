local prefix=(...):gsub('example_support%.comparison%.model$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local ParticlePreset=require(prefix..'example_support.comparison.particle_preset')
local C={}
C.__index=C
C.capacities={1000,10000,25000,50000,100000,250000}
C.particleCapacities=ParticlePreset.capacities
C.sizes={2,3,6,12,24}
local colors={{palette.purple[1],palette.purple[2],palette.purple[3],0.58},
  {palette.red[1],palette.red[2],palette.red[3],0.62},
  {palette.pink[1],palette.pink[2],palette.pink[3],0}}
function C.new(options)
  options=options or {}
  local self=setmetatable({capacityIndex=options.capacityIndex or 3,sizeIndex=options.selfCollision and 4 or 2,gpuMode=options.selfCollision and 'stateful' or 'analytic',view='both',
    particleCollision=options.selfCollision or false,particleCapacityIndex=options.particleCapacityIndex or 3,iterations=options.iterations or 1,
    mouseCollision=false,pointer={x=256,y=210,radius=48,inside=false},
    elapsed=0,frames=0,settling=0.5,fps=0,liveNative=0,paused=false,results={},benchmark=nil,quiet=options.quiet,
    cost={native={update=0,draw=0},gpu={update=0,draw=0}},samples={native={update=0,draw=0},gpu={update=0,draw=0}}},C)
  self.texture=ParticlePreset.texture()
  self.targets={native=love.graphics.newCanvas(512,512,{dpiscale=1,msaa=0}),gpu=love.graphics.newCanvas(512,512,{dpiscale=1,msaa=0})}
  self:rebuild()
  return self
end
function C:active(name) return self.view=='both' or self.view==name end
function C:clearMeasurement()
  self.elapsed,self.frames,self.fps,self.settling=0,0,0,0.5
  for _,name in ipairs{'native','gpu'} do
    self.samples[name].update,self.samples[name].draw=0,0
    self.cost[name].update,self.cost[name].draw=0,0
  end
end
function C:rebuild()
  if self.native then self.native:release();self.gpu:release() end
  local capacity=self.particleCollision and ParticlePreset.capacities[self.particleCapacityIndex] or self.capacities[self.capacityIndex]
  local size=self.sizes[self.sizeIndex]
  self.capacity,self.size=capacity,size
  self.lifetime=self.particleCollision and 4 or 2
  if self.particleCollision then
    local baseline=ParticlePreset.config(capacity,size,self.iterations,false,self.texture)
    local colliding=ParticlePreset.config(capacity,size,self.iterations,true,self.texture)
    if self.mouseCollision then
      baseline.circleCollider={radius=self.pointer.radius,particleRadius=size/2,bounce=0.18,friction=0.03,enabled=false}
      colliding.circleCollider=baseline.circleCollider
    end
    self.native=gpu.newEmitter(baseline);self.gpu=gpu.newEmitter(colliding)
  else
  local native=love.graphics.newParticleSystem(self.texture,capacity)
  native:setEmissionRate(capacity/2);native:setParticleLifetime(2)
  native:setPosition(256,24);native:setEmissionArea('uniform',222,0)
  native:setDirection(math.pi/2);native:setSpread(0);native:setSpeed(100)
  native:setLinearAcceleration(0,100);native:setLinearDamping(0)
  native:setSizes(size/16);native:setColors(unpack(colors));native:setInsertMode('top')
  self.native=native
  self.gpu=gpu.newEmitter{
    max=capacity,texture=self.texture,mode=self.gpuMode,rate=capacity/2,lifetime=2,seed=2026,
    position={256,24},emissionArea={distribution='uniform',x=222,y=0},
    direction=math.pi/2,spread=0,speed=100,gravity={0,100},damping=0,
    sizes={size},colors=colors,blendMode='alpha',
    circleCollider=self.mouseCollision and {radius=self.pointer.radius,particleRadius=size/2,bounce=0.18,friction=0.03,enabled=false} or nil,
  }
  end
  -- Equal simulated pre-roll; native is stepped because its trajectories are iterative.
  local warmSteps=self.lifetime*60+1
  for _=1,warmSteps do self.native:update(1/60) end
  self.gpu:warm(warmSteps/60)
  self:setPointer(self.pointer.x,self.pointer.y,self.pointer.inside)
  self.liveNative=self.native:getCount()
  self.backend=self.gpu:getBackend()
  self.liveGPU=self.backend=='gpu' and capacity or self.gpu:getCount()
  self.results={};self.benchmark=nil;self.benchmarkDone=false;self:clearMeasurement()
end
function C:setView(view)
  assert(view=='both' or view=='native' or view=='gpu')
  self.view=view;self:clearMeasurement()
end
function C:changeCapacity(delta)
  local key=self.particleCollision and 'particleCapacityIndex' or 'capacityIndex'
  local capacities=self.particleCollision and ParticlePreset.capacities or self.capacities
  local index=math.max(1,math.min(#capacities,self[key]+delta))
  if self[key]==index then return end
  self[key]=index
  self:rebuild()
end
function C:changeSize(delta)
  self.sizeIndex=math.max(1,math.min(#self.sizes,self.sizeIndex+delta));self:rebuild()
end
function C:toggleMode()
  if self.particleCollision then self:setParticleCollision(false) end
  self.mouseCollision=false;self.previousMode=nil
  self.gpuMode=self.gpuMode=='analytic' and 'stateful' or 'analytic';self:rebuild()
end
function C:setParticleCollision(enabled)
  if self.particleCollision==enabled then return end
  if enabled then
    self.previousComparison={mode=self.gpuMode,size=self.sizeIndex,mouse=self.mouseCollision,previousMode=self.previousMode}
    self.gpuMode,self.sizeIndex,self.mouseCollision,self.previousMode='stateful',4,false,nil
  else
    local old=self.previousComparison or {mode='analytic',size=2,mouse=false}
    self.gpuMode,self.sizeIndex,self.mouseCollision,self.previousMode=old.mode,old.size,old.mouse,old.previousMode
    self.previousComparison=nil
  end
  self.particleCollision=enabled;self:rebuild()
end
function C:changeIterations()
  if self.particleCollision then self.iterations=self.iterations%4+1;self:rebuild() end
end
function C:setMouseCollision(enabled)
  if self.mouseCollision==enabled then return end
  if enabled then self.previousMode=self.gpuMode;self.gpuMode='stateful'
  else self.gpuMode=self.previousMode or 'analytic';self.previousMode=nil end
  self.mouseCollision=enabled;self:rebuild()
end
function C:setPointer(x,y,inside)
  local p=self.pointer
  p.x,p.y,p.inside=x or p.x,y or p.y,inside
  if self.mouseCollision then
    if inside then self.gpu:setCircleCollider(p.x,p.y,p.radius) else self.gpu:setCircleCollider() end
    if self.particleCollision then
      if inside then self.native:setCircleCollider(p.x,p.y,p.radius) else self.native:setCircleCollider() end
    end
  end
end
function C:changeRadius(delta)
  if not self.mouseCollision then return end
  self.pointer.radius=math.max(8,math.min(120,self.pointer.radius+delta))
  self:setPointer(self.pointer.x,self.pointer.y,self.pointer.inside)
end
function C:update(dt,simulationDt)
  self.frameDt=dt
  if self.paused then return end
  -- Collision demonstration uses smaller steps; matched benchmark mode retains one update per frame.
  local step=self.particleCollision and self.benchmark and 1/120 or math.min(simulationDt or dt,self.particleCollision and 1/60 or 0.1)
  local steps=(self.mouseCollision or self.particleCollision) and math.max(1,math.ceil(step*120)) or 1
  if self:active('native') then
    local start=love.timer.getTime()
    for _=1,steps do self.native:update(step/steps) end
    self.samples.native.update=self.samples.native.update+(love.timer.getTime()-start)
  end
  if self:active('gpu') then
    local start=love.timer.getTime()
    for _=1,steps do self.gpu:update(step/steps) end
    self.samples.gpu.update=self.samples.gpu.update+(love.timer.getTime()-start)
  end
end
function C:renderTargets()
  local g=love.graphics
  g.push('all');g.origin();g.setShader();g.setScissor();g.setColor(1,1,1,1);g.setBlendMode('alpha')
  for _,name in ipairs{'native','gpu'} do
    if self:active(name) then
      g.setCanvas(self.targets[name]);g.clear(palette.deep)
      local start=love.timer.getTime()
      if name=='native' then
        if self.particleCollision then self.native:draw() else g.draw(self.native) end
      else self.gpu:draw() end
      self.samples[name].draw=self.samples[name].draw+(love.timer.getTime()-start)
      if self.particleCollision then
        g.setColor(palette.teal);g.setLineWidth(1);g.line(0,472,512,472);g.setColor(1,1,1,1)
      end
    end
  end
  g.pop()
end
function C:finishFrame()
  local dt=self.frameDt or 0
  if self.benchmark then
    local bench=self.benchmark
    bench.elapsed=bench.elapsed+dt
    if bench.elapsed>0.75 then bench.seconds=bench.seconds+dt;bench.frames=bench.frames+1 end
    if bench.elapsed>=3 then
      self.results[self.view]=bench.frames/math.max(bench.seconds,0.000001)
      if not self.quiet then
        local label=self.particleCollision and ('GPU particle collision '..(self.view=='native' and 'OFF' or 'ON')) or self.view
        print(('Comparison %s alone: %.1f FPS, %d capacity, %d px, mode %s, backend %s, %d iterations'):format(label,self.results[self.view],self.capacity,self.size,self.gpuMode,self.backend,self.iterations))
      end
      if self.view=='native' then
        self:setView('gpu');self.benchmark={elapsed=0,frames=0,seconds=0}
      else
        self.benchmark=nil;self:setView('both');self.benchmarkDone=true
      end
    end
  end
  self.settling=math.max(0,self.settling-dt)
  self.elapsed=self.elapsed+dt;self.frames=self.frames+1
  if self.elapsed>=0.5 then
    self.fps=self.frames/self.elapsed
    for _,name in ipairs{'native','gpu'} do
      self.cost[name].update=self.samples[name].update*1000/self.frames
      self.cost[name].draw=self.samples[name].draw*1000/self.frames
      self.samples[name].update,self.samples[name].draw=0,0
    end
    self.liveNative=self.native:getCount()
    if self.backend~='gpu' then self.liveGPU=self.gpu:getCount() end
    if self.view~='both' and not self.benchmark and not self.paused and not self.mouseCollision and self.settling==0 then self.results[self.view]=self.fps end
    self.elapsed,self.frames=0,0
  end
end
function C:startBenchmark()
  self:setMouseCollision(false)
  self.paused=false;self.benchmarkDone=false;self.results={}
  self:setView('native');self.benchmark={elapsed=0,frames=0,seconds=0}
end
function C:release()
  if self.released then return end
  self.native:release();self.gpu:release();self.texture:release()
  self.targets.native:release();self.targets.gpu:release();self.released=true
end
return C
