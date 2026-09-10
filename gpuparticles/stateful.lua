local prefix=(...):gsub('stateful$','')
local records,curves,shaders=require(prefix..'records'),require(prefix..'curves'),require(prefix..'shaders')
local forces,fields=require(prefix..'forces'),require(prefix..'fields')
local timeline=require(prefix..'timeline')
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
  g.setCanvas(e.stampTargets)
  g.setShader(e.stampShader)
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
  e.spawnTexture,e.motionTexture,e.styleTexture=canvas(),canvas(),canvas()
  e.stampTargets={e.stateA,e.spawnTexture,e.motionTexture,e.styleTexture}
  e.shader,e.shaderKey=shaders.acquire('render')
  e.simShader,e.simShaderKey=shaders.acquire('simulate',e.compiledForces.source,e.compiledForces.key)
  e.stampShader,e.stampShaderKey=shaders.acquire('stamp')
  fields.new(e)
  stamp(e,e.quad,e.config.max)
end
function M.update(e,dt)
  if dt==0 then return end
  timeline.advance(e,dt)
  local g,s=love.graphics,e.simShader
  g.push('all');prepare()
  g.setCanvas(e.stateB);g.setShader(s)
  shaders.common(e,s);forces.send(e.compiledForces,s);fields.send(e,s)
  s:send('u_state',e.stateA);s:send('u_spawn',e.spawnTexture)
  s:send('u_motion',e.motionTexture);s:send('u_style',e.styleTexture)
  s:send('u_dt',dt);s:send('u_texSize',e.texSize);s:send('u_count',e.config.max)
  g.draw(e.stateA)
  g.pop()
  e.stateA,e.stateB=e.stateB,e.stateA
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
function M.draw(e,x,y)
  local g=love.graphics
  g.push('all');g.setBlendMode(e.config.blendMode);g.setShader(e.shader)
  shaders.common(e,e.shader);curves.send(e,e.shader)
  e.shader:send('u_state',e.stateA);e.shader:send('u_texSize',e.texSize)
  g.drawInstanced(e.quad,e.config.max,x or 0,y or 0)
  g.pop()
end
M.release=require(prefix..'resources').release

return M
