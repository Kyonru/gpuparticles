local gpu=require('gpuparticles')
local M={}
function M.run()
  local w=assert(gpu.newVolumeWorld{width=64,height=64,cellSize=2})
  local water=w:addMaterial{name='water',model='water'}
  local smoke=w:addMaterial{name='smoke',model='gas'}
  local source=w:newSource{material=smoke,position={30,48},radius=5,rate=100}
  w:newSource{material=water,position={5,5},rate=10}
  source:setTemperature(2)
  w:warm(0.5);w:update(1/60)
  local c=love.graphics.newCanvas(64,64)
  love.graphics.setCanvas(c);love.graphics.clear();w:draw();love.graphics.setCanvas()
  c:release();w:release();w:release()
  print('Volume API water / gas compile and render PASS')
  require('tests.volume_controls').run()
  require('tests.volume_gas').run()
  require('tests.volume_extensions').run()
end
function M.install()
  function love.load()
    local ok,err=xpcall(M.run,debug.traceback);love.graphics.setCanvas()
    if not ok then print(err) end
    love.event.quit(ok and 0 or 1)
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
