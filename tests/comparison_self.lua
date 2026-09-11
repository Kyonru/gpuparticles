local Model=require('example_support.comparison.model')
local T={}
function T.run()
  local c=Model.new{capacityIndex=1,quiet=true};local originalSize=c.sizeIndex
  c.particleCapacityIndex=1;c:setParticleCollision(true)
  assert(c.capacity==256 and c.particleCollision and c.gpu:getMode()=='stateful' and c.native:getMode()=='stateful')
  assert(c.gpu:getBackend()=='gpu' and c.native:getBackend()=='gpu','self comparison must use GPU on both sides')
  assert(not c.native.config.selfCollision and c.gpu.config.selfCollision,'self comparison must isolate the particle collision feature')
  for _,k in ipairs{'max','seed','rate'} do assert(c.native.config[k]==c.gpu.config[k],'self comparison must match '..k) end
  assert(c.native.config.collision.y==c.gpu.config.collision.y and c.native.texture==c.gpu.texture)
  c:renderTargets();local a,b=c.native.stateA:newImageData(),c.gpu.stateA:newImageData();local changed=0
  for i=0,255 do
    local x,y=i%c.gpu.texSize,math.floor(i/c.gpu.texSize);local ax,ay=a:getPixel(x,y);local bx,by=b:getPixel(x,y)
    if math.abs(ax-bx)+math.abs(ay-by)>0.01 then changed=changed+1 end
  end
  a:release();b:release();assert(changed>20,'particle contacts must visibly change the comparison stream')
  c:setView('gpu');local before=c.native.time;c:update(1/60);c:renderTargets();c:finishFrame()
  assert(c.native.time==before and c.samples.native.update==0 and c.samples.native.draw==0,'isolated self comparison must skip the other system')
  c:changeIterations();assert(c.iterations==2 and c.gpu.config.selfCollision.iterations==2 and not c.results.gpu)
  c:setMouseCollision(true);c:setPointer(256,215,true)
  assert(c.native.config.circleCollider.enabled and c.gpu.config.circleCollider.enabled,'both self-comparison systems must share mouse obstacles')
  c:startBenchmark();assert(c.particleCollision and not c.mouseCollision,'benchmark must keep self comparison and disable the moving obstacle')
  before=c.native.time;c:update(0.1);assert(math.abs(c.native.time-before-1/120)<0.00001,'self benchmark must use one fixed simulation step per frame')
  c:renderTargets();c:finishFrame()
  for _=1,65 do c:update(0.1);c:renderTargets();c:finishFrame() end
  assert(c.benchmarkDone and math.abs(c.results.native-10)<0.001 and math.abs(c.results.gpu-10)<0.001)
  c:changeCapacity(1);assert(c.capacity==512 and not c.results.native and not c.results.gpu,'count changes must clear self comparison measurements')
  c.iterations=1;c:changeCapacity(100)
  assert(c.capacity==10000 and c.native:getCount()==10000 and c.gpu:getCount()==10000,'comparison must support 10000 live particles on both sides')
  assert(c.gpu:getBackend()=='gpu' and c.gpu.selfPacked,'10000 particles must retain GPU self collision')
  local emitter=c.gpu;c:changeCapacity(1);assert(c.gpu==emitter,'clamped counts must not rebuild the expensive simulation')
  c:setView('both');before=c.gpu.time;c:update(0.25)
  assert(math.abs(c.gpu.time-before-1/60)<0.00001,'overloaded preview must limit catch-up to two small steps')
  c:renderTargets();c:finishFrame()
  local state=c.gpu.stateA:newImageData()
  for i=0,9999 do
    local x,y,vx,vy=state:getPixel(i%c.gpu.texSize,math.floor(i/c.gpu.texSize))
    assert(math.abs(x)<10000 and math.abs(y)<10000 and math.abs(vx)<10000 and math.abs(vy)<10000,'10000-particle contacts must remain finite and bounded')
    assert(y<=466.001,'10000-particle contacts must preserve floor collision')
  end
  state:release();c:changeCapacity(-1);assert(c.capacity==5000,'comparison must offer the 5000-particle step')
  c:setParticleCollision(false);assert(c.capacity==1000 and c.sizeIndex==originalSize and c.gpu:getMode()=='analytic','leaving self comparison must restore regular settings')
  c:release()
  print('Comparison self collision off/on / 10000 live particles / bounded GPU state and preview catch-up / count limits / isolation / fixed-step benchmark / control restoration PASS')
end
return T
