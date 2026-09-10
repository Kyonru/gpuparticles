-- Also embedded verbatim in Lua exports. Only depends on gpuparticles and LÖVE.
local gpu=require('gpuparticles')
local R={};R.__index=R
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function build(layer,definition,owned)
  local c=copy(layer.emitter);c.mode='auto';c.forces={}
  if layer.shape and layer.shape~='disc' then
    local data=love.image.newImageData(32,32)
    data:mapPixel(function(x,y)
      x,y=(x+0.5-16)/16,(y+0.5-16)/16
      local r=math.sqrt(x*x+y*y);local alpha
      if layer.shape=='ring' then alpha=math.exp(-((r-0.66)*13)^2)
      elseif layer.shape=='spark' then alpha=math.max(0,1-math.sqrt(x*x+(y*5)^2))^2
      else alpha=math.max(0,1-r)^2*(0.7+0.3*math.sin(x*8+math.sin(y*5))*math.sin(y*9)) end
      return 1,1,1,alpha
    end)
    local ok,image=pcall(love.graphics.newImage,data);data:release();if not ok then error(image) end
    owned[#owned+1]=image;c.texture=image
  end
  if layer.turbulence.enabled then c.forces[#c.forces+1]=gpu.forces.turbulence(copy(layer.turbulence)) end
  if layer.curl.enabled then c.forces[#c.forces+1]=gpu.forces.curl(copy(layer.curl)) end
  if layer.attractor.enabled then c.attractors={copy(layer.attractor)} end
  local response=layer.response
  if layer.ground.enabled then c.collision={type='plane',y=layer.ground.y,radius=response.radius,bounce=response.bounce,friction=response.friction} end
  if layer.circle.enabled then c.circleCollider={x=layer.circle.x,y=layer.circle.y,radius=layer.circle.radius,
    particleRadius=response.radius,bounce=response.bounce,friction=response.friction} end
  if layer.flow.enabled then
    local data=love.image.newImageData(64,64,'rgba32f')
    data:mapPixel(function(x,y)
      local f=layer.flow.frequency*math.pi*2/64
      return math.sin(y*f),-0.35+math.cos(x*f)*0.65,0,1
    end)
    local ok,image=pcall(love.graphics.newImage,data);data:release();if not ok then error(image) end
    image:setFilter('linear','linear');image:setWrap('repeat','repeat')
    owned[#owned+1]=image;c.flowField={texture=image,size={definition.width,definition.height},strength=layer.flow.strength}
  end
  return gpu.newEmitter(c)
end
function R.new(definition)
  local self=setmetatable({definition=copy(definition),emitters={},owned={},events={},time=0,eventIndex=1,playing=true,hasState=false},R)
  local ok,err=xpcall(function()
    for i,l in ipairs(self.definition.layers) do
      local e=build(l,definition,self.owned);self.emitters[i]=e;e:stop()
      if l.enabled then
        self.hasState=self.hasState or e:getMode()=='stateful' or e:getBackend()=='native'
        self.events[#self.events+1]={time=l.start,kind=1,layer=i}
        self.events[#self.events+1]={time=math.min(definition.duration,l.start+l.span),kind=3,layer=i}
        for _,b in ipairs(l.bursts) do self.events[#self.events+1]={time=b.time,kind=2,layer=i,count=b.count} end
      end
    end
    table.sort(self.events,function(a,b) if a.time==b.time then return a.kind<b.kind end;return a.time<b.time end)
    self:_events()
  end,debug.traceback)
  if not ok then self:release();error(err) end
  return self
end
function R:_events()
  while self.eventIndex<=#self.events and self.events[self.eventIndex].time<=self.time+1e-8 do
    local event=self.events[self.eventIndex];local e=self.emitters[event.layer]
    if event.kind==1 then e:start()
    elseif event.kind==3 then e:stop()
    else
      local active=e:isActive();e:start();e:emit(event.count);if not active then e:stop() end
    end
    self.eventIndex=self.eventIndex+1
  end
end
function R:reset()
  self.time,self.eventIndex=0,1
  for _,e in ipairs(self.emitters) do e:reset();e:stop() end
  self:_events()
end
function R:advanceTo(target,budget)
  target=math.max(self.time,math.min(target,self.definition.duration));local steps=0
  while self.time<target-1e-8 do
    if budget and steps>=budget then return false end
    self:_events()
    local event=self.events[self.eventIndex]
    local finish=math.min(target,event and event.time or target)
    local dt=math.min(finish-self.time,self.hasState and 1/120 or math.huge)
    if dt>1e-8 then
      for i,e in ipairs(self.emitters) do if self.definition.layers[i].enabled then e:update(dt) end end
      self.time=self.time+dt;steps=steps+1
    else self.time=finish end
    self:_events()
  end
  self.time=target;self:_events();return true
end
function R:update(dt)
  assert(type(dt)=='number' and dt>=0 and dt<math.huge,'dt must be finite and nonnegative')
  if not self.playing then return end
  while dt>1e-8 do
    if self.time>=self.definition.duration-1e-8 then
      if not self.definition.loop then self.playing=false;return end
      self:reset()
    end
    local step=math.min(dt,self.definition.duration-self.time)
    self:advanceTo(self.time+step);dt=dt-step
  end
end
function R:seek(seconds)
  assert(type(seconds)=='number' and seconds==seconds and math.abs(seconds)<math.huge,'Seek time must be finite')
  self:reset();self:advanceTo(math.max(0,math.min(seconds,self.definition.duration)))
end
function R:draw(x,y)
  for i,e in ipairs(self.emitters) do if self.definition.layers[i].enabled and (not self.solo or self.solo==i) then e:draw(x or 0,y or 0) end end
end
function R:burst(index,count)
  local e=self.emitters[index];local active=e:isActive();e:start();e:emit(count);if not active then e:stop() end
end
function R:release()
  if self.released then return end
  for _,e in ipairs(self.emitters) do e:release() end
  for _,image in ipairs(self.owned) do image:release() end
  self.released=true
end
return R
