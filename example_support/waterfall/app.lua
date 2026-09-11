local prefix=(...):gsub('example_support%.waterfall%.app$','')
local Scene=require(prefix..'example_support.waterfall.scene')
local M={}
function M.viewport(width,height)
  local scale=math.min(width/1280,height/800)
  return scale,(width-1280*scale)/2,(height-800*scale)/2
end
function M.mapPointer(x,y,width,height)
  local scale,left,top=M.viewport(width,height)
  x,y=(x-left)/scale,(y-top)/scale
  return x,y,x>=0 and x<=1280 and y>=0 and y<=800
end
function M.install()
  local scene,smoke,capture,captured,requested,frames=nil,false,false,false,false,0
  local mouseDemo,plantDemo,selfDemo=false,false,false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
    if value=='--mouse-collision' then mouseDemo=true end
    if value=='--plant-collision' then mouseDemo=true;plantDemo=true end
    if value=='--self-collision' then selfDemo=true end
  end
  local function restart()
    local contacts=selfDemo
    if scene then contacts=scene.selfCollision end
    if scene then scene:release() end
    scene=Scene.new{selfCollision=contacts};scene:warm(3.1)
  end
  function love.load() restart() end
  function love.update(dt)
    if smoke then scene:setPointer(plantDemo and 482 or 580,plantDemo and 288 or 225,mouseDemo)
    else
      local x,y=love.mouse.getPosition()
      scene:setPointer(M.mapPointer(x,y,love.graphics.getDimensions()))
    end
    scene:update(smoke and 1/60 or dt)
    frames=frames+1
    if smoke and frames>=(mouseDemo and 120 or 6) and (not capture or captured) then
      print('Waterfall standalone render PASS');love.event.quit()
    end
  end
  function love.draw()
    local g=love.graphics
    g.clear(0.018,0.04,0.055)
    local w,h=g.getDimensions()
    local scale,left,top=M.viewport(w,h)
    g.push('all');g.translate(left,top);g.scale(scale)
    scene:draw();g.pop()
    if capture and frames>=(mouseDemo and 90 or 3) and love.timer.getFPS()>0 and not requested then
      requested=true
      g.captureScreenshot(function(data)
        local file=selfDemo and (mouseDemo and 'waterfall-self-mouse.png' or 'waterfall-self.png') or plantDemo and 'waterfall-plants.png' or mouseDemo and 'waterfall-mouse.png' or 'waterfall.png'
        data:encode('png',file);data:release()
        print('WATERFALL_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file)
        captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='space' then scene.paused=not scene.paused
    elseif key=='r' then restart()
    elseif key=='h' then scene.showHud=not scene.showHud
    elseif key=='1' then scene.layers.curtain=not scene.layers.curtain
    elseif key=='2' then scene.layers.drops=not scene.layers.drops
    elseif key=='3' then scene.layers.mist=not scene.layers.mist
    elseif key=='d' then scene.layers.field=not scene.layers.field end
    if key=='c' then scene:toggleMouse() end
    if key=='s' then scene:setSelfCollision(not scene.selfCollision) end
    if key=='w' then scene:toggleWind() end
  end
  function love.wheelmoved(_,y) scene:changeRadius(y*4) end
  function love.quit() if scene then scene:release() end end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
