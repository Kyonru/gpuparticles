local App=require('editor_support.app')
local D=require('editor_support.document')
local J=require('editor_support.json')
local T={}
local function near(a,b,label,tolerance)
  assert(math.abs(a-b)<(tolerance or 0.00001),('%s: expected %.5f, got %.5f'):format(label or 'color picker',b,a))
end
function T.run()
  local app=App.new();local m=app.model;local g=love.graphics
  local doc=D.new();doc.layers[1].emitter.max=16;doc.layers[1].emitter.rate=0
  doc.layers[1].emitter.colors[1]={1,0,0,0.25};m:replace(doc);m.playing=false;m.tab='Style'
  while m.seekTarget do m:update(0.1) end
  local function find(id)
    for _,w in ipairs(app.ui.items) do if w.id==id then return w end end
  end
  local function show(id,height)
    m.scroll=0;app:draw()
    while (not find(id) or find(id).h<(height or 40)) and m.scroll<m.scrollMax do
      m.scroll=math.min(m.scroll+80,m.scrollMax);app:draw()
    end
    local w=assert(find(id),'missing color control '..id)
    assert(w.h>=(height or 40),'color control must be fully visible');return w
  end
  local function pick(id,s,t)
    local w=show(id,id:match(':alpha$') and 40 or 112);local x,y=w.x+s*w.w,w.y+t*w.h
    app:mousepressed(x,y,1);app:mousereleased(x,y,1)
  end
  local function typeValue(id,value)
    local w=show(id);local x,y=w.x+w.w/2,w.y+w.h/2
    app:mousepressed(x,y,1);app:mousereleased(x,y,1);app.ui:textinput(value);app:keypressed('return')
  end
  local function color() return m:layer().emitter.colors[m.colorStop] end
  local function rgb(r,gc,b,label)
    local c=color();near(c[1],r,label);near(c[2],gc,label);near(c[3],b,label)
  end
  local untouched=J.encode(m:layer().emitter.colors[2]);local history=#m.undoStack
  pick('color:hue',0.5,1/3);rgb(0,1,0,'hue selection');near(color()[4],0.25,'hue must preserve alpha')
  assert(#m.undoStack==history+1,'hue click must create one undo entry')
  local w=show('color:sv',112);local builds=m.builds;history=#m.undoStack
  app:mousepressed(w.x+w.w*0.8,w.y+w.h*0.2,1)
  app:mousemoved(w.x+w.w*0.5,w.y+w.h*0.4);rgb(0.3,0.6,0.3,'saturation brightness selection')
  app:draw();m:update(0.2)
  assert(#m.undoStack==history and m.builds==builds,'color drag must defer undo and rebuild until release')
  app:mousereleased(w.x+w.w*0.5,w.y+w.h*0.4,1)
  assert(#m.undoStack==history+1 and not m.before,'color drag must commit once')
  m:history(false);rgb(0,1,0);m:history(true);rgb(0.3,0.6,0.3)
  history=#m.undoStack;w=show('color:sv',112)
  app:mousepressed(w.x,w.y,1);app:mousemoved(w.x+w.w,w.y+w.h)
  app:keypressed('escape');app:mousereleased(w.x+w.w,w.y+w.h,1);rgb(0.3,0.6,0.3)
  assert(not m.before and not app.modal and #m.undoStack==history,'Escape must cancel color drag without history or quit')
  pick('color:alpha',0.75,0.5);near(color()[4],0.75,'opacity selection');rgb(0.3,0.6,0.3)
  w=show('color:alpha');app:mousepressed(w.x+w.w/2,w.y+20,1)
  app:mousemoved(w.x-100,w.y);near(color()[4],0,'opacity minimum clamp')
  app:mousemoved(w.x+w.w+100,w.y);near(color()[4],1,'opacity maximum clamp')
  app:mousereleased(w.x+w.w+100,w.y,1)
  assert(J.encode(m:layer().emitter.colors[2])==untouched,'picker must edit only the selected stop')
  typeValue('color:hex','0000FF80');rgb(0,0,1);near(color()[4],128/255)
  show('color:sv',112);near(app.ui.colorPicker:state(color()).h,2/3,'hex must synchronize picker hue')
  typeValue('color:hex','oops');assert(app.ui.edit and app.ui.edit.error,'invalid hex must remain editable');app:keypressed('escape');rgb(0,0,1)
  typeValue('color:1','1');rgb(1,0,1)
  show('color:sv',112);near(app.ui.colorPicker:state(color()).h,5/6,'numeric channel must synchronize picker hue')
  -- Black and gray have no encoded hue, so preserve the chosen hue until saturation/value increases.
  typeValue('color:hex','000000FF');history=#m.undoStack
  pick('color:hue',0.5,1/3);rgb(0,0,0);assert(#m.undoStack==history,'choosing hue for black must not create an unchanged document edit')
  pick('color:sv',1,0);rgb(0,1,0,'black must retain chosen hue')
  typeValue('color:hex','808080FF');pick('color:hue',0.5,2/3);pick('color:sv',1,0);rgb(0,0,1,'gray must retain chosen hue')
  m.colorStop=2;show('color:sv',112);near(app.ui.colorPicker:state(color()).r,color()[1],'stop switch must synchronize picker')
  m.colorStop=1;pick('color:sv',0.5,0.5);app:draw();app:keypressed('right');rgb(0.245,0.245,0.5,'picker keyboard saturation')
  app:draw();app:keypressed('up');rgb(0.2499,0.2499,0.51,'picker keyboard brightness')

  m.tab='Effects';m:layer().appearance.outline=1
  pick('outline:hue',0.5,1/3);pick('outline:sv',1,0)
  local outline=m:layer().appearance.outlineColor;near(outline[1],0);near(outline[2],1);near(outline[3],0)
  typeValue('outline:hex','112233');near(m:layer().appearance.outlineColor[1],17/255)
  pick('tint:hue',0.5,2/3);pick('tint:sv',1,0)
  near(m:layer().appearance.tint[1],0);near(m:layer().appearance.tint[2],0);near(m:layer().appearance.tint[3],1)
  assert(not find('tint:alpha') and not find('outline:alpha'),'RGB effects must not offer an alpha control')
  typeValue('tint:hex','FFFFFF');near(m:layer().appearance.tint[3],1)
  print('Editor visible color pickers / hue and SV / opacity / typing sync / grayscale hue / stop isolation / effects / keyboard / undo / cancel PASS')

  -- Numeric readback checks the actual gradient under the pointer, including when particle alpha is zero.
  m.tab='Style';typeValue('color:hex','FF000000')
  local oldW,oldH=g.getDimensions();local resources=app.ui.colorPicker
  for _,size in ipairs{{1440,900},{1120,760}} do
    love.window.setMode(size[1],size[2],{vsync=0});m.scroll=0;app:draw()
    local sv=assert(find('color:sv'));local hue=assert(find('color:hue'));local alpha=assert(find('color:alpha'))
    assert(sv.h==112 and hue.h==112 and alpha.h==40 and alpha.y+alpha.h<=app.layout.bottom,'full color picker must fit the compact inspector')
    local canvas=g.newCanvas(size[1],size[2],{format='rgba32f',dpiscale=1})
    g.push('all');g.setCanvas(canvas);app:draw();g.pop();local data=canvas:newImageData()
    local px,py=math.floor(sv.x+sv.w*0.6),math.floor(sv.y+sv.h*0.4)
    local s,v=(px+0.5-sv.x)/sv.w,1-(py+0.5-sv.y)/sv.h
    local r,gc,b=data:getPixel(px,py)
    near(r,v,'rendered picker brightness',0.01);near(gc,v*(1-s),'rendered picker saturation',0.01);near(b,v*(1-s),'rendered picker saturation',0.01)
    px,py=math.floor(hue.x+10),math.floor(hue.y+hue.h/3)
    r,gc,b=data:getPixel(px,py);assert(gc>0.97 and r<0.05 and b<0.05,'rendered hue strip must show green at its selectable position')
    for _,argument in ipairs(arg or {}) do if argument=='--color-capture' then
      local capture=g.newCanvas(size[1],size[2],{dpiscale=1})
      g.push('all');g.setCanvas(capture);g.origin();g.setShader();g.setBlendMode('replace','premultiplied');g.setColor(1,1,1,1);g.draw(canvas);g.pop()
      local pixels=capture:newImageData();local file='editor-colors-'..size[1]..'.png';pixels:encode('png',file);pixels:release();capture:release()
      print('EDITOR_COLORS_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file)
    end end
    data:release();canvas:release();assert(app.ui.colorPicker==resources,'picker meshes must be reused across draws and resizes')
  end
  love.window.setMode(oldW,oldH,{vsync=0});app:release()
  assert(not pcall(resources.hue.getVertexCount,resources.hue),'picker resources must release with the editor')
  print('Editor picker rendered gradient accuracy / transparent colors / compact visibility / mesh reuse and release PASS')
end
return T
