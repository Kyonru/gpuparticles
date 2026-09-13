local config = require((...):gsub('emitter$', 'config'))
local E = {}
E.__index = E
function E:_check() assert(not self.released, 'gpuparticles: emitter is released') end
function E:getMode() return self.mode end
function E:getBackend() return self.backend end
function E:getFallbackReason() return self.fallbackReason end
function E:update(dt)
  self:_check()
  config.number(dt, 'dt', 0)
  self.driver.update(self, dt)
end
function E:draw(x, y, options)
  self:_check()
  if options ~= nil then
    assert(type(options) == 'table', 'gpuparticles: draw options must be a table')
    assert(self.config.depth, 'gpuparticles: draw depth options need an emitter created with depth')
    assert(options.cut == nil or options.cut == 'behind' or options.cut == 'front',
      "gpuparticles: depth cut must be 'behind' or 'front'")
    if options.range ~= nil then config.number(options.range, 'depth range', 0.000001) end
    if options.size ~= nil then config.number(options.size, 'depth size') end
    if options.dim ~= nil then config.number(options.dim, 'depth dim', 0) end
  end
  self.driver.draw(self, x, y, options)
end
function E:getStateMemory()
  self:_check()
  return self.driver.stateMemory and self.driver.stateMemory(self) or 0
end
function E:emit(n)
  self:_check()
  n = config.number(n, 'emit count', 0)
  assert(n%1 == 0, 'gpuparticles: emit count must be an integer')
  if not self.running then return self end
  if self.native then self.native:emit(n) else self.driver.emit(self, n) end
  return self
end
function E:getCount()
  self:_check()
  if self.native then return self.native:getCount() end
  return self.driver.count(self)
end
function E:warm(seconds)
  self:_check()
  config.number(seconds, 'warm duration', 0)
  if self.driver.warm then self.driver.warm(self, seconds)
  else
    while seconds > 0 do local dt = math.min(seconds, 1/60); self:update(dt); seconds = seconds-dt end
  end
  return self
end
function E:release()
  if self.released then return end
  self.driver.release(self)
  if self.ownsTexture then self.texture:release() end
  self.released = true
end
function E:setPosition(x,y)
  self:_check()
  self.config.position = {config.number(x,'x'),config.number(y,'y')}
  if self.native then self.native:setPosition(x,y) end
  return self
end
function E:getPosition() return unpack(self.config.position) end
require((...):gsub('emitter$','setters')).install(E)
return E
