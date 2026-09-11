local gpu=require('gpuparticles')
local function near(a,b,epsilon) assert(math.abs(a-b)<(epsilon or 1e-5),('expected %.9f, got %.9f'):format(b,a)) end
local function run()
  local e=gpu.newEmitter{max=100000,rate=100000,lifetime=2,position={32,32},sizes={3},colors={{1,1,1,1}}}
  assert(e:getMode()=='analytic' and e:getBackend()=='gpu')
  e:warm(1)
  assert(e:getCount()==100000)
  local target=love.graphics.newCanvas(64,64,{format='rgba32f'})
  love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0)
  local stats={};love.graphics.getStats(stats);local before=stats.drawcalls
  e:draw()
  love.graphics.getStats(stats);assert(stats.drawcalls-before==1,'analytic must use one draw call')
  love.graphics.setCanvas()
  local data=target:newImageData();local r=data:getPixel(32,32);assert(r>0,'analytic must render')
  data:release();target:release()
  local function updates() for _=1,10000 do e:update(0.001) end end
  updates();updates()
  collectgarbage('collect');collectgarbage('stop')
  local memory=collectgarbage('count')
  updates()
  near(collectgarbage('count'),memory,0.01)
  collectgarbage('restart')
  print('Analytic 100k / one draw / allocation-free update PASS')
  print(('100k build %.3f ms; upload %.3f ms'):format(e.buildTime*1000,e.uploadTime*1000))
  e:release();e:release()
  local burst=gpu.newEmitter{max=100000,rate=0,lifetime=10,speed={10,20},seed=42}
  local untouched={burst.instances:getVertex(513)}
  local at=love.timer.getTime();burst:emit(512)
  print(('512-record burst %.3f ms'):format((love.timer.getTime()-at)*1000))
  assert(burst:getCount()==512)
  local after={burst.instances:getVertex(513)}
  for i=1,#after do near(after[i],untouched[i]) end
  burst.cursor=99900;burst:emit(512)
  assert(burst.cursor==412,'ring cursor must wrap')
  assert(burst:getCount()==613,'only the overwritten ring slice changes')
  burst:release()
  print('Burst offset / wrap / untouched records PASS')
  local f1=gpu.newEmitter{max=4,forces={gpu.forces.turbulence{amplitude=10},gpu.forces.curl{amplitude=2}}}
  local f2=gpu.newEmitter{max=4,forces={gpu.forces.curl{amplitude=99},gpu.forces.turbulence{amplitude=50}}}
  assert(f1:getMode()=='analytic' and f2:getMode()=='analytic')
  assert(f1.shader==f2.shader,'same force set must share a shader regardless of values or order')
  for _=1,3 do f1:update(1/60);f1:draw();f2:draw() end
  f1:release();f2:draw();f2:release()
  local good,message=pcall(gpu.newEmitter,{forces={{kind='collision'}}})
  assert(not good and message:find('unsupported force'))
  print('Force composition / cache / mode / reference release PASS')
  require('tests.stateful').run()
  require('tests.circle').run()
  require('tests.selfcollision').run()
  require('tests.api').run()
  require('tests.numeric').run()
  require('tests.graphics').run()
end
function love.load()
  local success,err=xpcall(run,debug.traceback)
  if success then print('ALL TESTS PASS') else print(err) end
  love.event.quit(success and 0 or 1)
end
function love.errorhandler(message) print(message);return function() return 1 end end
return {near=near}
