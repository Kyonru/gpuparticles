local Model=require('example_support.comparison.model')
local View=require('example_support.comparison.view')
local M={}
local function near(a,b,tolerance) assert(math.abs(a-b)<tolerance,('comparison expected %.6f, got %.6f'):format(b,a)) end
local function moments(target)
  local data=target:newImageData()
  local weight,sumY=0,0
  for y=0,511 do for x=0,511 do
    local _,_,b=data:getPixel(x,y)
    local value=math.max(0,b-16/255)
    weight=weight+value;sumY=sumY+y*value
  end end
  data:release();return weight,sumY/weight
end
local function imageDifference(a,b)
  local first,second=a:newImageData(),b:newImageData()
  local difference=0
  for y=0,511,2 do for x=0,511,2 do
    local ar,ag,ab=first:getPixel(x,y)
    local br,bg,bb=second:getPixel(x,y)
    difference=difference+math.abs(ar-br)+math.abs(ag-bg)+math.abs(ab-bb)
  end end
  first:release();second:release();return difference
end
function M.run()
  local c=Model.new{capacityIndex=1,quiet=true}
  assert(c.native:typeOf('ParticleSystem'),'left side must be the actual native ParticleSystem')
  assert(c.gpu:getBackend()=='gpu' and c.gpu:getMode()=='analytic')
  assert(c.native:getTexture()==c.texture and c.gpu.texture==c.texture,'both systems must use the same texture')
  near(c.native:getEmissionRate(),c.gpu:getEmissionRate(),0.001)
  near(c.native:getParticleLifetime(),2,0.0001)
  near(c.native:getSizes()*16,c.gpu.config.sizes[1],0.0001)
  assert(c.native:getCount()>c.capacity*0.95 and c.gpu:getCount()==c.capacity)
  c:renderTargets()
  local nativeLight,nativeY=moments(c.targets.native)
  local gpuLight,gpuY=moments(c.targets.gpu)
  assert(nativeLight>100 and gpuLight>100,'both systems must render visible particles')
  near(gpuLight/nativeLight,1,0.15);near(nativeY,gpuY,6)
  print('Comparison real native backend / shared texture / matched settings / image distribution PASS')
  local nativeSystem,gpuSystem=c.native,c.gpu
  c:setAfterimage(true)
  assert(c.native==nativeSystem and c.gpu==gpuSystem,'postprocessing must not rebuild either particle system')
  for _=1,8 do c:update(1/30);c:renderTargets() end
  local trailFrame=love.graphics.newCanvas(512,512,{dpiscale=1,msaa=0})
  love.graphics.setCanvas(trailFrame);love.graphics.setBlendMode('replace','premultiplied');love.graphics.draw(c.targets.gpu);love.graphics.setCanvas();love.graphics.setBlendMode('alpha')
  c:setAfterimage(false);c:renderTargets()
  assert(imageDifference(trailFrame,c.targets.gpu)>1,'afterimage history must change the rendered image')
  c:setBlur(true);c:renderTargets()
  local sharpFrame=love.graphics.newCanvas(512,512,{dpiscale=1,msaa=0})
  c:setBlur(false);c:renderTargets()
  love.graphics.setCanvas(sharpFrame);love.graphics.setBlendMode('replace','premultiplied');love.graphics.draw(c.targets.gpu);love.graphics.setCanvas();love.graphics.setBlendMode('alpha')
  c:setBlur(true);c:renderTargets()
  assert(imageDifference(sharpFrame,c.targets.gpu)>1,'two-pass blur must change the rendered image')
  c:setBlur(false);trailFrame:release();sharpFrame:release()
  assert(c.native==nativeSystem and c.gpu==gpuSystem,'postprocessing toggles must preserve simulation state')
  print('Comparison afterimage history / separable blur / no-rebuild toggles PASS')
  for _=1,60 do c:update(0.01);c:renderTargets();c:finishFrame() end
  near(c.fps,100,0.001)
  assert(not c.results.native and not c.results.gpu,'shared FPS must not be presented as separate per-system FPS')
  c:setView('native')
  local previous=c.gpu.time
  for _=1,60 do c:update(0.01);c:renderTargets();c:finishFrame() end
  near(c.gpu.time,previous,0.00001);near(c.results.native,100,0.001)
  assert(c.cost.gpu.update==0 and c.cost.gpu.draw==0,'inactive GPU must incur no simulation/draw measurement')
  c:setView('gpu')
  for _=1,60 do c:update(0.01);c:renderTargets();c:finishFrame() end
  assert(c.cost.native.update==0 and c.cost.native.draw==0,'inactive native system must incur no measured work')
  near(c.results.gpu,100,0.001)
  c.paused=true
  for _=1,6 do c:update(0.2);c:renderTargets();c:finishFrame() end
  near(c.fps,5,0.001);near(c.results.gpu,100,0.001)
  c.paused=false
  print('Comparison shared FPS / isolated views / inactive-system gating / paused measurement PASS')
  c:startBenchmark()
  for _=1,65 do c:update(0.1);c:renderTargets();c:finishFrame() end
  assert(c.benchmarkDone and not c.benchmark and c.view=='both')
  near(c.results.native,10,0.001);near(c.results.gpu,10,0.001)
  print('Comparison isolated benchmark phases / FPS arithmetic PASS')
  c:toggleMode();assert(c.gpu:getMode()=='stateful')
  assert(not c.results.native and not c.results.gpu,'configuration changes invalidate old benchmark results')
  local before=c.gpu.stateA;c:update(1/60);assert(c.gpu.stateA~=before)
  c:changeSize(1);near(c.native:getSizes()*16,c.gpu.config.sizes[1],0.0001)
  c:toggleMode();assert(c.gpu:getMode()=='analytic')
  c:setMouseCollision(true);assert(c.gpu:getMode()=='stateful' and not c.results.native)
  local view=View.new()
  for _,name in ipairs{'native','gpu'} do
    for _,width in ipairs{960,1280,1600} do
      local x,y,size=view:particleViewport(name,width,800)
      local wx,wy,inside=view:mapPointer(x+size/2,y+size/4,width,800)
      assert(inside);near(wx,256,0.001);near(wy,128,0.001)
    end
  end
  local _,_,inside=view:mapPointer(5,5,1280,800);assert(not inside);view:release()
  c:setPointer(256,215,true)
  local instances=c.gpu.instances;c:changeRadius(8);assert(c.gpu.instances==instances)
  near(c.gpu.config.circleCollider.radius,56,0.001)
  for _=1,120 do c:update(1/120) end
  local data=c.gpu.stateA:newImageData()
  local nearEdge=0
  for i=0,c.capacity-1 do
    local x,y=data:getPixel(i%c.gpu.texSize,math.floor(i/c.gpu.texSize))
    local distance=math.sqrt((x-256)^2+(y-215)^2)
    assert(distance>=56+c.size/2-0.01,'GPU particles must stay outside the mouse radius')
    if distance<60 then nearEdge=nearEdge+1 end
  end
  data:release();assert(nearEdge>0,'mouse obstacle must intercept the stream')
  c:setPointer(nil,nil,false);assert(not c.gpu.config.circleCollider.enabled)
  c:setPointer(256,215,true);c:startBenchmark()
  assert(not c.mouseCollision and c.gpu:getMode()=='analytic','matched benchmark must disable mouse collision and restore the selected mode')
  print('Comparison pointer mapping / live radius / bulk mouse collision / benchmark restoration PASS')
  c:release();c:release()
  print('Comparison stateful toggle / size parity / release PASS')
  require('tests.comparison_self').run()
end
function M.install()
  function love.load()
    local ok,err=xpcall(M.run,debug.traceback)
    if not ok then print(err) end
    love.event.quit(ok and 0 or 1)
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
