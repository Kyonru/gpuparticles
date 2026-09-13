local prefix=(...):gsub('stateful$','')
local records,curves,shaders=require(prefix..'records'),require(prefix..'curves'),require(prefix..'shaders')
local forces,fields=require(prefix..'forces'),require(prefix..'fields')
local timeline=require(prefix..'timeline')
local selfCollision=require(prefix..'selfcollision')
local M={}
local function prepare()
  local g=love.graphics
  g.origin();g.setColor(1,1,1,1);g.setScissor();g.setStencilTest();g.setDepthMode()
  g.setColorMask(true,true,true,true);g.setMeshCullMode('none')
  g.setBlendMode('replace','premultiplied')
end
local function stamp(e,quad,count,preserve)
  local g=love.graphics
  g.push('all');prepare()
  e.stampTargets[1]=preserve and e.stateB or e.stateA
  if e.depthA then e.stampTargets[5]=preserve and e.depthB or e.depthA end
  g.setCanvas(e.stampTargets)
  g.setShader(e.stampShader)
  if e.depthA then
    local d=e.config.depth
    shaders.send(e.stampShader,'u_depthAxis',d.axis);shaders.send(e.stampShader,'u_depthOrbit',d.orbit)
    shaders.send(e.stampShader,'u_depthEmission',d.emission);shaders.send(e.stampShader,'u_depthSpeed',d.speed)
  end
  e.stampShader:send('u_origin',e.config.position)
  e.stampShader:send('u_texSize',e.texSize)
  g.drawInstanced(quad,count)
  g.pop()
end
function M.new(e)
  records.new(e)
  e.quad=records.quad(e)
  curves.refresh(e)
  e.texSize=math.ceil(math.sqrt(e.config.max))
  assert(e.texSize<=e.capabilities.limits.texturesize,'gpuparticles: particle state exceeds maximum texture size')
  local function canvas()
    local c=love.graphics.newCanvas(e.texSize,e.texSize,{format='rgba32f',dpiscale=1,msaa=0})
    c:setFilter('nearest','nearest');c:setWrap('clamp','clamp')
    love.graphics.push('all');prepare();love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0);love.graphics.pop()
    return c
  end
  e.stateA,e.stateB=canvas(),canvas()
  -- Optional simulated z: a small ping-pong pair, created only for `depth` without code.
  -- Emitters without it allocate nothing here and keep the plain shaders below.
  local depth=e.config.depth
  if depth and not depth.code then
    local function depthCanvas(format)
      local c=love.graphics.newCanvas(e.texSize,e.texSize,{format=format,dpiscale=1,msaa=0})
      c:setFilter('nearest');c:setWrap('clamp','clamp')
      love.graphics.push('all');prepare();love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0);love.graphics.pop()
      return c
    end
    local format=love.graphics.getCanvasFormats().rg32f and 'rg32f' or 'rgba32f'
    e.depthA,e.depthB=depthCanvas(format),depthCanvas(format)
    -- A driver may refuse render targets of different formats together; match the state then.
    love.graphics.push('all')
    local mixedTargetsOk=format=='rgba32f' or pcall(love.graphics.setCanvas,e.stateB,e.depthB)
    love.graphics.pop()
    if not mixedTargetsOk then
      e.depthA:release();e.depthB:release()
      e.depthA,e.depthB=depthCanvas('rgba32f'),depthCanvas('rgba32f')
    end
  end
  e.spawnTexture,e.motionTexture,e.styleTexture=canvas(),canvas(),canvas()
  e.stampTargets={e.stateA,e.spawnTexture,e.motionTexture,e.styleTexture}
  e.shader,e.shaderKey=shaders.acquire('render',nil,nil,depth and (e.depthA and {} or {code=depth.code}) or nil)
  e.simShader,e.simShaderKey=shaders.acquire('simulate',e.compiledForces.source,e.compiledForces.key,e.depthA and {} or nil)
  e.stampShader,e.stampShaderKey=shaders.acquire('stamp',nil,nil,e.depthA and {} or nil)
  fields.new(e)
  if e.config.selfCollision then selfCollision.new(e,canvas) end
  stamp(e,e.quad,e.config.max)
end
function M.update(e,dt)
  if dt==0 then return end
  timeline.advance(e,dt)
  local g,s=love.graphics,e.simShader
  g.push('all');prepare()
  if e.depthA then g.setCanvas(e.stateB,e.depthB);g.setShader(s) else
  g.setCanvas(e.stateB);g.setShader(s)
  end
  shaders.common(e,s);forces.send(e.compiledForces,s);fields.send(e,s)
  s:send('u_state',e.stateA);s:send('u_spawn',e.spawnTexture)
  s:send('u_motion',e.motionTexture);s:send('u_style',e.styleTexture)
  s:send('u_dt',dt);s:send('u_texSize',e.texSize);s:send('u_count',e.config.max)
  if e.depthA then
    local d=e.config.depth
    s:send('u_depthState',e.depthA)
    shaders.send(s,'u_depthAxis',d.axis);shaders.send(s,'u_depthOrbit',d.orbit)
    shaders.send(s,'u_depthGravity',d.gravity);shaders.send(s,'u_depthEmission',d.emission)
    shaders.send(s,'u_depthSpeed',d.speed)
  end
  g.draw(e.stateA)
  e.stateA,e.stateB=e.stateB,e.stateA
  if e.depthA then e.depthA,e.depthB=e.depthB,e.depthA end
  if e.selfPacked then selfCollision.step(e) end
  g.pop()
end
function M.warm(e,seconds)
  while seconds>0 do local dt=math.min(seconds,e.config.warmStep or 1/60);M.update(e,dt);seconds=seconds-dt end
end
function M.emit(e,n)
  records.emit(e,n,function(emitter,_,count,data)
    local instances=love.graphics.newMesh(records.format,data,'points','stream')
    local original=emitter.instances
    emitter.instances=instances
    local quad=records.quad(emitter)
    emitter.instances=original
    stamp(emitter,quad,count)
    quad:release();instances:release()
  end)
end
M.count=records.count
function M.refresh(e) records.refresh(e);stamp(e,e.quad,e.config.max,true) end
function M.draw(e,x,y,options)
  local g=love.graphics
  g.push('all');g.setBlendMode(e.config.blendMode);g.setShader(e.shader)
  shaders.common(e,e.shader);curves.send(e,e.shader)
  e.shader:send('u_state',e.stateA);e.shader:send('u_texSize',e.texSize)
  shaders.depth(e,e.shader,options)
  g.drawInstanced(e.quad,e.config.max,x or 0,y or 0)
  g.pop()
end
-- Bytes held in particle state and spawn-record textures, including the optional z pair.
local bytesPerTexel={rgba32f=16,rg32f=8,rgba16f=8,rg16f=4,r32f=4}
function M.stateMemory(e)
  local total=0
  for _,key in ipairs{'stateA','stateB','spawnTexture','motionTexture','styleTexture','depthA','depthB','selfPacked'} do
    local c=e[key]
    if c then total=total+c:getWidth()*c:getHeight()*(bytesPerTexel[c:getFormat()] or 16) end
  end
  return total
end
M.release=require(prefix..'resources').release

return M
