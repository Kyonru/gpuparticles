local gpu = require('gpuparticles')
function love.load()
  local caps = gpu.getCapabilities()
  assert(caps.instancing and caps.glsl3 and caps.formats.rgba32f)
  print('Capability detection PASS: '..table.concat(caps.renderer, ' / '))
  local real = gpu.getCapabilities
  gpu.getCapabilities = function() local c=real(); c.analytic=false; c.stateful=false; return c end
  local emitter = gpu.newEmitter{max=100,rate=100,lifetime=1,position={32,32},sizes={16},colors={{1,1,1,1}},blendMode='alpha'}
  assert(emitter:getBackend() == 'native')
  assert(emitter:getMode() == 'analytic')
  emitter:warm(0.5)
  assert(emitter:getCount() > 0)
  local canvas=love.graphics.newCanvas(64,64)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0,0,0,0)
  emitter:draw()
  love.graphics.setCanvas()
  local data=canvas:newImageData()
  local _,_,_,a=data:getPixel(32,32)
  assert(a>0, 'fallback must draw visible particles')
  emitter:release();data:release()
  local stateful=gpu.newEmitter{max=16,collision={type='plane',y=64},position={32,32},sizes={16},lifetime=1}
  assert(stateful:getMode()=='stateful' and stateful:getBackend()=='native')
  stateful:setCircleCollider(32,32,20);stateful:setCircleCollider()
  stateful:emit(8);stateful:update(0.1)
  love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0);stateful:draw();love.graphics.setCanvas()
  data=canvas:newImageData();local r=data:getPixel(32,32);assert(r>0,'stateful capability fallback must draw')
  stateful:release();data:release();canvas:release()
  gpu.getCapabilities=real
  print('Native fallback draw for both selected modes PASS')
  love.event.quit(0)
end
function love.errorhandler(message) print(message); return function() return 1 end end
