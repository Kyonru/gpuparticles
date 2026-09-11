local Scene=require('example_support.waterfall.scene')
local gpu=require('gpuparticles')
local App=require('example_support.waterfall.app')
local M={}
local function near(a,b,tolerance)
  assert(math.abs(a-b)<(tolerance or 0.06),('waterfall expected %.6f, got %.6f'):format(b,a))
end
local function state(e)
  assert(love.graphics.getCanvas()~=e.stateA,'unbind before reading particle state')
  local data=e.stateA:newImageData()
  local x,y,vx,vy=data:getPixel(0,0);data:release()
  return x,y,vx,vy
end
local function sampleTotal(data)
  local sum=0
  for y=88,697,3 do for x=520,830,3 do
    local r,g,b=data:getPixel(x,y);sum=sum+r+g+b
  end end
  return sum
end
local function render(scene)
  local target=love.graphics.newCanvas(1280,800,{dpiscale=1,msaa=0})
  love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.origin();scene:draw(false);love.graphics.pop()
  local data=target:newImageData();target:release();return data
end
function M.run()
  require('tests.plants').run()
  local scene=Scene.new()
  local terrain=scene.terrain
  assert(scene.drops:getMode()=='stateful' and scene.drops:getBackend()=='gpu')
  for _,e in ipairs(scene.spray) do assert(e:getMode()=='analytic') end
  for _,e in ipairs(scene.mist) do assert(e:getMode()=='analytic') end
  assert(terrain:distance(551,360)<-20 and terrain:distance(804,533)<-30)
  assert(terrain:distance(580,200)>30)
  local function shot(index,enabled)
    local x,y,nx,ny=terrain:surface(index)
    local config={max=1,mode='stateful',lifetime=2,position={x+nx*12,y+ny*12},
      speed=180,direction=math.atan2(-ny,-nx)}
    if enabled then config.collision={type='sdf',texture=terrain.field,size={1280,800},radius=2,bounce=0.25} end
    local e=gpu.newEmitter(config);e:emit(1);e:update(0.1)
    local px,py,vx,vy=state(e);e:release()
    if enabled then
      near(px,x+nx*2);near(py,y+ny*2);near(vx,nx*45,0.2);near(vy,ny*45,0.2)
      near(terrain:distance(px,py),2)
    else
      assert(terrain:distance(px,py)<-5,'disabled collider control must penetrate the rock')
    end
  end
  shot(1,true);shot(2,true);shot(1,false);shot(2,false)
  print('Waterfall SDF / both sloped ledges / bounce / disabled-collision control PASS')
  scene:warm(3.1)
  local e=scene.drops
  local data=e.stateA:newImageData()
  local inspected,lower,collided=0,0,0
  local bins={};for i=1,8 do bins[i]={count=0,x=0} end
  for i=1,e.config.max,7 do
    if e.births[i]<=e.emissionTime and e.time-e.births[i]<e.lives[i] then
      local x,y,vx,vy=data:getPixel((i-1)%e.texSize,math.floor((i-1)/e.texSize))
      assert(x==x and y==y and vx==vx and vy==vy,'particle state must stay finite')
      assert(terrain:distance(x,y)>-1,'active waterfall particles must remain outside the rocks')
      inspected=inspected+1
      if y>570 then lower=lower+1 end
      if math.abs(vx)>30 and y>320 then collided=collided+1 end
      local b=bins[math.max(1,math.min(8,math.floor(y/100)+1))]
      b.count=b.count+1;b.x=b.x+x
    end
  end
  data:release()
  assert(inspected>1000 and collided>100,'waterfall must carry a substantial colliding stream')
  assert(lower>10,'water must reach the lower cascade')
  for i,b in ipairs(bins) do if b.count>0 then print(('Waterfall y %d..%d: %d samples, mean x %.1f'):format((i-1)*100,i*100,b.count,b.x/b.count)) end end
  print('Waterfall fixed-step / bulk GPU state / flow to lower cascade PASS')
  scene.layers.curtain=false;scene.layers.drops=false;scene.layers.mist=false
  data=render(scene);local baseline=sampleTotal(data);data:release()
  scene.layers.curtain=true;data=render(scene);local sheet=sampleTotal(data);data:release()
  assert(sheet>baseline+250,'animated water curtain must visibly contribute')
  scene.layers.curtain=false;scene.layers.drops=true;data=render(scene);local drops=sampleTotal(data);data:release()
  assert(drops>baseline+30,'GPU droplets must render independently of the curtain')
  scene.layers.drops=false;scene.layers.mist=true;data=render(scene);local mist=sampleTotal(data);data:release()
  assert(mist>baseline+15,'spray and mist must contribute independently')
  for _,width in ipairs{960,1280,1600} do
    local scale,left,top=App.viewport(width,800)
    local x,y,inside=App.mapPointer(left+580*scale,top+225*scale,width,800)
    near(x,580);near(y,225);assert(inside)
    local _,_,outside=App.mapPointer(-1,0,width,800);assert(not outside)
  end
  scene:setPointer(580,225,true)
  assert(e.config.circleCollider.enabled and e.config.collision.type=='sdf')
  local field=scene.terrain.field
  scene:changeRadius(5);near(e.config.circleCollider.radius,50)
  for _=1,120 do scene:stepOnce() end
  assert(scene.terrain.field==field,'moving obstacle must not rebuild the environment field')
  data=e.stateA:newImageData()
  for i=1,e.config.max,11 do
    local age=(e.emissionTime-e.births[i])%(e.config.max/e.config.rate)
    if age<e.lives[i] then
      local x,y=data:getPixel((i-1)%e.texSize,math.floor((i-1)/e.texSize))
      assert(math.sqrt((x-580)^2+(y-225)^2)>51.49,'waterfall droplets must avoid the mouse radius')
    end
  end
  data:release();scene:toggleMouse();assert(not e.config.circleCollider.enabled)
  scene:toggleMouse();scene:setPointer(nil,nil,false);assert(not e.config.circleCollider.enabled)
  print('Waterfall pointer scaling / mouse collision / radius / field reuse / disable PASS')
  local time=scene.time;scene.paused=true;scene:update(0.1);near(scene.time,time,0.00001)
  scene:toggleWind();assert(not scene.wind and scene.render.frontPlants.wind==0 and scene.render.backPlants.wind==0)
  scene:toggleWind();assert(scene.wind and scene.render.frontPlants.wind==1)
  local plants=scene.render.frontPlants
  scene:setPointer(plants.plants[1].x-10,plants.plants[1].y-25,true)
  for _=1,120 do scene:stepOnce() end
  assert(math.abs(plants.plants[1].bx)+math.abs(plants.plants[1].by)>1,'scene circle must reach the plant springs')
  scene:release();scene:release()
  print('Waterfall independent layers / modes / pause / release PASS')
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
