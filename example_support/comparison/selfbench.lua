local prefix=(...):gsub('example_support%.comparison%.selfbench$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local Preset=require(prefix..'example_support.comparison.particle_preset')
local B={}
local function sync(canvas)
  local data=canvas:newImageData();data:release()
end
local function measure(capacity,iterations,texture,target)
  local g=love.graphics
  local e=gpu.newEmitter(Preset.config(capacity,12,iterations,iterations>0,texture))
  assert(e:getBackend()=='gpu' and e:getMode()=='stateful','completed-work benchmark requires the GPU stateful backend')
  e:warm(241/60);sync(e.stateA)
  local function batch(draw)
    local measurements={}
    for sample=1,3 do
      g.push('all');g.origin();g.setCanvas(target);g.setShader();g.setScissor();g.setColor(1,1,1,1)
      local start=love.timer.getTime()
      for _=1,30 do
        e:update(1/120)
        if draw then g.clear(palette.deep);e:draw() end
      end
      g.pop();sync(draw and target or e.stateA)
      measurements[sample]=(love.timer.getTime()-start)*1000/30
    end
    table.sort(measurements);return measurements[2]
  end
  local simulation,frame=batch(false),batch(true)
  local live=e:getCount();e:release();return simulation,frame,live
end
function B.run()
  local counts=Preset.capacities
  for _,argument in ipairs(arg or {}) do
    local count=tonumber(argument:match('^%-%-count=(%d+)$'))
    if count then
      local supported=false
      for _,capacity in ipairs(Preset.capacities) do if capacity==count then supported=true end end
      assert(supported,'Unsupported particle count; choose '..table.concat(Preset.capacities,', ')..'.')
      counts={count}
    end
  end
  local caps=gpu.getCapabilities()
  print(('LÖVE %s | %s'):format(table.concat(caps.version,'.'),table.concat(caps.renderer,' / ')))
  print('Self collision: same seeded stream and floor as the comparison, 512x512, 12px discs, 1/120 s per step.')
  print('Completed wall milliseconds: median of three 30-step batches, each ending with one amortized readback. Not GPU timer queries.')
  print('Capacity | Iterations | Live | Simulation ms | Update + draw ms')
  local texture=Preset.texture();local target=love.graphics.newCanvas(512,512,{dpiscale=1,msaa=0})
  for _,capacity in ipairs(counts) do for _,iterations in ipairs{0,1,2,4} do
    local simulation,frame,live=measure(capacity,iterations,texture,target)
    print(('%8d | %10d | %4d | %13.4f | %16.4f'):format(capacity,iterations,live,simulation,frame))
  end end
  target:release();texture:release();print('Self collision completed-work benchmark PASS')
end
function B.install()
  function love.load() local ok,err=xpcall(B.run,debug.traceback);if not ok then print(err) end;love.event.quit(ok and 0 or 1) end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return B
