local prefix=(...):gsub('example_support%.runner$','')
local effects=require(prefix..'example_support.effects')
local M={}
function M.install(selected,automated)
  local hasEditor=love.filesystem.getInfo('editor_support/app.lua')~=nil
  local index=1
  for i,name in ipairs(effects.names) do if name==selected then index=i end end
  local smoke,frames=false,0
  for _,value in ipairs(arg or {}) do if value=='--smoke' then smoke=true end end
  local emitter,owned
  local function release()
    if emitter then emitter:release() end
    for _,image in ipairs(owned or {}) do image:release() end
    emitter,owned=nil,nil
  end
  local function load()
    release();emitter,owned=effects.create(effects.names[index],love.graphics.getDimensions());emitter:warm(2)
  end
  function love.load()
    if automated then
      local ok,err=xpcall(function()
        for _,name in ipairs(effects.names) do
          local e,images=effects.create(name,960,640)
          e:emit(512);e:warm(0.2);e:update(1/60)
          local target=love.graphics.newCanvas(960,640)
          love.graphics.setCanvas(target);love.graphics.clear(0,0,0,0);e:draw();love.graphics.setCanvas()
          local data=target:newImageData()
          local sum=0
          for y=0,639,8 do for x=0,959,8 do local r,g,b=data:getPixel(x,y);sum=sum+r+g+b end end
          assert(sum>0,name..' must render nonempty output')
          data:release();target:release();e:release()
          for _,image in ipairs(images) do image:release() end
          print('Example '..name..' mode / render PASS')
        end
      end,debug.traceback)
      if not ok then print(err) end
      love.event.quit(ok and 0 or 1)
    else load() end
  end
  function love.update(dt)
    if emitter then emitter:update(math.min(dt,1/30)) end
    if smoke then
      frames=frames+1
      if frames==5 then print('Standalone example '..effects.names[index]..' PASS');love.event.quit() end
    end
  end
  function love.draw()
    if not emitter then return end
    local g=love.graphics
    g.clear(0.018,0.022,0.035)
    emitter:draw()
    g.setColor(0.85,0.9,1,1);g.print(effects.names[index]:upper(),24,24)
    g.setColor(0.48,0.68,0.72);g.print(('%s · %s · %s particles'):format(
      emitter:getMode(),emitter:getBackend(),emitter:getBufferSize()),24,45)
    local controls='Left/Right Effect   Space Burst   R Reset   C Compare   W Waterfall   V Volumes'
    if hasEditor then controls=controls..'   E Editor' end
    g.setColor(0.48,0.62,0.69);g.print(controls..'   Esc',24,g.getHeight()-28)
    local name=effects.names[index]
    if name=='collision' then love.graphics.line(0,love.graphics.getHeight()-80,love.graphics.getWidth(),love.graphics.getHeight()-80)
    elseif name=='sdf' then love.graphics.circle('line',love.graphics.getWidth()/2,love.graphics.getHeight()/2,90) end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='space' then emitter:emit(512)
    elseif key=='right' or key=='left' then index=(index-1+(key=='right' and 1 or -1))%#effects.names+1;load()
    elseif key=='c' or key=='w' then
      release()
      require(prefix..'example_support.'..(key=='c' and 'comparison' or 'waterfall')..'.app').install()
      love.load()
    elseif key=='r' then load() end
    if key=='e' and hasEditor then release();require('editor_support.app').install();love.load() end
    if key=='v' then release();require(prefix..'example_support.volume.app').install();love.load() end
  end
  function love.quit() release() end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
