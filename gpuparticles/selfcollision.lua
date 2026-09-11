local prefix=(...):gsub('selfcollision$','')
local shaders,fields=require(prefix..'shaders'),require(prefix..'fields')
local M={}
function M.new(e,canvas)
  e.selfPacked=canvas()
  e.selfPack,e.selfPackKey=shaders.acquire('selfpack')
  e.selfResolve,e.selfResolveKey=shaders.acquire('selfresolve')
end
-- The stateful driver supplies replace blending and restores all caller graphics state.
function M.step(e)
  local g,pack,resolve=love.graphics,e.selfPack,e.selfResolve
  local c=e.config.selfCollision
  shaders.common(e,pack);pack:send('u_spawn',e.spawnTexture);pack:send('u_texSize',e.texSize)
  resolve:send('u_texSize',e.texSize);resolve:send('u_count',e.config.max)
  resolve:send('u_radius',c.radius);resolve:send('u_bounce',c.bounce);resolve:send('u_strength',c.strength)
  fields.sendCollision(e,resolve)
  for _=1,c.iterations do
    g.setCanvas(e.selfPacked);g.setShader(pack);pack:send('u_state',e.stateA);g.draw(e.stateA)
    g.setCanvas(e.stateB);g.setShader(resolve)
    resolve:send('u_state',e.stateA);resolve:send('u_neighbors',e.selfPacked);g.draw(e.stateA)
    e.stateA,e.stateB=e.stateB,e.stateA
  end
end
return M
