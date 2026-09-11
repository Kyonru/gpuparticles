local Scene=require('example_support.waterfall.scene')
local gpu=require('gpuparticles')
local T={}
function T.run()
  local scene=Scene.new{render=false,selfCollision=true}
  local e=scene.drops
  assert(scene.selfCollision and e.config.selfCollision and e.selfPacked,'waterfall must enable particle contacts')
  assert(e.config.max==24000 and e.config.rate==6000,'waterfall self collision must keep the full emitted count')
  assert(e:getMode()=='stateful' and e:getBackend()=='gpu')
  scene:changeRadius(5);scene:setPointer(580,225,true)
  -- Keep identical passes and terrain projection; a negligible radius removes pair contacts.
  local config=require('gpuparticles.config').copy(e.config);config.selfCollision.radius=0.000001
  local baseline=gpu.newEmitter(config)
  for _=1,math.floor(3.1/Scene.step+0.5) do baseline:update(Scene.step) end
  scene:warm(3.1)
  local a,b=e.stateA:newImageData(),baseline.stateA:newImageData()
  local changed,alive=0,0
  for i=1,e.config.max do
    if e.births[i]<=e.emissionTime and e.time-e.births[i]<e.lives[i] then
      local x,y,vx,vy=a:getPixel((i-1)%e.texSize,math.floor((i-1)/e.texSize))
      local bx,by=b:getPixel((i-1)%e.texSize,math.floor((i-1)/e.texSize))
      assert(x==x and y==y and vx==vx and vy==vy,'waterfall contacts must remain finite')
      assert(scene.terrain:distance(x,y)>-0.5,'waterfall contacts must preserve rock collision')
      assert((x-580)^2+(y-225)^2>51.49^2,'waterfall contacts must preserve mouse collision')
      if math.abs(x-bx)+math.abs(y-by)>0.01 then changed=changed+1 end
      alive=alive+1
    end
  end
  a:release();b:release();baseline:release()
  assert(alive>18000 and changed>100,'waterfall self collision must change the actual droplet stream')
  local field,spray,mist,time=scene.terrain.field,scene.spray[1],scene.mist[1],scene.time
  local oldCanvas=e.selfPacked;local count=e:getCount()
  scene.paused=true;scene.layers.curtain=false;scene:setSelfCollision(false)
  assert(not scene.selfCollision and not scene.drops.selfPacked and scene.drops.config.max==24000 and scene.drops.config.rate==6000)
  assert(scene.drops:getCount()==count,'waterfall toggle must preserve the warmed particle count')
  assert(not pcall(oldCanvas.getWidth,oldCanvas),'waterfall toggle must release old contact resources')
  assert(scene.emitters[1]==scene.drops and #scene.emitters==7,'waterfall toggle must replace the updated emitter')
  assert(scene.drops.config.circleCollider.enabled and scene.drops.config.circleCollider.radius==50)
  assert(scene.terrain.field==field and scene.spray[1]==spray and scene.mist[1]==mist and scene.time==time and scene.paused and not scene.layers.curtain,
    'waterfall toggle must preserve scenery, decoration, clock, and controls')
  assert(spray:getMode()=='analytic' and mist:getMode()=='analytic')
  e=scene.drops;scene:setSelfCollision(false);assert(scene.drops==e,'unchanged contact mode must not rebuild')
  scene:setSelfCollision(true);assert(scene.drops.selfPacked and scene.drops.config.max==24000 and scene.drops.config.rate==6000)
  assert(scene.drops:getCount()==count,'enabling waterfall contacts must preserve the warmed particle count')
  local before=scene.drops.time;scene.paused=false;scene:update(0.25)
  assert(math.abs(scene.drops.time-before-2*Scene.step)<0.00001,'waterfall must bound overloaded frames to two simulation steps')
  assert(scene.accumulator<Scene.step,'waterfall must discard excess catch-up work')
  scene:release();scene:release()
  print('Waterfall self collision / 24000 slots and 6000 per second in both modes / live count parity / numeric contact / bounded catch-up / release PASS')
end
return T
