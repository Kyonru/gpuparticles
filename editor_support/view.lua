local U=require('editor_support.ui')
local Inspector=require('editor_support.inspector')
local V={}
function V.layout(width,height)
  local left,right=232,344
  return {width=width,height=height,left=left,right=right,top=64,bottom=height-28,
    preview={x=left,y=64,w=width-left-right,h=height-64-204},timeline={x=left,y=height-204,w=width-left-right,h=176}}
end
function V.viewport(layout)
  local r=V.previewRect(layout);local scale=math.min(r.w/960,r.h/640)
  return r.x+(r.w-960*scale)/2,r.y+(r.h-640*scale)/2,scale
end
function V.previewRect(layout)
  local r=layout.preview
  return {x=r.x+1,y=r.y+56,w=r.w-2,h=r.h-88}
end
function V.bounds(layout)
  local r=V.previewRect(layout);local x,y,scale=V.viewport(layout)
  return {x=(r.x-x)/scale,y=(r.y-y)/scale,w=r.w/scale,h=r.h/scale}
end
function V.world(layout,x,y)
  local left,top,scale=V.viewport(layout);local r=V.previewRect(layout)
  return (x-left)/scale,(y-top)/scale,x>=r.x and y>=r.y and x<=r.x+r.w and y<=r.y+r.h
end
local function separator(x1,y1,x2,y2) U.color('line');love.graphics.setLineWidth(1);love.graphics.line(x1,y1,x2,y2) end
local function toolbar(app,L)
  local u,m=app.ui,app.model
  u:text('Particle Studio',20,13,'ink',19)
  u:text('GPU EFFECT COMPOSITOR',21,39,'muted',11)
  u:input('project:name',m.doc.name,L.left+16,12,math.max(160,L.preview.w-406),40,function(v) return m:change(function(doc) doc.name=v end) end)
  local x=L.width-520
  u:button('project','Project',x-112,12,104,40,function() app:open('project') end)
  u:button('presets','Presets',x,12,92,40,function() app:open('presets') end)
  u:button('open','Open',x+100,12,76,40,function() app:open('files') end)
  u:button('save',m.dirty and 'Save *' or 'Save',x+184,12,78,40,function() m:save() end)
  u:button('export','Export Lua',x+270,12,120,40,function() m:export() end,true)
  u:button('help','?',L.width-56,12,40,40,function() app:open('help') end)
end
local function layers(app,L)
  local u,m,g=app.ui,app.model,love.graphics
  u:text('COMPOSITION',16,84,'muted',11);u:text(('%02d layers'):format(#m.doc.layers),145,84,'secondary',11)
  u:button('layer:add','+ Add emitter',12,112,208,40,function() m:add() end)
  local visible=math.floor((L.bottom-342)/52)
  local first=math.max(1,math.min(m.selected-visible+1,#m.doc.layers-visible+1))
  for i=first,math.min(#m.doc.layers,first+visible-1) do
    local l=m.doc.layers[i];local y=164+(i-first)*52;local c=l.emitter.colors[math.min(2,#l.emitter.colors)]
    u:button('layer:'..i,l.name,12,y,160,44,function() m:select(i) end,m.selected==i)
    g.setColor(c[1],c[2],c[3],l.enabled and 1 or 0.25);g.rectangle('fill',16,y+12,3,20)
    u:button('visible:'..i,l.enabled and 'On' or 'Off',176,y,44,44,function() m:change(function(doc) doc.layers[i].enabled=not doc.layers[i].enabled end) end,l.enabled)
  end
  local y=L.bottom-170
  u:button('layer:duplicate','Duplicate',12,y,100,40,function() m:add(true) end)
  u:button('layer:remove','Remove',120,y,100,40,function() m:remove() end,false,#m.doc.layers==1)
  u:button('layer:up','Move up',12,y+48,100,40,function() m:move(-1) end,false,m.selected==1)
  u:button('layer:down','Move down',120,y+48,100,40,function() m:move(1) end,false,m.selected==#m.doc.layers)
  u:button('layer:solo',m.solo and 'Exit solo' or 'Solo selected',12,y+96,208,40,function()
    m.solo=m.solo and nil or m.selected;m.runtime.solo=m.solo
  end,m.solo~=nil)
  u:text('Draw order: first layer behind the rest.',12,L.bottom-23,'muted',11,208)
end
local function preview(app,L)
  local u,m,g=app.ui,app.model,love.graphics;local r=L.preview
  u:text('LIVE PREVIEW',r.x+20,r.y+16,'muted',11)
  u:button('grid','Grid',r.x+r.w-166,r.y+8,62,40,function() m.grid=not m.grid end,m.grid)
  u:button('restart','Replay',r.x+r.w-96,r.y+8,82,40,function() m:seek(0) end)
  local x,y,scale=V.viewport(L);local area=V.previewRect(L);local bounds=V.bounds(L)
  g.setScissor(area.x,area.y,area.w,area.h);g.push('all');g.translate(x,y);g.scale(scale)
  U.color('canvas');g.rectangle('fill',bounds.x,bounds.y,bounds.w,bounds.h)
  if m.grid then
    g.setColor(0.11,0.12,0.13,0.55);g.setLineWidth(1/scale)
    for i=math.ceil(bounds.x/40)*40,bounds.x+bounds.w,40 do g.line(i,bounds.y,i,bounds.y+bounds.h) end
    for j=math.ceil(bounds.y/40)*40,bounds.y+bounds.h,40 do g.line(bounds.x,j,bounds.x+bounds.w,j) end
  end
  g.setColor(1,1,1,1);m.runtime:draw(0,0,bounds)
  local l=m:layer();local c=l.emitter
  g.setColor(0.98,0.65,0.29,0.5);g.setLineWidth(1/scale)
  if l.ground.enabled then g.line(bounds.x,l.ground.y,bounds.x+bounds.w,l.ground.y) end
  if l.circle.enabled then g.circle('line',l.circle.x,l.circle.y,l.circle.radius) end
  if l.attractor.enabled then g.circle('line',l.attractor.x,l.attractor.y,14);g.line(l.attractor.x-20,l.attractor.y,l.attractor.x+20,l.attractor.y) end
  U.color('accent');g.setLineWidth(1.5/scale)
  g.circle('line',c.position[1],c.position[2],10/scale)
  g.line(c.position[1]-16/scale,c.position[2],c.position[1]+16/scale,c.position[2]);g.line(c.position[1],c.position[2]-16/scale,c.position[1],c.position[2]+16/scale)
  g.line(c.position[1],c.position[2],c.position[1]+math.cos(c.direction)*50,c.position[2]+math.sin(c.direction)*50)
  if c.spread>0 and c.spread<math.pi*1.9 then
    g.setColor(0.98,0.65,0.29,0.28)
    for _,sign in ipairs{-1,1} do local angle=c.direction+sign*c.spread/2;g.line(c.position[1],c.position[2],c.position[1]+math.cos(angle)*72,c.position[2]+math.sin(angle)*72) end
  end
  if c.emissionArea.distribution~='none' then
    local emission=c.emissionArea
    g.push();g.translate(c.position[1],c.position[2]);g.rotate(emission.angle);g.setColor(0.98,0.65,0.29,0.22)
    if emission.distribution=='uniform' or emission.distribution=='borderrectangle' then g.rectangle('line',-emission.x,-emission.y,emission.x*2,emission.y*2)
    else g.ellipse('line',0,0,math.max(1,emission.x),math.max(1,emission.y)) end
    g.pop()
  end
  g.pop();g.setScissor()
  local e=m.runtime.emitters[m.selected]
  local mode=e and (e:getBackend()=='gpu' and ('GPU / '..e:getMode()) or 'Native fallback') or 'Rebuilding'
  local detail=m.seekTarget and ('Replaying %.2f / %.2f s'):format(m.runtime.time,m.seekTarget) or m.pending>0 and 'Applying changes…' or 'Drag origin · Shift-drag circle · Alt-drag attractor'
  u:text(detail,r.x+20,r.y+r.h-24,'secondary',11,r.w-220)
  u:text(mode,r.x+r.w-180,r.y+r.h-24,'accent',11,160)
end
local function timeline(app,L)
  local u,m,g=app.ui,app.model,love.graphics;local r=L.timeline
  u:button('play',m.playing and 'Pause' or 'Play',r.x+16,r.y+12,74,36,function() m:togglePlayback() end,true)
  u:button('burst','Burst 256',r.x+98,r.y+12,98,36,function() m:play();m.runtime:burst(m.selected,256) end)
  u:button('speed',m.speed..'x',r.x+204,r.y+12,54,36,function() m.speed=m.speed==0.25 and 0.5 or m.speed==0.5 and 1 or m.speed==1 and 2 or 0.25 end)
  u:button('loop',m.doc.loop and 'Loop on' or 'Loop off',r.x+266,r.y+12,88,36,function() m:change(function(doc) doc.loop=not doc.loop end) end,m.doc.loop)
  u:text(('%05.2f / %.2f s'):format(m.runtime.time,m.doc.duration),r.x+r.w-133,r.y+23,'ink',13)
  local left,top,width=r.x+112,r.y+72,r.w-136
  for i=0,6 do
    local x=left+width*i/6;separator(x,top-2,x,r.y+r.h-9)
    u:text(('%g'):format(m.doc.duration*i/6),x+3,top-18,'muted',11)
  end
  local first=math.max(1,m.selected-3)
  for i=first,math.min(#m.doc.layers,first+3) do
    local l=m.doc.layers[i];local y=top+(i-first)*22
    u:text(l.name,r.x+16,y,'secondary',11,88)
    local c=l.emitter.colors[math.min(2,#l.emitter.colors)]
    g.setColor(c[1],c[2],c[3],l.enabled and 0.28 or 0.07)
    local a=left+l.start/m.doc.duration*width;local b=left+math.min(m.doc.duration,l.start+l.span)/m.doc.duration*width
    g.rectangle('fill',a,y+1,math.max(1,b-a),15,2,2)
    if i==m.selected then g.setColor(c[1],c[2],c[3],0.85);g.rectangle('line',a,y+1,math.max(1,b-a),15,2,2) end
    U.color('accent')
    for _,burst in ipairs(l.bursts) do local x=left+burst.time/m.doc.duration*width;g.polygon('fill',x,y+3,x+5,y+8,x,y+13,x-5,y+8) end
  end
  local px=left+(app.scrubTime or m.runtime.time)/m.doc.duration*width
  U.color('accent');g.setLineWidth(1.5);g.line(px,top-10,px,r.y+r.h-8);g.polygon('fill',px-4,top-10,px+4,top-10,px,top-4)
  local function seek(x) app.scrubTime=math.max(0,math.min(m.doc.duration,(x-left)/width*m.doc.duration)) end
  u:register{id='timeline',kind='drag',x=left,y=top-18,w=width,h=r.h-54,
    begin=function(x) m.playing=false;seek(x) end,move=seek,finish=function() m:seek(app.scrubTime);app.scrubTime=nil end,
    key=function(key) if key=='left' or key=='right' then m.playing=false;m:seek(m.runtime.time+(key=='right' and 0.1 or -0.1));return true end end}
end
function V.draw(app)
  local u,m,g=app.ui,app.model,love.graphics;local width,height=g.getDimensions();local L=V.layout(width,height);app.layout=L
  u:begin();u.suspend=app.modal~=nil
  g.clear(U.colors.panel);g.setShader();g.setBlendMode('alpha');g.setLineWidth(1)
  toolbar(app,L);layers(app,L);preview(app,L);timeline(app,L)
  Inspector.draw(app,width-L.right,L.top,L.right,L.bottom)
  separator(0,64,width,64);separator(L.left,64,L.left,L.bottom);separator(width-L.right,64,width-L.right,L.bottom)
  separator(L.left,L.timeline.y,width-L.right,L.timeline.y);separator(0,L.bottom,width,L.bottom)
  local total=0;for _,l in ipairs(m.doc.layers) do if l.enabled then total=total+l.emitter.max end end
  u:text(m.status,12,height-20,m.error and 'danger' or 'secondary',11,width-300)
  u:text(('%d capacity  ·  %d FPS'):format(total,love.timer.getFPS()),width-250,height-20,'muted',11,238)
  if app.modal then require('editor_support.dialogs').draw(app) end
end
return V
