local App=require('editor_support.app')
local D=require('editor_support.document')
local S=require('editor_support.storage')
local R=require('editor_support.runtime')
local T={}
local function near(a,b,label)
  assert(math.abs(a-b)<0.0001,('%s: expected %.6f, got %.6f'):format(label or 'numeric input',b,a))
end
function T.run()
  local app=App.new();local m=app.model
  local doc=D.new();doc.layers[1].emitter.max=16;doc.layers[1].emitter.rate=0
  m:replace(doc);m.playing=false
  while m.seekTarget do m:update(0.1) end
  local function find(id)
    for _,w in ipairs(app.ui.items) do if w.id==id and w.h>=32 then return w end end
  end
  local function show(id)
    m.scroll=0;app:draw()
    while not find(id) and m.scroll<m.scrollMax do m.scroll=math.min(m.scroll+80,m.scrollMax);app:draw() end
    return assert(find(id),'missing numeric control '..id)
  end
  local function press(id)
    local w=show(id);local x,y=w.x+w.w/2,w.y+w.h/2
    app:mousepressed(x,y,1);return x,y
  end
  local function click(id)
    local x,y=press(id);app:mousereleased(x,y,1)
  end
  local function typeNumber(id,value)
    click(id);app.ui:textinput(tostring(value));app:keypressed('return')
  end
  local function drag(id,dx,dy)
    local x,y=press(id);app:mousemoved(x+dx,y+dy);app:mousereleased(x+dx,y+dy,1)
  end
  m.tab='Motion'
  local before=#m.undoStack;local x,y=press('emitter.damping')
  app:mousemoved(x+2,y+1);app:mousereleased(x+2,y+1,1)
  assert(app.ui.edit and #m.undoStack==before,'small hand movement must remain a typing click')
  app.ui:textinput('2');app:keypressed('return');near(m:layer().emitter.damping,2)
  before=#m.undoStack;local builds=m.builds
  x,y=press('emitter.damping');app:mousemoved(x+10,y)
  near(m:layer().emitter.damping,2.2,'input body horizontal drag')
  app:draw();app:mousemoved(x+20,y);near(m:layer().emitter.damping,2.4)
  m:update(0.2);assert(m.builds==builds and #m.undoStack==before,'numeric drag must defer rebuild and undo until release')
  app:mousereleased(x+20,y,1)
  assert(not app.ui.edit and #m.undoStack==before+1 and not m.before,'drag must commit once without opening text entry')
  m:history(false);near(m:layer().emitter.damping,2);m:history(true);near(m:layer().emitter.damping,2.4)
  drag('emitter.damping',0,-10);near(m:layer().emitter.damping,2.6,'vertical numeric drag')
  drag('emitter.damping',0,10);near(m:layer().emitter.damping,2.4)
  drag('emitter.damping:scrub',-10,0);near(m:layer().emitter.damping,2.2,'label drag remains usable')
  before=#m.undoStack;click('emitter.damping');drag('emitter.damping',10,0)
  near(m:layer().emitter.damping,2.4);assert(#m.undoStack==before+1,'focusing a number before dragging must not add a redundant edit')
  -- Bounds must be reached safely and reversing must respond without retracing the overshoot.
  x,y=press('emitter.damping');app:mousemoved(x+5000,y)
  near(m:layer().emitter.damping,20,'numeric drag maximum clamp')
  app:mousemoved(x+4990,y);near(m:layer().emitter.damping,19.8,'numeric drag reversal at maximum')
  app:mousemoved(x-5000,y);near(m:layer().emitter.damping,0,'numeric drag minimum clamp')
  app:mousemoved(x-4990,y);near(m:layer().emitter.damping,0.2,'numeric drag reversal at minimum')
  app:mousereleased(x-4990,y,1)
  before=#m.undoStack;x,y=press('emitter.damping');app:mousemoved(x+100,y)
  app:keypressed('escape');app:mousereleased(x+100,y,1)
  near(m:layer().emitter.damping,0.2)
  assert(not m.before and not app.modal and #m.undoStack==before,'Escape must cancel the drag without undo or quit')
  x,y=press('emitter.damping');app:mousemoved(x+10,y);app:mousemoved(x,y);app:mousereleased(x,y,1)
  near(m:layer().emitter.damping,0.2);assert(#m.undoStack==before,'returning to the initial value must not create an undo entry')
  -- Shift changes sensitivity during the gesture without jumping to a new baseline.
  x,y=press('emitter.damping');app:mousemoved(x+10,y)
  local isDown=love.keyboard.isDown
  love.keyboard.isDown=function(...) if (...)=='lshift' then return true end;return isDown(...) end
  app:mousemoved(x+20,y);love.keyboard.isDown=isDown
  near(m:layer().emitter.damping,0.42,'fine numeric drag');app:mousereleased(x+20,y,1)
  -- Committing text then grabbing the same field must start from the entered value.
  click('emitter.damping');app.ui:textinput('3')
  local w=find('emitter.damping');x,y=w.x+w.w/2,w.y+w.h/2
  app:mousepressed(x,y,1);app:mousemoved(x+10,y);app:mousereleased(x+10,y,1)
  near(m:layer().emitter.damping,3.2,'drag after typing')
  app:draw();app:keypressed('up');near(m:layer().emitter.damping,3.3)
  app:draw();app:keypressed('down');near(m:layer().emitter.damping,3.2)
  typeNumber('emitter.damping',21);assert(app.ui.edit and app.ui.edit.error);near(m:layer().emitter.damping,3.2);app:keypressed('escape')
  m.tab='Emitter'
  drag('emitter.lifetime.1',1000,0);near(m:layer().emitter.lifetime[1],m:layer().emitter.lifetime[2],'paired numeric maximum')
  drag('emitter.lifetime.2',0,1000);near(m:layer().emitter.lifetime[2],m:layer().emitter.lifetime[1],'paired numeric minimum')
  drag('emitter.max',7,0);assert(m:layer().emitter.max==156 and m:layer().emitter.max%1==0,'integer input must remain integral')
  drag('emitter.seed',4,0);assert(m:layer().emitter.seed==43,'integer input must round fractional drag steps')
  drag('emitter.direction',10,0);near(m:layer().emitter.direction,-80*math.pi/180,'degree input conversion')
  before=#m.undoStack;x,y=press('layer:name');app:mousemoved(x+10,y);app:mousereleased(x+10,y,1)
  assert(app.ui.edit and app.ui.edit.id=='layer:name' and #m.undoStack==before,'text fields must retain text editing');app:keypressed('escape')
  -- Shared number controls without live model callbacks (curve stops and project settings).
  m.tab='Style';before=#m.undoStack
  drag('color:1',-100,0);near(m:layer().emitter.colors[m.colorStop][1],0.8)
  assert(#m.undoStack==before+1,'color channel drag must be one edit')
  drag('size:value',10,0);near(m:layer().emitter.sizes[m.sizeStop],5)
  app:open('project');before=#m.undoStack
  drag('project:duration',0,-20);near(m.doc.duration,7)
  assert(#m.undoStack==before+1,'modal numeric drag must be one edit');app:close()
  print('Editor numeric click / four-direction drag / limits / reversal / precision / cancel / undo / typed and keyboard entry PASS')

  m.tab='Motion';m:layer().attractor.enabled=true
  near(tonumber(show('attractor.strength').value),90,'attractor readable strength')
  drag('attractor.strength',10,0);near(m:layer().attractor.strength,920000)
  typeNumber('attractor.strength',1001);assert(app.ui.edit and app.ui.edit.error);app:keypressed('escape')
  drag('attractor.strength',10000,0);near(m:layer().attractor.strength,10000000)
  drag('attractor.strength',-10000,0);near(m:layer().attractor.strength,-10000000)
  for _,strength in ipairs{90,-90,0} do
    typeNumber('attractor.strength',strength);near(m:layer().attractor.strength,strength*10000,'attractor typed conversion')
    local definition=S.decode(require('editor_support.json').encode(m.doc));local l=definition.layers[1]
    near(l.attractor.strength,strength*10000,'attractor saved coefficient')
    l.emitter.position={100,0};l.emitter.speed={0,0};l.emitter.gravity={0,0};l.emitter.damping=0
    l.emitter.emissionArea.distribution='none';l.attractor.x=0;l.attractor.y=0
    local original=R.new(definition);local exported=assert(loadstring(S.exportSource(definition)))().new()
    for _,effect in ipairs{original,exported} do
      local e=effect.emitters[1];assert(e:getMode()=='stateful');e:emit(1);e:update(1/60)
      local data=e.stateA:newImageData();local px,py,vx,vy=data:getPixel(0,0);data:release()
      near(vx,-strength/60,'attractor calibrated GPU acceleration');near(px,100-strength/3600)
      near(py,0);near(vy,0);effect:release()
    end
  end
  typeNumber('attractor.strength',90)
  for _,argument in ipairs(arg or {}) do if argument=='--numeric-capture' then
    local g=love.graphics;local oldW,oldH=g.getDimensions()
    for _,size in ipairs{{1440,900},{1120,760}} do
      love.window.setMode(size[1],size[2],{vsync=0});show('attractor.softening')
      local canvas=g.newCanvas(size[1],size[2]);g.push('all');g.setCanvas(canvas);app:draw();g.pop()
      local data=canvas:newImageData();local file='editor-numbers-'..size[1]..'.png';data:encode('png',file);data:release();canvas:release()
      print('EDITOR_NUMBERS_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file)
    end
    love.window.setMode(oldW,oldH,{vsync=0})
  end end
  app:release()
  print('Editor attractor scale / coefficient persistence / numeric GPU pull and repulsion / export parity PASS')
end
return T
