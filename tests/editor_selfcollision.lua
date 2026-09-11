local App=require('editor_support.app')
local D=require('editor_support.document')
local J=require('editor_support.json')
local R=require('editor_support.runtime')
local S=require('editor_support.storage')
local T={}
function T.run()
  local old=D.new();old.layers[1].selfCollision=nil
  assert(not S.decode(J.encode(old)).layers[1].selfCollision.enabled,'old projects must default to self collision off')
  local app=App.new();local m=app.model;m:replace(D.new());m.playing=false;m.tab='Motion'
  local function widget(id)
    m.scroll=0;app:draw()
    while true do
      for _,w in ipairs(app.ui.items) do if w.id==id and w.h>=40 then return w end end
      assert(m.scroll<m.scrollMax,'missing self collision control '..id);m.scroll=math.min(m.scroll+80,m.scrollMax);app:draw()
    end
  end
  local function click(id)
    local w=widget(id);local x,y=w.x+w.w/2,w.y+w.h/2;app:mousepressed(x,y,1);app:mousereleased(x,y,1)
  end
  local capacity=m:layer().emitter.max;local history=#m.undoStack
  assert(widget('selfCollision.enabled') and m.scroll==0,'self collision must be visible at the top of Motion')
  click('selfCollision.enabled')
  assert(m:layer().selfCollision.enabled and m:layer().emitter.max==2048,'editor self collision must enforce its advertised capacity')
  assert(#m.undoStack==history+1,'enabling self collision and reducing capacity must be one edit')
  m.tab='Emitter';assert(widget('emitter.max').scrub.max==2048,'capacity input must respect the self collision limit')
  m:history(false);assert(not m:layer().selfCollision.enabled and m:layer().emitter.max==capacity)
  m:history(true);assert(m:layer().selfCollision.enabled and m:layer().emitter.max==2048)
  assert(not m:change(function(_,l) l.emitter.max=2049 end),'editor must reject oversized self collision buffers')
  m:change(function(_,l)
    l.emitter.max=4;l.emitter.rate=0;l.emitter.lifetime={2,2};l.emitter.speed={0,0};l.emitter.gravity={0,0}
    l.emitter.emissionArea.distribution='none';l.emitter.position={32,32};l.bursts={{time=0,count=4}}
  end)
  m.tab='Motion';click('selfCollision.iterations');app.ui:textinput('2');app:keypressed('return')
  while m.pending>0 or m.seekTarget do m:update(0.2) end
  assert(m.runtime.emitters[1]:getMode()=='stateful' and m.runtime.emitters[1].config.selfCollision.iterations==2,'editor must pass self collision settings to its emitter')
  for _,argument in ipairs(arg or {}) do if argument=='--self-capture' then
    local g=love.graphics;local oldW,oldH=g.getDimensions()
    for _,size in ipairs{{1440,900},{1120,760}} do
      love.window.setMode(size[1],size[2],{vsync=0});widget('selfCollision.iterations')
      local canvas=g.newCanvas(size[1],size[2],{dpiscale=1})
      g.push('all');g.setCanvas(canvas);app:draw();g.pop()
      local data=canvas:newImageData();local file='editor-self-'..size[1]..'.png';data:encode('png',file);data:release();canvas:release()
      print('EDITOR_SELF_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file)
    end
    love.window.setMode(oldW,oldH,{vsync=0})
  end end
  local doc=S.decode(J.encode(m.doc));local original=R.new(doc);local exported=assert(loadstring(S.exportSource(doc)))().new()
  original:seek(0.2);exported:seek(0.2)
  local a=original.emitters[1].stateA:newImageData();local b=exported.emitters[1].stateA:newImageData()
  for y=0,1 do for x=0,1 do
    local aa,bb={a:getPixel(x,y)},{b:getPixel(x,y)}
    for i=1,4 do assert(math.abs(aa[i]-bb[i])<0.0001,'self collision export must match preview state') end
  end end
  a:release();b:release();original:release();exported:release()
  click('selfCollision.enabled');while m.pending>0 or m.seekTarget do m:update(0.2) end
  assert(m.runtime.emitters[1]:getMode()=='analytic','disabling the only stateful feature must restore analytic mode')
  m.dirty=false;app:open('presets');app:draw()
  local preset
  for _,w in ipairs(app.ui.items) do if w.id=='preset:7' then preset=w end end
  assert(preset and preset.y>=0 and preset.y+preset.h<love.graphics.getHeight(),'self collision preset must fit in the preset dialog')
  app:mousepressed(preset.x+20,preset.y+20,1);app:mousereleased(preset.x+20,preset.y+20,1)
  assert(not app.modal and m.tab=='Motion' and m.scroll==0 and m:layer().selfCollision.enabled,'contact preset must open its controls')
  while m.pending>0 or m.seekTarget do m:update(0.2) end
  assert(m.runtime.emitters[1].selfPacked and m.runtime.emitters[1].config.max==1024,'contact preset must run the GPU solver')
  app:release()
  print('Editor self collision toggle / capacity clamp and undo / legacy projects / export state parity / automatic mode restoration PASS')
end
return T
