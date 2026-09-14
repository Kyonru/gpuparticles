local prefix=(...):gsub('setters$','')
local config,curves,timeline=require(prefix..'config'),require(prefix..'curves'),require(prefix..'timeline')
local M={}
local unpack=unpack or table.unpack
local collisionActions={bounce=0,slide=1,stop=2,disappear=3,respawn=4}
local function refresh(e,recordsChanged)
  if e.native then require(prefix..'native').configure(e)
  elseif recordsChanged then e.driver.refresh(e) end
  return e
end
local function stops(args)
  if #args==1 and type(args[1])=='table' and type(args[1][1])=='table' then return config.copy(args[1]) end
  return config.copy(args)
end
local function curveChanged(e)
  if e.native then return refresh(e) end
  curves.refresh(e)
  return e
end
function M.install(E)
  function E:setCollisionResponse(mode)
    self:_check()
    assert(collisionActions[mode]~=nil,'gpuparticles: collision response must be bounce, slide, stop, disappear or respawn')
    self.config.collisionResponse=mode
    if self.fields then self.fields.collisionAction=collisionActions[mode] end
    return self
  end
  function E:setCircleCollider(x,y,radius)
    self:_check()
    assert(self.mode=='stateful','gpuparticles: setCircleCollider requires an emitter constructed with circleCollider or stateful mode')
    local c=self.config.circleCollider
    if x==nil then
      if c then c.enabled=false end
      return self
    end
    config.number(x,'circle center x');config.number(y,'circle center y');config.number(radius,'circle radius',0.000001)
    if not c then c=config.circleCollider({});self.config.circleCollider=c end
    c.x,c.y,c.radius,c.enabled=x,y,radius,true
    return self
  end
  function E:setBoxCollider(x,y,width,height)
    self:_check()
    assert(self.mode=='stateful','gpuparticles: setBoxCollider requires an emitter constructed with boxCollider or stateful mode')
    local c=self.config.boxCollider
    if x==nil then if c then c.enabled=false end;return self end
    config.number(x,'box center x');config.number(y,'box center y')
    config.number(width,'box width',0.000001);config.number(height,'box height',0.000001)
    if not c then c=config.boxCollider({});self.config.boxCollider=c end
    c.x,c.y,c.width,c.height,c.enabled=x,y,width,height,true
    return self
  end
  function E:setCapsuleCollider(x1,y1,x2,y2,radius)
    self:_check()
    assert(self.mode=='stateful','gpuparticles: setCapsuleCollider requires an emitter constructed with capsuleCollider or stateful mode')
    local c=self.config.capsuleCollider
    if x1==nil then if c then c.enabled=false end;return self end
    config.number(x1,'capsule start x');config.number(y1,'capsule start y')
    config.number(x2,'capsule end x');config.number(y2,'capsule end y');config.number(radius,'capsule radius',0.000001)
    if not c then c=config.capsuleCollider({});self.config.capsuleCollider=c end
    c.x1,c.y1,c.x2,c.y2,c.radius,c.enabled=x1,y1,x2,y2,radius,true
    return self
  end
  function E:setColors(...)
    self:_check()
    local args={...}
    local values
    if type(args[1])=='number' then
      assert(#args%4==0,'gpuparticles: colors need RGBA groups')
      values={};for i=1,#args,4 do values[#values+1]={args[i],args[i+1],args[i+2],args[i+3]} end
    else values=stops(args) end
    assert(#values>0,'gpuparticles: at least one color is required')
    for _,c in ipairs(values) do
      assert(type(c)=='table' and #c>=3,'gpuparticles: colors must be RGB or RGBA tables')
      c[4]=c[4] or 1
      for i=1,4 do config.number(c[i],'color') end
    end
    self.config.colors=values
    return curveChanged(self)
  end
  function E:setSizes(...)
    self:_check()
    local values={...};if type(values[1])=='table' then values=config.copy(values[1]) end
    assert(#values>0,'gpuparticles: at least one size is required')
    for _,v in ipairs(values) do config.number(v,'size',0) end
    self.config.sizes=values
    return curveChanged(self)
  end
  local ranges={setSpeed={'speed'},setParticleLifetime={'lifetime',0.0001},setSpin={'spin'},setRotation={'rotation'},
    setRadialAcceleration={'radialAcceleration'},setTangentialAcceleration={'tangentialAcceleration'},setLinearDamping={'damping',0}}
  for method,spec in pairs(ranges) do
    local field,minimum=spec[1],spec[2]
    E[method]=function(self,a,b)
      self:_check();self.config[field]=config.range({a,b or a},nil,field,minimum)
      return refresh(self,field=='speed' or field=='lifetime' or field=='spin' or field=='rotation')
    end
  end
  local scalars={setDirection='direction',setSpread='spread',setSizeVariation='sizeVariation',setSpinVariation='spinVariation'}
  for method,field in pairs(scalars) do
    E[method]=function(self,value)
      self:_check();config.number(value,field)
      if field=='sizeVariation' or field=='spinVariation' then assert(value>=0 and value<=1,'gpuparticles: variation must be between 0 and 1') end
      self.config[field]=value
      return refresh(self,true)
    end
  end
  function E:setLinearAcceleration(x,y,maxX,maxY)
    self:_check()
    self.config.acceleration={config.number(x,'acceleration x'),config.number(y,'acceleration y'),
      config.number(maxX or x,'maximum acceleration x'),config.number(maxY or y,'maximum acceleration y')}
    assert(self.config.acceleration[3]>=x and self.config.acceleration[4]>=y,'gpuparticles: acceleration maximum must be >= minimum')
    return refresh(self)
  end
  function E:setRelativeRotation(value)
    self:_check();assert(type(value)=='boolean','gpuparticles: relative rotation must be boolean')
    self.config.relativeRotation=value;return refresh(self)
  end
  -- Uniform only: the style shader reads it every draw, so no records are rebuilt.
  function E:setStretch(seconds)
    self:_check();self.config.stretch=config.number(seconds,'stretch',0)
    return self
  end
  function E:setOffset(x,y)
    self:_check();self.config.offset={config.number(x,'offset x'),config.number(y,'offset y')}
    return refresh(self)
  end
  function E:setQuads(...)
    self:_check()
    local q={...};if type(q[1])=='table' then q=config.copy(q[1]) end
    for _,quad in ipairs(q) do assert(quad.typeOf and quad:typeOf('Quad'),'gpuparticles: setQuads expects LÖVE Quads') end
    self.config.quads=q;return curveChanged(self)
  end
  function E:setEmissionArea(distribution,x,y,angle,directionRelative)
    self:_check()
    local valid={none=true,uniform=true,normal=true,ellipse=true,borderellipse=true,borderrectangle=true}
    assert(valid[distribution],'gpuparticles: invalid emission area distribution')
    self.config.emissionArea={distribution=distribution,x=config.number(x or 0,'area x',0),y=config.number(y or 0,'area y',0),
      angle=config.number(angle or 0,'area angle'),directionRelative=not not directionRelative}
    return refresh(self,true)
  end
  function E:setEmitterLifetime(seconds)
    self:_check();self.config.emitterLifetime=config.number(seconds,'emitter lifetime');self.remaining=seconds
    return refresh(self)
  end
  function E:setEmissionRate(rate)
    self:_check();self.config.rate=config.number(rate,'emission rate',0)
    self.epoch=self.emissionTime or 0
    return refresh(self,true)
  end
  function E:setInsertMode(mode)
    self:_check();assert(mode=='top' or mode=='bottom' or mode=='random','gpuparticles: invalid insert mode')
    self.config.insertMode=mode;self.cursor=mode=='bottom' and self.config.max or 1
    return refresh(self)
  end
  function E:setBufferSize(n)
    self:_check();config.number(n,'buffer size',1);assert(n%1==0,'gpuparticles: buffer size must be an integer')
    assert(not self.config.selfCollision or n<=config.selfCollisionLimit,'gpuparticles: selfCollision supports at most 24000 particle slots per emitter')
    self.config.max=n
    if self.native then self.native:setBufferSize(n)
    else self:reset() end
    return self
  end
  function E:start()
    self:_check()
    if self.native then self.native:start()
    elseif not self.running then
      if self.remaining==0 then self.remaining=self.config.emitterLifetime end
      timeline.resume(self)
    end
    self.running,self.paused=true,false
    return self
  end
  function E:stop()
    self:_check()
    if self.native then self.native:stop() end
    self.running,self.paused=false,false;self.remaining=self.config.emitterLifetime
    return self
  end
  function E:pause()
    self:_check()
    if self.native then self.native:pause() end
    self.running,self.paused=false,true
    return self
  end
  function E:reset()
    self:_check()
    if self.native then self.native:reset()
    else
      self.driver.release(self)
      self.time,self.cursor=0,self.config.insertMode=='bottom' and self.config.max or 1
      self.driver.new(self)
    end
    return self
  end
  function E:isActive() return self.native and self.native:isActive() or (not self.native and self.running) end
  function E:isPaused() return self.native and self.native:isPaused() or (not self.native and self.paused) end
  function E:isStopped() return self.native and self.native:isStopped() or (not self.native and not self.running and not self.paused) end
  function E:isEmpty() return self:getCount()==0 end
  function E:isFull() return self:getCount()==self.config.max end
  function E:getBufferSize() return self.config.max end
  function E:getEmissionRate() return self.config.rate end
  function E:getEmitterLifetime() return self.config.emitterLifetime end
  function E:getParticleLifetime() return unpack(self.config.lifetime) end
  function E:getStretch() return self.config.stretch end
end
return M
