local prefix=(...):gsub('%.init$','')..'.'
local U,Shaders=require(prefix..'util'),require(prefix..'shaders')
local W={};W.__index=W
function W.new(options)
  options=options or {}
  U.keys(options,'width height cellSize fixedStep maxSubsteps transportSteps pressureIterations velocityDamping renderStyle distance wind','world')
  local g=love.graphics
  local caps=g.getSupported()
  if not caps.glsl3 or not caps.pixelshaderhighp or not g.getCanvasFormats().rgba32f then
    return nil,'gpuparticles volume requires GLSL 3, high precision pixel shaders, and rgba32f canvases'
  end
  local self=setmetatable({materials={},sources={},reactions={},owned={},keys={},shaders={},time=0,accumulator=0,
    paused=false,released=false,droppedTime=0,wind=U.vector(options.wind,{0,0},'wind',2),circle={0,0,0,0},
    box={0,0,0,0},boxEnabled=false,capsule={0,0,0,0},capsuleRadius=0,capsuleEnabled=false,
    brush={0,0,0,0},impulse={0,0},
    width=U.number(options.width,1280,'width',1),height=U.number(options.height,800,'height',1),
    cellSize=U.number(options.cellSize,8,'cell size',0.25),
    fixedStep=U.number(options.fixedStep,1/120,'fixed step',1/1000,1/30),
    maxSubsteps=U.number(options.maxSubsteps,8,'max substeps',1,64,true),
    transportSteps=U.number(options.transportSteps,3,'transport steps',1,4,true),
    pressureIterations=U.number(options.pressureIterations,24,'pressure iterations',1,80,true),
    velocityDamping=U.number(options.velocityDamping,0.1,'velocity damping',0,20),
    renderStyle=U.choice(options.renderStyle,'pixel','render style',{pixel=true,smooth=true})},W)
  self.columns,self.rows=math.ceil(self.width/self.cellSize),math.ceil(self.height/self.cellSize)
  local limit=g.getSystemLimits().texturesize
  assert(self.columns<=limit and self.rows<=limit and self.columns*self.rows<=1048576,'volume grid exceeds device or 1048576-cell limit')
  self.cell={self.width/self.columns,self.height/self.rows};self.grid={self.columns,self.rows}
  assert(options.distance==nil or type(options.distance)=='function','volume distance must be a function')
  local ok,reason=xpcall(function()
    U.guard(function()
      self.empty=self:_canvas();U.clear(self.empty)
      self.terrain=self:_canvas();self.terrainNext=self:_canvas()
      local data=love.image.newImageData(self.columns,self.rows,'rgba32f');self.owned[#self.owned+1]=data
      data:mapPixel(function(x,y)
        return U.number(options.distance and options.distance((x+0.5)*self.cell[1],(y+0.5)*self.cell[2]) or 1e6,nil,'terrain distance'),0,0,1
      end)
      local image=g.newImage(data);self.owned[#self.owned+1]=image
      g.setCanvas(self.terrain);g.draw(image)
      self.initialTerrain=image
      for _,name in ipairs{'inject','inject-apply','terrain','heat','impulse','reaction','reaction-apply'} do self:_shader(name) end
      self.transfer=self:_canvas();U.clear(self.transfer)
    end)
  end,debug.traceback)
  if not ok then self:release();return nil,reason end
  return self
end
function W:_canvas()
  local c=U.canvas(self);self.owned[#self.owned+1]=c;return c
end
function W:_shader(name)
  if not self.shaders[name] then
    local shader,key=Shaders.acquire(name);self.shaders[name]=shader;self.keys[#self.keys+1]=key
  end
  return self.shaders[name]
end
function W:_newGas()
  if self.gas then return end
  local gas={owned={}}
  local ok,err=xpcall(function()
    U.guard(function()
      for _,name in ipairs{'state','next','force','divergence','pressure','pressureNext'} do
        gas[name]=U.canvas(self);gas.owned[#gas.owned+1]=gas[name];U.clear(gas[name])
      end
      for _,name in ipairs{'velocity','divergence','pressure','project','gas-transport'} do self:_shader(name) end
    end)
  end,debug.traceback)
  if not ok then for _,c in ipairs(gas.owned) do c:release() end;error(err,0) end
  self.gas=gas
end
function W:addMaterial(options) return require(prefix..'material').new(self,options) end
function W:newSource(options) return require(prefix..'source').new(self,options) end
function W:addReaction(options) return require(prefix..'reaction').new(self,options) end
function W:_injectSource(source,amount,immediate)
  if source.count==0 or amount==0 then return end
  local g,m=love.graphics,source.material
  if immediate then U.clear(m.injection) end
  g.setCanvas(m.injection);local s=self.shaders.inject;U.bind(self,s)
  s:send('u_brush',source.brush);s:send('u_amount',amount/(source.count*self.cell[1]*self.cell[2]))
  s:send('u_temperature',source.temperature)
  g.setBlendMode('add','premultiplied')
  local b=source.bounds;g.rectangle('fill',b[1],b[2],b[3]-b[1]+1,b[4]-b[2]+1)
  g.setBlendMode('replace','premultiplied')
  if immediate then
    s=self.shaders['inject-apply'];s:send('u_injection',m.injection);s:send('u_gas',m.model=='gas')
    U.pass(self,s,m.next,m.state);U.swap(m)
  end
end
function W:_water(dt)
  local m=self.water;if not m then return end
  local flux,transport=m.fluxShader,m.transportShader
  flux:send('u_step',dt/self.fixedStep*m.flowSpeed);flux:send('u_compression',m.compression);flux:send('u_spread',m.spread)
  transport:send('u_flux',m.flux);transport:send('u_injection',m.injection)
  transport:send('u_injectionScale',1/self.transportSteps)
  transport:send('u_decay',math.exp(-m.dissipation*dt/self.transportSteps))
  transport:send('u_cooling',math.exp(-m.cooling*dt/self.transportSteps))
  for _=1,self.transportSteps do
    U.pass(self,flux,m.flux,m.state);U.pass(self,transport,m.next,m.state);U.swap(m)
  end
end
function W:_gas(dt)
  local gas=self.gas;if not gas then return end
  local g=love.graphics
  U.clear(gas.force);g.setBlendMode('add','premultiplied')
  for _,m in ipairs(self.materials) do if m.model=='gas' then
    local s=m.forceShader;U.send(s,'u_velocity',gas.state);U.send(s,'u_buoyancy',m.buoyancy);Shaders.send(s,m.force)
    U.pass(self,s,gas.force,m.state)
  end end
  g.setBlendMode('replace','premultiplied')
  local s=self.shaders.velocity;s:send('u_dt',dt);s:send('u_force',gas.force)
  s:send('u_wind',self.wind);s:send('u_damping',self.velocityDamping)
  U.pass(self,s,gas.next,gas.state);U.swap(gas)
  self:_project()
  s=self.shaders['gas-transport'];s:send('u_velocity',gas.state);s:send('u_dt',dt)
  for _,m in ipairs(self.materials) do if m.model=='gas' then
    s:send('u_injection',m.injection);s:send('u_decay',math.exp(-m.dissipation*dt));s:send('u_cooling',math.exp(-m.cooling*dt))
    U.pass(self,s,m.next,m.state);U.swap(m)
  end end
end
function W:_project()
  local gas=self.gas
  U.pass(self,self.shaders.divergence,gas.divergence,gas.state)
  U.clear(gas.pressure)
  local s=self.shaders.pressure;s:send('u_divergence',gas.divergence)
  for _=1,self.pressureIterations do
    U.pass(self,s,gas.pressureNext,gas.pressure);gas.pressure,gas.pressureNext=gas.pressureNext,gas.pressure
  end
  s=self.shaders.project;s:send('u_pressure',gas.pressure)
  U.pass(self,s,gas.next,gas.state);U.swap(gas)
end
function W:_react(dt)
  for _,r in ipairs(self.reactions) do if r.active then
    local s=self.shaders.reaction;s:send('u_threshold',r.temperatureAbove);s:send('u_fraction',1-math.exp(-r.rate*dt))
    U.pass(self,s,self.transfer,r.from.state)
    s=self.shaders['reaction-apply'];s:send('u_transfer',self.transfer)
    s:send('u_sign',-1);U.pass(self,s,r.from.next,r.from.state);U.swap(r.from)
    s:send('u_sign',1);U.pass(self,s,r.to.next,r.to.state);U.swap(r.to)
  end end
end
function W:_step(dt)
  self.time=self.time+dt
  for _,m in ipairs(self.materials) do U.clear(m.injection) end
  for _,source in ipairs(self.sources) do if source.active then self:_injectSource(source,source.rate*dt) end end
  self:_water(dt);self:_gas(dt);self:_react(dt)
end
function W:update(dt)
  U.alive(self);dt=U.number(dt,nil,'dt',0)
  if self.paused then return end
  local available=self.accumulator+dt
  self.accumulator=math.min(available,self.fixedStep*self.maxSubsteps)
  self.droppedTime=self.droppedTime+available-self.accumulator
  U.guard(function()
    while self.accumulator+1e-10>=self.fixedStep do
      self:_step(self.fixedStep);self.accumulator=math.max(0,self.accumulator-self.fixedStep)
    end
  end)
end
function W:warm(seconds)
  U.alive(self);seconds=U.number(seconds,nil,'warm seconds',0)
  U.guard(function() for _=1,math.floor(seconds/self.fixedStep+1e-8) do self:_step(self.fixedStep) end end)
  return self
end
function W:draw(x,y,debug)
  U.alive(self);local g=love.graphics
  g.push('all');g.translate(x or 0,y or 0);g.setBlendMode('alpha');g.setColor(1,1,1,1)
  for _,m in ipairs(self.materials) do
    local s=m.drawShader;U.bind(self,s);Shaders.send(s,m.render)
    U.send(s,'u_gas',m.model=='gas');U.send(s,'u_smooth',self.renderStyle=='smooth');U.send(s,'u_debug',not not debug)
    U.send(s,'u_color',m.color);U.send(s,'u_flux',m.flux or self.empty)
    g.draw(m.state,0,0,0,self.cell[1],self.cell[2])
  end
  g.pop()
end
function W:setWind(x,y)
  U.alive(self);x=U.number(x,nil,'wind x');y=U.number(y,nil,'wind y');self.wind[1],self.wind[2]=x,y;return self
end
function W:setCircleCollider(x,y,radius)
  U.alive(self)
  if x==nil then self.circle[4]=0
  else
    x=U.number(x,nil,'circle x');y=U.number(y,nil,'circle y');radius=U.number(radius,nil,'circle radius',0)
    self.circle[1],self.circle[2],self.circle[3],self.circle[4]=x,y,radius,1
  end
  return self
end
function W:setBoxCollider(x,y,width,height)
  U.alive(self)
  if x==nil then self.boxEnabled=false
  else
    x=U.number(x,nil,'box x');y=U.number(y,nil,'box y')
    width=U.number(width,nil,'box width',0.001);height=U.number(height,nil,'box height',0.001)
    self.box[1],self.box[2],self.box[3],self.box[4],self.boxEnabled=x,y,width*0.5,height*0.5,true
  end
  return self
end
function W:setCapsuleCollider(x1,y1,x2,y2,radius)
  U.alive(self)
  if x1==nil then self.capsuleEnabled=false
  else
    x1=U.number(x1,nil,'capsule start x');y1=U.number(y1,nil,'capsule start y')
    x2=U.number(x2,nil,'capsule end x');y2=U.number(y2,nil,'capsule end y')
    self.capsuleRadius=U.number(radius,nil,'capsule radius',0.001)
    self.capsule[1],self.capsule[2],self.capsule[3],self.capsule[4],self.capsuleEnabled=x1,y1,x2,y2,true
  end
  return self
end
function W:setRenderStyle(style) U.alive(self);self.renderStyle=U.choice(style,nil,'render style',{pixel=true,smooth=true});return self end
function W:pause() U.alive(self);self.paused=true;return self end
function W:start() U.alive(self);self.paused=false;return self end
function W:reset()
  U.alive(self)
  U.guard(function()
    for _,m in ipairs(self.materials) do for _,c in ipairs(m.owned) do U.clear(c) end end
    if self.gas then for _,c in ipairs(self.gas.owned) do U.clear(c) end end
  end)
  self.time,self.accumulator,self.droppedTime=0,0,0;return self
end
function W:_brush(x,y,radius)
  self.brush[1]=U.number(x,nil,'brush x');self.brush[2]=U.number(y,nil,'brush y')
  self.brush[3]=U.number(radius,nil,'brush radius',0.001);self.brush[4]=1
end
function W:paintTerrain(x,y,radius,solid)
  U.alive(self);assert(type(solid)=='boolean','paintTerrain requires a solid boolean');self:_brush(x,y,radius)
  U.guard(function()
    local s=self.shaders.terrain;s:send('u_brush',self.brush);s:send('u_solid',solid)
    U.pass(self,s,self.terrainNext,self.terrain);self.terrain,self.terrainNext=self.terrainNext,self.terrain
  end);return self
end
function W:resetTerrain()
  U.alive(self);U.guard(function() love.graphics.setCanvas(self.terrain);love.graphics.draw(self.initialTerrain) end);return self
end
function W:addHeat(x,y,radius,amount,material)
  U.alive(self);self:_brush(x,y,radius);amount=U.number(amount,nil,'heat',-1000,1000)
  assert(not material or (material.world==self and not material.released),'heat material must belong to this world')
  U.guard(function()
    local s=self.shaders.heat;s:send('u_brush',self.brush);s:send('u_heat',amount)
    for _,m in ipairs(self.materials) do if not material or material==m then U.pass(self,s,m.next,m.state);U.swap(m) end end
  end);return self
end
function W:addForce(x,y,radius,vx,vy)
  U.alive(self);assert(self.gas,'volume impulses require a gas material');self:_brush(x,y,radius)
  self.impulse[1]=U.number(vx,nil,'impulse x');self.impulse[2]=U.number(vy,nil,'impulse y')
  U.guard(function()
    local s=self.shaders.impulse;s:send('u_brush',self.brush);s:send('u_impulse',self.impulse)
    U.pass(self,s,self.gas.next,self.gas.state);U.swap(self.gas)
  end);return self
end
function W:readback(material)
  U.alive(self);assert(material and material.world==self and not material.released,'readback material must belong to this world')
  return material.state:newImageData()
end
function W:getBackend() U.alive(self);return 'gpu' end
function W:release()
  if self.released then return end
  self.released=true
  for i=#self.materials,1,-1 do self.materials[i]:release() end
  if self.gas then for _,c in ipairs(self.gas.owned) do c:release() end end
  for _,c in ipairs(self.owned) do c:release() end
  for _,key in ipairs(self.keys) do Shaders.release(key) end
end
return W
