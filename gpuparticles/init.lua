local prefix = (...):gsub('%.init$', '') .. '.'
local capabilities = require(prefix .. 'capabilities')
local config = require(prefix .. 'config')
local E = require(prefix .. 'emitter')
local M = {forces = require(prefix .. 'forces')}
local warned = false
function M.getCapabilities() return capabilities.get() end
local function disc()
  local data = love.image.newImageData(32,32)
  data:mapPixel(function(x,y)
    local d = math.sqrt(((x+0.5)/32-0.5)^2+((y+0.5)/32-0.5)^2)*2
    local t = math.max(0, 1-d)
    return 1,1,1,t*t*(3-2*t)
  end)
  local image = love.graphics.newImage(data)
  data:release()
  return image
end
function M.newEmitter(input)
  local c = config.normalize(input)
  local needsState = c.collision or c.circleCollider or (c.attractors and #c.attractors>0) or c.flowField
  for _, force in ipairs(c.forces) do needsState = needsState or force.stateful end
  if c.mode == 'analytic' and needsState then
    error('gpuparticles: this effect requires stateful mode (collision, attractors, flowField or stateful force)',2)
  end
  local mode = c.mode == 'auto' and (needsState and 'stateful' or 'analytic') or c.mode
  local compiled = M.forces.compose(c.forces, mode)
  local caps = M.getCapabilities()
  local e = setmetatable({config=c, mode=mode, capabilities=caps, time=0, cursor=1,
    running=true, paused=false, released=false, compiledForces=compiled, texture=c.texture or disc(), ownsTexture=not c.texture}, E)
  if caps[mode] then
    e.backend='gpu'
    e.driver=require(prefix..mode)
    local ok,reason=pcall(e.driver.new,e)
    if ok then return e end
    require(prefix..'resources').release(e)
    e.fallbackReason='GPU initialization failed: '..tostring(reason)
  else e.fallbackReason='required GPU capabilities unavailable for '..mode end
  e.backend='native'
  e.driver=require(prefix..'native')
  if not warned then
    print('gpuparticles: using native ParticleSystem; '..e.fallbackReason..'. GPU-only forces are omitted.')
    warned=true
  end
  local ok,reason=pcall(e.driver.new,e)
  if not ok then
    if e.native then e.native:release() end
    if e.ownsTexture then e.texture:release() end
    error(reason,2)
  end
  return e
end
return M
