local timeline=require((...):gsub('records$','timeline'))
local random=require((...):gsub('records$','random'))
local M = {}
local ok, ffi = pcall(require, 'ffi')
M.format = {{'ParticleSpawn','float',4},{'ParticleMotion','float',4},{'ParticleStyle','float',4},{'ParticleIndex','float',1}}
M.stride = 13
local function between(e, range)
  if range[1]==range[2] then return range[1] end
  return range[1]+(range[2]-range[1])*e.random:random()
end
function M.record(e, slot, continuous)
  local c, r = e.config, e.random
  local seed = r:random()
  local life = between(e,c.lifetime)
  local angle = c.direction
  if c.spread~=0 then angle=angle+(r:random()-0.5)*c.spread end
  local speed = between(e,c.speed)
  local a = c.emissionArea
  local x,y = 0,0
  if a.distribution == 'uniform' then
    x,y = (r:random()*2-1)*a.x, (r:random()*2-1)*a.y
  elseif a.distribution == 'normal' then
    x,y = r:randomNormal(a.x),r:randomNormal(a.y)
  elseif a.distribution == 'ellipse' or a.distribution == 'borderellipse' then
    local theta = r:random()*math.pi*2
    local radius = a.distribution == 'ellipse' and math.sqrt(r:random()) or 1
    x,y = math.cos(theta)*radius*a.x, math.sin(theta)*radius*a.y
  elseif a.distribution == 'borderrectangle' then
    local t = r:random()*4*(a.x+a.y)
    if t < 2*a.x then x,y=-a.x+t,-a.y
    elseif t < 2*a.x+2*a.y then x,y=a.x,-a.y+t-2*a.x
    elseif t < 4*a.x+2*a.y then x,y=a.x-(t-2*a.x-2*a.y),a.y
    else x,y=-a.x,a.y-(t-4*a.x-2*a.y) end
  end
  local ca,sa = math.cos(a.angle or 0),math.sin(a.angle or 0)
  x,y = x*ca-y*sa,x*sa+y*ca
  if a.directionRelative then angle=angle+math.atan2(y,x) end
  local period = continuous and (c.rate > 0 and c.max/c.rate or 0) or -1
  local birth = continuous and (c.rate > 0 and e.epoch+slot/c.rate or 1e20) or e.time
  local rotation,spin = between(e,c.rotation),between(e,c.spin)
  if c.spinVariation~=0 then spin=spin*(1-c.spinVariation*r:random()) end
  return birth,life,seed,period, x,y,math.cos(angle)*speed,math.sin(angle)*speed,
    rotation,spin,continuous and 0 or c.position[1],continuous and 0 or c.position[2],slot-1
end
function M.build(e, first, count, continuous)
  local result, ptr
  if ok and not e.config.noFFI then
    result=love.data.newByteData(count*M.stride*4)
    if result.getFFIPointer then ptr=ffi.cast('float*',result:getFFIPointer())
    else result:release();result={} end
  else result={} end
  for i=1,count do
    local slot=first+i-1
    local b,l,s,p,x,y,vx,vy,r,spin,scale,flag,index
    if e.preserveBursts and e.isBurst[slot] then
      b,l,s,p,x,y,vx,vy,r,spin,scale,flag,index=e.instances:getVertex(slot)
    else
      b,l,s,p,x,y,vx,vy,r,spin,scale,flag,index=M.record(e,slot,continuous)
      e.isBurst[slot]=not continuous
    end
    e.births[slot],e.lives[slot],e.periods[slot]=b,l,p
    if ptr then
      local j=(i-1)*M.stride
      ptr[j],ptr[j+1],ptr[j+2],ptr[j+3]=b,l,s,p
      ptr[j+4],ptr[j+5],ptr[j+6],ptr[j+7]=x,y,vx,vy
      ptr[j+8],ptr[j+9],ptr[j+10],ptr[j+11],ptr[j+12]=r,spin,scale,flag,index
    else result[i]={b,l,s,p,x,y,vx,vy,r,spin,scale,flag,index} end
  end
  return result
end
function M.releaseData(data) if type(data)=='userdata' then data:release() end end
function M.new(e)
  timeline.new(e)
  e.epoch=e.emissionTime
  e.births,e.lives,e.periods,e.isBurst={},{},{},{}
  e.random=random.new(e.config.seed)
  local t=love.timer.getTime()
  local data=M.build(e,1,e.config.max,true)
  e.buildTime=love.timer.getTime()-t
  t=love.timer.getTime()
  e.instances=love.graphics.newMesh(M.format,data,'points','stream')
  e.uploadTime=love.timer.getTime()-t
  M.releaseData(data)
end
function M.quad(e)
  local mesh=love.graphics.newMesh({{'VertexPosition','float',2},{'VertexTexCoord','float',2}},
    {{-.5,-.5,0,0},{.5,-.5,1,0},{.5,.5,1,1},{-.5,.5,0,1}},'fan','static')
  for _,attribute in ipairs(M.format) do mesh:attachAttribute(attribute[1],e.instances,'perinstance') end
  mesh:setTexture(e.texture)
  return mesh
end
function M.emit(e,n,stamp)
  if e.config.insertMode=='random' then e.cursor=math.floor(e.random:random()*e.config.max)+1 end
  n=math.min(n,e.config.max)
  while n>0 do
    local bottom=e.config.insertMode=='bottom'
    local count=math.min(n,bottom and e.cursor or (e.config.max-e.cursor+1))
    local first=bottom and (e.cursor-count+1) or e.cursor
    local data=M.build(e,first,count,false)
    e.instances:setVertices(data,first,count)
    if stamp then stamp(e,first,count,data) end
    M.releaseData(data)
    e.cursor=bottom and ((e.cursor-count-1)%e.config.max+1) or ((e.cursor+count-1)%e.config.max+1)
    n=n-count
  end
end
function M.refresh(e)
  e.random:setSeed(e.config.seed)
  e.preserveBursts=true
  local data=M.build(e,1,e.config.max,true)
  e.preserveBursts=false
  e.instances:setVertices(data)
  M.releaseData(data)
end
function M.count(e)
  local count=0
  local now=e.time
  for i=1,e.config.max do
    local birth,life,period=e.births[i],e.lives[i],e.periods[i]
    local burstEnd
    if period<0 and now-birth>=life and e.config.rate>0 then
      burstEnd=birth+life
      period=e.config.max/e.config.rate
      birth=e.epoch+i/e.config.rate
    end
    if period>0 then
      local reference=e.emissionTime
      if reference>=birth then
        birth=timeline.wallBirth(e,birth+math.floor((reference-birth)/period)*period)
      else birth=1e20 end
    end
    if now>=birth and now-birth<life and (not burstEnd or birth>=burstEnd) then count=count+1 end
  end
  return count
end
return M
