local gpu=require('gpuparticles')
local M={}
local function near(a,b,epsilon,label)
  assert(math.abs(a-b)<(epsilon or 1e-5),('%s: expected %.6f, got %.6f'):format(label or 'depth',b,a))
end
local function pixel(canvas,x,y)
  assert(love.graphics.getCanvas()~=canvas,'readback must happen after unbinding')
  local data=canvas:newImageData();local a,b,c,d=data:getPixel(x or 0,y or 0);data:release()
  return a,b,c,d
end
local function total(canvas)
  local data=canvas:newImageData();local sum={0,0,0,0}
  data:mapPixel(function(_,_,r,g,b,a) sum[1]=sum[1]+r;sum[2]=sum[2]+g;sum[3]=sum[3]+b;sum[4]=sum[4]+a;return r,g,b,a end)
  data:release()
  return sum
end
local function render(e,passes)
  local target=love.graphics.newCanvas(96,96,{format='rgba32f'})
  love.graphics.push('all');love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0)
  for _,options in ipairs(passes) do e:draw(0,0,options~=false and options or nil) end
  love.graphics.pop()
  local sum=total(target);target:release()
  return sum
end
local function halvesAddUp(e,range,label)
  local full=render(e,{false})
  local split=render(e,{{cut='behind',range=range},{cut='front',range=range}})
  local behind=render(e,{{cut='behind',range=range}})
  local front=render(e,{{cut='front',range=range}})
  for i=1,4 do near(split[i],full[i],math.max(1e-3,full[i]*1e-4),label..' depth halves channel '..i) end
  -- Additive blending leaves destination alpha alone, so measure the drawn colour instead.
  local function light(sum) return sum[1]+sum[2]+sum[3] end
  assert(light(behind)>0 and light(front)>0,label..': each depth half must draw part of the emitter')
  assert(light(behind)<light(full) and light(front)<light(full),label..': neither depth half may draw the whole emitter')
end

function M.run()
  -- Opt-in: without depth there are no z textures, the shader variants are the plain ones,
  -- and state memory is the five record/state textures alone.
  local plain=gpu.newEmitter{max=64,mode='stateful',lifetime=10}
  assert(plain.depthA==nil and plain.depthB==nil,'an emitter without depth must not allocate z textures')
  assert(plain.shaderKey=='render:','an emitter without depth must keep the plain render shader')
  assert(plain.simShaderKey=='simulate:'..(plain.compiledForces.key or ''),'an emitter without depth must keep the plain simulation shader')
  local texels=plain.texSize*plain.texSize
  assert(plain:getStateMemory()==texels*80,'plain stateful memory must be five rgba32f textures')
  local orbiting=gpu.newEmitter{max=64,lifetime=10,depth={orbit=2}}
  assert(orbiting:getMode()=='stateful','simulated depth must select stateful mode')
  assert(orbiting.depthA and orbiting.depthB,'simulated depth must allocate its z pair')
  local extra=orbiting:getStateMemory()-plain:getStateMemory()
  assert(extra==texels*16 or extra==texels*32,'simulated depth must add only its z pair, got '..extra..' bytes')
  assert(orbiting.shader~=plain.shader and orbiting.simShader~=plain.simShader,'z emitters must use their own variants')
  plain:release();orbiting:release()
  assert(orbiting.depthA==nil and orbiting.depthB==nil,'release must free the z pair')

  -- A driver may advertise rg32f but reject it beside rgba32f. The format probe must
  -- fall back without leaking its graphics-state push.
  if love.graphics.getCanvasFormats().rg32f then
    local setCanvas=love.graphics.setCanvas
    local stackDepth=love.graphics.getStackDepth()
    love.graphics.setCanvas=function(...)
      if select('#',...)==2 then error('simulated mixed-format rejection') end
      return setCanvas(...)
    end
    local ok,fallback=pcall(gpu.newEmitter,{max=4,lifetime=1,depth={orbit=1}})
    love.graphics.setCanvas=setCanvas
    assert(ok,fallback)
    assert(fallback.depthA:getFormat()=='rgba32f' and fallback.depthB:getFormat()=='rgba32f',
      'mixed-format rejection must use rgba32f depth textures')
    assert(love.graphics.getStackDepth()==stackDepth,
      'mixed-format fallback must leave the graphics stack balanced')
    fallback:release()
  end
  print('Depth opt-in allocation / plain variants / state memory / release PASS')

  -- One step: born moving round the axis at the orbit rate, pulled back towards it.
  local e=gpu.newEmitter{max=1,lifetime=10,position={1,0},depth={axis=0,orbit=2}}
  e:emit(1);e:update(0.01)
  local x,_,vx=pixel(e.stateA)
  local z,vz=pixel(e.depthA)
  near(vx,-0.04,1e-5,'depth orbit x velocity');near(x,0.9996,1e-5,'depth orbit x')
  near(vz,2,1e-5,'depth orbit z velocity');near(z,0.02,1e-5,'depth orbit z')
  -- Half a revolution later it is on the far side of the axis.
  for _=1,math.floor((math.pi/2-0.01)*240+0.5) do e:update(1/240) end
  x=pixel(e.stateA);z=pixel(e.depthA)
  near(x,-1,0.02,'depth half orbit x');near(z,0,0.02,'depth half orbit z')
  e:release()
  print('Depth orbit numeric step / half revolution PASS')

  -- A respawn restores birth z, not the z it had reached.
  e=gpu.newEmitter{max=1,lifetime=10,position={1,0},direction=math.pi/2,speed=10,
    collision={type='plane',y=0.5},collisionResponse='respawn',depth={axis=0,orbit=2}}
  e:emit(1);e:update(0.1)
  z,vz=pixel(e.depthA)
  near(z,0,1e-5,'respawn depth z');near(vz,2,1e-5,'respawn depth z velocity')
  e:release()
  print('Depth birth values on respawn PASS')

  -- Depth code: a formula, so the emitter stays analytic and holds no state.
  local code='return sin(seed*6.2831853+age*3.0)*20.0;'
  local ring={max=4000,rate=4000,lifetime=1,position={48,48},emissionArea={distribution='uniform',x=40,y=40},
    sizes={6},colors={{0.2,0.4,0.6,0.5}},depth={code=code,tilt=0.25}}
  local a1,a2=gpu.newEmitter(ring),gpu.newEmitter(ring)
  assert(a1:getMode()=='analytic' and a1:getStateMemory()==0,'depth code must stay analytic and hold no state')
  assert(a1.shader==a2.shader,'emitters with the same depth code must share a shader')
  a1:warm(0.5)
  halvesAddUp(a1,20,'analytic')
  a2:release()
  local simulated=gpu.newEmitter{max=4000,rate=4000,lifetime=2,position={48,48},
    emissionArea={distribution='uniform',x=30,y=30},sizes={6},colors={{0.2,0.4,0.6,0.5}},
    depth={orbit={2,3},tilt=0.2}}
  simulated:warm(1)
  halvesAddUp(simulated,15,'stateful')
  simulated:release()
  print('Depth code variants / complementary behind and front halves PASS')

  local flat=gpu.newEmitter{max=4}
  assert(not pcall(flat.draw,flat,0,0,{cut='front'}),'depth options on an emitter without depth must fail')
  assert(not pcall(a1.draw,a1,0,0,{cut='sideways'}),'an unknown depth cut must fail')
  assert(not pcall(a1.draw,a1,0,0,{cut='front',range=0}),'a zero depth range must fail')
  assert(not pcall(gpu.newEmitter,{mode='analytic',depth={orbit=1}}),'explicit analytic mode cannot simulate depth')
  assert(not pcall(gpu.newEmitter,{depth={code='return 0.0;',orbit=1}}),'depth code cannot be mixed with simulated depth')
  assert(not pcall(gpu.newEmitter,{depth=true}),'depth must be a table')
  flat:release();a1:release()
  local resized=gpu.newEmitter{max=16,depth={orbit=1}}
  resized:setBufferSize(100)
  assert(resized.depthA and resized.depthA:getWidth()==resized.texSize,'the z pair must follow a buffer resize')
  resized:release()
  print('Depth validation / buffer resize PASS')
end
return M
