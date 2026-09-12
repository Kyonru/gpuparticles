function love.errorhandler(message) print(message);return function() return 1 end end
local gpu=require('gpuparticles')
local noFFI=false
for _,value in ipairs(arg or {}) do if value=='--no-ffi' then noFFI=true end end
local function sync(canvas)
  local data=canvas:newImageData();data:release()
end
local function measure(config,width,height,samples)
  config.noFFI=noFFI
  local start=love.timer.getTime()
  local e=gpu.newEmitter(config)
  assert(e:getBackend()=='gpu' and e:getMode()=='analytic')
  local creation=love.timer.getTime()-start
  e:warm(3)
  local canvas=love.graphics.newCanvas(width,height,{dpiscale=1,msaa=0})
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,1)
  for _=1,4 do e:draw() end
  love.graphics.pop();sync(canvas)
  love.graphics.push('all');love.graphics.setCanvas(canvas)
  start=love.timer.getTime()
  for _=1,samples do e:draw() end
  local submitted=love.timer.getTime()-start
  love.graphics.pop();sync(canvas)
  local completed=love.timer.getTime()-start
  local build,upload,live=e.buildTime,e.uploadTime,e:getCount()
  e:release();canvas:release()
  return build*1000,upload*1000,submitted*1000/samples,completed*1000/samples,creation*1000,live
end
local function run()
  local caps=gpu.getCapabilities()
  print(('LÖVE %s | %s'):format(table.concat(caps.version,'.'),table.concat(caps.renderer,' / ')))
  print('Lua: '.._VERSION..' | JIT: '..tostring(jit and jit.status())..' | noFFI: '..tostring(noFFI))
  print('All times are milliseconds. GPU completion is wall time including one amortized readback, not a GPU timer query.')
  print('512x512, 3px soft discs, uniform coverage, 40 draws per sample batch')
  print('Particles | Build Lua | Upload mesh | Submit/frame | Completed/frame | Total create')
  for _,n in ipairs{10000,50000,100000,250000} do
    local build,upload,submit,complete,creation=measure({max=n,rate=n,lifetime=1,position={256,256},sizes={3},colors={{1,1,1,0.1}},
      emissionArea={distribution='uniform',x=255,y=255,angle=0}},512,512,40)
    print(('%9d | %9.3f | %11.3f | %12.3f | %15.3f | %12.3f'):format(n,build,upload,submit,complete,creation))
  end
  print('1920x1080, 50k soft discs, uniform coverage, 12 draws per sample batch')
  print('Size px | Submit/frame | Completed/frame')
  for _,size in ipairs{3,16,48} do
    local _,_,submit,complete=measure({max=50000,rate=50000,lifetime=1,position={960,540},sizes={size},colors={{1,70/255,122/255,0.2}},
      emissionArea={distribution='uniform',x=950,y=530,angle=0}},1920,1080,12)
    print(('%7d | %12.3f | %15.3f'):format(size,submit,complete))
  end
  local _,_,submit,complete,_,live=measure({max=50000,rate=16000,lifetime={1,3},position={960,920},direction=-math.pi/2,spread=0.7,
    speed={80,220},gravity={0,-40},damping=0.4,sizes={4,10,0},colors={{1,213/255,30/255,1},{1,70/255,122/255,0.7},{80/255,3/255,192/255,0}}},1920,1080,12)
  print(('Example plume at 1080p: %d live, submit %.3f ms, completed %.3f ms'):format(live,submit,complete))
  local burst=gpu.newEmitter{max=100000,lifetime=5,noFFI=noFFI}
  for _=1,8 do burst:emit(512) end
  local start=love.timer.getTime()
  for _=1,50 do burst:emit(512) end
  print(('512-particle burst (build + sliced upload): %.3f ms average'):format((love.timer.getTime()-start)*1000/50))
  local data=require('gpuparticles.records').build(burst,1,512,false)
  start=love.timer.getTime()
  for _=1,50 do burst.instances:setVertices(data,20000,512) end
  print(('512-particle sliced upload only: %.3f ms average'):format((love.timer.getTime()-start)*1000/50))
  if type(data)=='userdata' then data:release() end
  burst:release()
end
function love.load()
  local ok,err=xpcall(run,debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
function love.errorhandler(message) print(message);return function() return 1 end end
