local prefix=(...):gsub('example_support%.library%.app$','')
local catalog=require(prefix..'example_support.library.catalog')
local Particles=require(prefix..'example_support.library.particles')
local Volumes=require(prefix..'example_support.library.volumes')
local palette=require(prefix..'example_support.palette')
local GifCapture=require(prefix..'example_support.gif_capture')

local A={}

function A.install()
  local sidebar=252
  local index,scene,frames,cycleFrames=1,nil,0,0
  local titleFont,textFont,smallFont
  local smoke,capture,requested,captured=false,false,false,false
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true end
    if value=='--capture' then capture=true end
    local preset=value:match('^%-%-preset=([%w%-]+)$')
    if preset then for i,item in ipairs(catalog) do if item.id==preset then index=i end end end
  end
  local gif=GifCapture.new('effect-library',{start=24,every=5,count=24})

  local function dimensions()
    local width,height=love.graphics.getDimensions()
    return math.max(320,width-sidebar),height
  end

  local function loadScene()
    if scene then scene:release() end
    local width,height=dimensions();local item=catalog[index]
    scene=item.volume and Volumes.new(item.id,width,height,smoke) or Particles.new(item.id,width,height)
    cycleFrames=0
  end

  local function select(nextIndex)
    index=(nextIndex-1)%#catalog+1
    loadScene()
  end

  function love.load()
    titleFont=love.graphics.newFont(26);textFont=love.graphics.newFont(13);smallFont=love.graphics.newFont(11)
    loadScene()
  end

  function love.resize() loadScene() end

  function love.update(dt)
    frames=frames+1;cycleFrames=cycleFrames+1
    dt=smoke and 1/60 or math.min(dt,1/30)
    local width,height=dimensions();local mx,my=love.mouse.getPosition()
    if scene.setPointer then scene:setPointer(mx-sidebar,my,mx>=sidebar and mx<=sidebar+width and my>=0 and my<=height) end
    scene:update(dt)
    if gif and (scene.kind=='fire' or scene.kind=='weather') and (cycleFrames==8 or cycleFrames==16) then scene:action() end
    if gif and scene.kind=='explosions' and cycleFrames==12 then scene:burstAt(width*0.68,height*0.42) end
    if smoke then
      if capture then
        if captured then print('Effect library standalone render PASS');love.event.quit() end
      else
        local interval=gif and 24 or 8
        if cycleFrames>=interval then
          if index==#catalog then
            if not gif or gif.done then print('Effect library standalone render PASS');love.event.quit() end
          else select(index+1) end
        end
      end
    end
  end

  local function sidebarDraw(g,height)
    g.setColor(palette.deep);g.rectangle('fill',0,0,sidebar,height)
    g.setFont(titleFont);g.setColor(palette.beige);g.print('Effect library',20,18)
    g.setFont(smallFont);g.setColor(palette.blue);g.print(#catalog..' COPYABLE RECIPES',21,52)
    local y=82
    for i,item in ipairs(catalog) do
      if i==index then
        g.setColor(palette.blue[1],palette.blue[2],palette.blue[3],0.2);g.rectangle('fill',10,y-5,sidebar-20,29,5,5)
        g.setColor(palette.peach)
      else g.setColor(palette.teal) end
      g.print(('%02d  %s'):format(i,item.title),20,y)
      y=y+32
    end
    g.setColor(palette.blue);g.print('Up/Down Browse   Space Action',20,height-50);g.print('R Reset   Esc Quit',20,height-30)
  end

  function love.draw()
    local g=love.graphics;local width,height=love.graphics.getDimensions();local item=catalog[index]
    g.clear(palette.ink)
    g.push('all');g.setScissor(sidebar,0,width-sidebar,height);scene:draw(sidebar,0);g.pop()
    sidebarDraw(g,height)
    local panelWidth=math.min(560,width-sidebar-36)
    g.setColor(palette.deep[1],palette.deep[2],palette.deep[3],0.88);g.rectangle('fill',sidebar+18,18,panelWidth,88,6,6)
    g.setFont(smallFont);g.setColor(palette.peach);g.print(item.group,sidebar+32,30)
    g.setFont(titleFont);g.setColor(palette.beige);g.print(item.title,sidebar+31,45)
    g.setFont(textFont);g.setColor(palette.teal);g.print(item.note,sidebar+32,76)
    g.setColor(palette.blue);g.print(item.api,sidebar+32,94)
    g.setColor(palette.deep[1],palette.deep[2],palette.deep[3],0.86);g.rectangle('fill',sidebar+18,height-48,width-sidebar-36,30,5,5)
    g.setColor(palette.beige)
    local control=scene.controls and scene:controls() or item.id=='terrain' and 'LMB paint · RMB erase' or item.id=='smoke' and 'Move mouse to stir' or item.id=='steam' and 'Click to add heat' or 'Click or Space to emit'
    local measured=love.timer.getFPS();local fps=measured>0 and measured..' FPS' or 'FPS ...'
    g.print(control..'  ·  '..fps,sidebar+30,height-39)
    if gif then gif:draw(frames) end
    local captureFrame=item.id=='steam' and 180 or 60
    if capture and frames>=captureFrame and not requested then
      requested=true
      g.captureScreenshot(function(data)
        local file='library-'..item.id..'.png';data:encode('png',file);data:release()
        print('LIBRARY_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file);captured=true
      end)
    end
  end

  function love.keypressed(key)
    if key=='escape' then love.event.quit()
    elseif key=='down' or key=='right' then select(index+1)
    elseif key=='up' or key=='left' then select(index-1)
    elseif key=='space' then scene:action()
    elseif key=='r' then loadScene()
    else
      local number=tonumber(key)
      if number and number>=1 and number<=9 then select(number) end
    end
  end

  function love.mousepressed(x,y,button)
    if x>=sidebar then scene:mousepressed(x-sidebar,y,button) end
  end
  function love.mousereleased(x,y,button)
    if x>=sidebar then scene:mousereleased(x-sidebar,y,button) end
  end
  function love.wheelmoved(_,y) if y~=0 then select(index+(y<0 and 1 or -1)) end end

  function love.quit()
    if scene then scene:release() end
    for _,font in ipairs{titleFont,textFont,smallFont} do if font then font:release() end end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end

return A
