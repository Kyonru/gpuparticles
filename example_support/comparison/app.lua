local prefix=(...):gsub('example_support%.comparison%.app$','')
local Model=require(prefix..'example_support.comparison.model')
local View=require(prefix..'example_support.comparison.view')
local M={}
function M.install()
  local model,view,smoke,capture,requested,captured,benchmark=nil,nil,false,false,false,false,false
  local frames=0
  local mouseDemo=false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
    if value=='--benchmark' then benchmark=true end
    if value=='--mouse-collision' then mouseDemo=true end
  end
  mouseDemo=mouseDemo and not benchmark
  function love.load()
    love.window.setMode(1280,800,{resizable=true,minwidth=960,minheight=700,vsync=0})
    love.window.setTitle('LÖVE vs GPU — matched particle comparison')
    model=Model.new();view=View.new()
    if mouseDemo then model:setMouseCollision(true) end
    if benchmark then model:startBenchmark() end
  end
  function love.update(dt)
    if mouseDemo and smoke and not benchmark then model:setPointer(256,215,true)
    else model:setPointer(view:mapPointer(love.mouse.getPosition())) end
    if mouseDemo and smoke and frames==1 then model:clearMeasurement() end
    model:update(dt,mouseDemo and smoke and 1/60 or nil);frames=frames+1
    local done=benchmark and model.benchmarkDone or (not benchmark and frames>=(mouseDemo and 120 or 30))
    if smoke and done and (not capture or captured) then print('Comparison standalone render PASS');love.event.quit() end
  end
  function love.draw()
    local shownBenchmark,shownFPS=model.benchmark,model.fps
    model:renderTargets();view:draw(model);model:finishFrame()
    if capture and not requested and frames>=(mouseDemo and 90 or 5) and (not mouseDemo or shownFPS>0) and (not benchmark or (model.benchmarkDone and not shownBenchmark and shownFPS>0)) then
      requested=true
      love.graphics.captureScreenshot(function(data)
        local file=mouseDemo and not benchmark and 'comparison-mouse.png' or 'comparison.png'
        data:encode('png',file);data:release()
        print('COMPARISON_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end
  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='1' then model.benchmark=nil;model:setView('native')
    elseif key=='2' then model.benchmark=nil;model:setView('gpu')
    elseif key=='3' then model.benchmark=nil;model:setView('both')
    elseif key=='b' then model:startBenchmark()
    elseif key=='up' then model:changeCapacity(1)
    elseif key=='down' then model:changeCapacity(-1)
    elseif key=='[' then model:changeSize(-1)
    elseif key==']' then model:changeSize(1)
    elseif key=='m' then model:toggleMode()
    elseif key=='c' then model:setMouseCollision(not model.mouseCollision)
    elseif key=='space' then model.paused=not model.paused;model.benchmark=nil;model:clearMeasurement()
    elseif key=='r' then model:rebuild() end
  end
  function love.wheelmoved(_,y) model:changeRadius(y*4) end
  function love.quit() if model then model:release() end;if view then view:release() end end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return M
