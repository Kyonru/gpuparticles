local D=require('editor_support.document')
local J=require('editor_support.json')
local P=require('editor_support.presets')
local R=require('editor_support.runtime')
local S=require('editor_support.storage')
local Model=require('editor_support.model')
local App=require('editor_support.app')
local View=require('editor_support.view')
local T={}
local function near(a,b) assert(math.abs(a-b)<0.001,('editor expected %.6f, got %.6f'):format(b,a)) end
local function finish(model)
  local count=0
  repeat model:update(0.2);count=count+1;assert(count<200,'editor seek must finish') until not model.seekTarget and model.pending<=0
end
local function state(e,index)
  local data=e.stateA:newImageData();local x,y,vx,vy=data:getPixel(index%e.texSize,math.floor(index/e.texSize));data:release()
  return x,y,vx,vy
end
local function render(effect)
  local g=love.graphics;local canvas=g.newCanvas(960,640,{format='rgba32f',dpiscale=1})
  g.push('all');g.setCanvas(canvas);g.origin();g.setColor(1,1,1,1);g.clear(0,0,0,0);effect:draw();g.pop()
  local data=canvas:newImageData();canvas:release();return data
end
function T.run()
  love.window.setMode(1280,800,{vsync=0})
  for i=1,4 do
    local doc=P.make(i);local decoded=S.decode(J.encode(doc));assert(J.encode(doc)==J.encode(decoded))
    local effect=R.new(doc);effect:seek(i==4 and 0.35 or 1.5)
    for j,e in ipairs(effect.emitters) do assert(e:getMode()==(i==3 and j==1 and 'stateful' or 'analytic'),'presets must use their cheapest mode') end
    local data=render(effect);local sum=0
    for y=0,639,8 do for x=0,959,8 do local r,g,b=data:getPixel(x,y);sum=sum+r+g+b end end
    data:release();assert(sum>1,'editor preset must render visible particles');effect:release()
  end
  assert(J.decode('"\\uD83D\\uDD25"')=='🔥');assert(S.decode(J.encode(P.make(1))).version==1)
  assert(not pcall(S.decode,'return os.execute("false")'),'projects must never be evaluated as Lua')
  local invalid=P.make(1);invalid.layers[1].emitter.lifetime={2,1};assert(not pcall(D.validate,invalid))
  invalid=P.make(1);invalid.layers[1].emitter.max=250001;assert(not pcall(D.validate,invalid))
  invalid=P.make(1);invalid.layers[1].emitter.mode='stateful';assert(not pcall(D.validate,invalid),'import must reject hidden backend overrides')
  print('Editor presets / rendered output / mode selection / JSON round trip / validation PASS')

  local doc=P.make(4);local effect=R.new(doc)
  effect:advanceTo(0.079);assert(effect.emitters[3]:getCount()==0,'burst must not fire early')
  effect:advanceTo(0.081);assert(effect.emitters[3]:getCount()==2200,'burst must fire at its scheduled boundary')
  effect:seek(0.079);assert(effect.emitters[3]:getCount()==0);effect:advanceTo(0.081);assert(effect.emitters[3]:getCount()==2200)
  effect:seek(3.99);effect:update(0.02);near(effect.time,0.01);effect:release()
  doc=D.new();doc.loop=false;doc.duration=2;local l=doc.layers[1];l.start=0.5;l.span=0.5;l.emitter.rate=100;l.emitter.lifetime={0.2,0.2};l.emitter.max=100
  effect=R.new(doc);effect:advanceTo(0.49);assert(effect.emitters[1]:getCount()==0)
  effect:advanceTo(0.7);assert(effect.emitters[1]:getCount()>10);effect:advanceTo(1.3);assert(effect.emitters[1]:getCount()==0)
  effect:update(2);assert(not effect.playing);effect:release()
  print('Editor exact burst boundaries / seeking / looping / emission windows / lifetime tail PASS')

  doc=P.make(3);for _,layer in ipairs(doc.layers) do layer.emitter.max=256;layer.emitter.rate=100 end
  local original=R.new(doc);local source=S.exportSource(doc)
  assert(not source:find('require%(["\']editor_support'),'export must not depend on the editor')
  local factory=assert(loadstring(source,'generated-effect'))();local exported=factory.new()
  original:seek(1.1);exported:seek(1.1)
  for i=0,12 do local a,b,c,d=state(original.emitters[1],i);local x,y,vx,vy=state(exported.emitters[1],i);near(a,x);near(b,y);near(c,vx);near(d,vy) end
  local a,b=render(original),render(exported)
  for y=0,639,11 do for x=0,959,13 do local ar,ag,ab=a:getPixel(x,y);local br,bg,bb=b:getPixel(x,y);near(ar,br);near(ag,bg);near(ab,bb) end end
  a:release();b:release();original:release();exported:release()
  doc.name='Verification '..os.time();local path=S.save(doc);local file=S.slug(doc.name)..'.json'
  assert(J.encode(S.load(file))==J.encode(doc));assert(path:find(file,1,true));assert(love.filesystem.remove('projects/'..file))
  print('Editor standalone Lua export / GPU state parity / rendered parity / file persistence PASS')
  for _,argument in ipairs(arg or {}) do
    if argument=='--export-fixture' then print('EDITOR_EXPORT_PATH '..S.write('verification/editor.lua',source)) end
  end

  doc=D.new();l=doc.layers[1];l.emitter.max=100;l.emitter.rate=50
  l.flow.enabled=true;l.attractor.enabled=true;l.shape='ring'
  effect=R.new(doc);assert(effect.emitters[1]:getMode()=='stateful' and #effect.owned==2)
  effect:advanceTo(0.2);effect:release();effect:release()
  print('Editor composed flow / attractor / generated sprite / resource release PASS')

  local m=Model.new();m.playing=false;finish(m)
  local initial=m:layer().emitter.rate;assert(m:change(function(_,layer) layer.emitter.rate=333 end));finish(m);near(m.runtime.emitters[m.selected].config.rate,333)
  m:history(false);finish(m);near(m:layer().emitter.rate,initial);m:history(true);finish(m);near(m:layer().emitter.rate,333)
  m:add(true);assert(#m.doc.layers==4);m:move(-1);assert(m.selected==3);m:remove();assert(#m.doc.layers==3)
  local before=J.encode(m.doc);assert(not m:change(function(_,layer) layer.emitter.max=0 end));assert(J.encode(m.doc)==before)
  m:replace(P.make(3));m.playing=false;m:seek(4);m:update(0.01);assert(m.seekTarget and m.runtime.time<4,'stateful seeking must yield between batches');finish(m);near(m.runtime.time,4)
  m:release();print('Editor model edits / undo-redo / layer actions / rejected edit rollback / bounded replay PASS')

  local app=App.new();app.model.playing=false;finish(app.model)
  local function draw() app:draw() end
  local function widget(id) for _,w in ipairs(app.ui.items) do if w.id==id then return w end end;error('Missing editor control '..id) end
  local function click(id)
    draw();local w=widget(id);local x,y=w.x+w.w/2,w.y+w.h/2
    app:mousepressed(x,y,1);app:mousereleased(x,y,1)
  end
  click('emitter.rate');app.ui:textinput('777');app:keypressed('return');near(app.model:layer().emitter.rate,777)
  click('emitter.rate');app.ui:textinput('-5');app:keypressed('return');assert(app.ui.edit and app.ui.edit.error);near(app.model:layer().emitter.rate,777)
  app:keypressed('escape');click('tab:Style');assert(app.model.tab=='Style')
  for _=1,7 do click('color:add') end;assert(#app.model:layer().emitter.colors==10,'editor must author more than eight color stops')
  click('color:hex');app.ui:textinput('2299EE88');app:keypressed('return');near(app.model:layer().emitter.colors[app.model.colorStop][1],34/255)
  app.model.scroll=250;draw();local graph=widget('curve:size');local oldHistory=#app.model.undoStack
  app:mousepressed(graph.x+graph.w/2,graph.y+graph.h/2,1);app:mousemoved(graph.x+graph.w/2,graph.y+12);app:mousereleased(graph.x+graph.w/2,graph.y+12,1)
  assert(#app.model.undoStack==oldHistory+1,'a curve drag must create one undo entry')
  draw();local x,y,scale=View.viewport(app.layout)
  app:mousepressed(x+300*scale,y+200*scale,1);app:mousereleased(x+300*scale,y+200*scale,1)
  near(app.model:layer().emitter.position[1],300);near(app.model:layer().emitter.position[2],200)
  app:open('presets');draw();for _,w in ipairs(app.ui.items) do assert(w.id:match('^preset:') or w.id=='modal:close','modal must trap focus') end
  click('preset:3');assert(app.modal.kind=='confirm','preset navigation must protect unsaved edits');click('confirm:cancel');assert(not app.modal)
  app:release();print('Editor real UI / numeric entry / invalid input / 10 color stops / curve drag / viewport mapping / unsaved guard PASS')
end
function T.install()
  function love.load() local ok,err=xpcall(T.run,debug.traceback);if not ok then print(err) end;love.event.quit(ok and 0 or 1) end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return T
