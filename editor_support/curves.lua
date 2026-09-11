local U=require('editor_support.ui')
local C={}
function C.draw(app,x,y,w)
  local m,u,g=app.model,app.ui,love.graphics
  local colors=m:layer().emitter.colors
  m.colorStop=math.max(1,math.min(m.colorStop,#colors))
  u:text('COLOR OVER LIFE',x,y+6,'secondary',11);u:text(#colors..' stops',x+w-62,y+6,'muted',11);y=y+32
  local gradientY=y
  for row=0,3 do for column=0,math.ceil(w/12)-1 do
    U.color((row+column)%2==0 and 'raised' or 'panel')
    g.rectangle('fill',x+column*12,y+row*10,math.min(12,w-column*12),math.min(10,38-row*10))
  end end
  for k=0,79 do
    local at=k/79*(#colors-1);local i=math.floor(at)+1;local a,b=colors[i],colors[math.min(#colors,i+1)];local f=at-math.floor(at)
    g.setColor(a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f,a[3]+(b[3]-a[3])*f,a[4]+(b[4]-a[4])*f)
    g.rectangle('fill',x+k*w/80,y,w/80,38)
  end
  if u.focus=='curve:color' then U.color('accent');g.rectangle('line',x,gradientY,w,38) end
  for i,c in ipairs(colors) do
    local px=x+(#colors==1 and w/2 or (i-1)/(#colors-1)*w)
    g.setColor(c[1],c[2],c[3],1);g.circle('fill',px,y+45,4)
    if i==m.colorStop then U.color('ink');g.circle('line',px,y+45,7) end
  end
  local function selectColor(px) m.colorStop=math.floor(math.max(0,math.min(1,(px-x)/w))*(#colors-1)+1.5) end
  u:register{id='curve:color',kind='drag',x=x,y=gradientY,w=w,h=56,begin=selectColor,move=selectColor,
    key=function(key)
      if key=='left' or key=='right' then m.colorStop=math.max(1,math.min(#colors,m.colorStop+(key=='right' and 1 or -1)));return true end
    end}
  y=y+64
  u:button('color:add','+ Stop',x,y,w/2-4,40,function()
    if #colors>=32 then m:message('Use up to 32 color stops.',true);return end
    m:change(function(_,l) table.insert(l.emitter.colors,m.colorStop+1,require('editor_support.document').copy(l.emitter.colors[m.colorStop])) end);m.colorStop=m.colorStop+1
  end,false,#colors>=32)
  u:button('color:remove','Remove',x+w/2+4,y,w/2-4,40,function() m:change(function(_,l) table.remove(l.emitter.colors,m.colorStop) end);m.colorStop=math.max(1,m.colorStop-1) end,false,#colors==1)
  y=y+48
  local color=colors[m.colorStop]
  local stop=m.colorStop
  y=require('editor_support.colorpicker').draw(app,'color','Stop '..stop,x,y,w,function(layer) return layer.emitter.colors[stop] end)
  for i,label in ipairs{'Red','Green','Blue','Alpha'} do
    u:number('color:'..i,label,color[i],x,y,w,function(v) return m:change(function(_,l) l.emitter.colors[m.colorStop][i]=v end) end,{min=0,max=1,step=0.01,decimals=3});y=y+40
  end
  y=y+12;u:text('SIZE OVER LIFE',x,y,'secondary',11);y=y+26
  local sizes=m:layer().emitter.sizes;m.sizeStop=math.max(1,math.min(m.sizeStop,#sizes))
  if not u.active or u.active.widget.id~='curve:size' then
    local highest=0;for _,v in ipairs(sizes) do highest=math.max(highest,v) end
    m.curveScale=math.max(32,math.ceil(highest/16)*16)
  end
  local graphY,graphH=y,100;u:box(x,graphY,w,graphH,'input')
  if u.focus=='curve:size' then U.color('accent');g.rectangle('line',x,graphY,w,graphH) end
  U.color('line');g.setLineWidth(1)
  for i=1,3 do g.line(x,graphY+i*graphH/4,x+w,graphY+i*graphH/4) end
  local points={}
  for i,v in ipairs(sizes) do points[#points+1]=x+(#sizes==1 and w/2 or (i-1)/(#sizes-1)*w);points[#points+1]=graphY+graphH-v/m.curveScale*graphH end
  U.color('accent');g.setLineWidth(2);if #points>=4 then g.line(points) end
  for i=1,#sizes do
    g.circle('fill',points[i*2-1],points[i*2],4)
    if i==m.sizeStop then U.color('ink');g.circle('line',points[i*2-1],points[i*2],7);U.color('accent') end
  end
  local function changeSize(_,py) m:layer().emitter.sizes[m.sizeStop]=math.max(0,math.min(200,(graphY+graphH-py)/graphH*m.curveScale)) end
  u:register{id='curve:size',kind='drag',x=x,y=graphY-6,w=w,h=graphH+12,
    begin=function(px,py) m.sizeStop=math.floor(math.max(0,math.min(1,(px-x)/w))*(#sizes-1)+1.5);m:beginEdit();changeSize(px,py) end,
    move=changeSize,finish=function() m:commitEdit() end,
    key=function(key)
      if key=='left' or key=='right' then m.sizeStop=math.max(1,math.min(#sizes,m.sizeStop+(key=='right' and 1 or -1)));return true end
      if key=='up' or key=='down' then m:change(function(_,l) l.emitter.sizes[m.sizeStop]=math.max(0,math.min(200,l.emitter.sizes[m.sizeStop]+(key=='up' and 1 or -1))) end);return true end
    end}
  y=y+112;u:text('Birth',x,y,'muted',11);u:text('End of life',x+w-55,y,'muted',11);y=y+28
  u:button('size:add','+ Stop',x,y,w/2-4,40,function()
    m:change(function(_,l) table.insert(l.emitter.sizes,m.sizeStop+1,l.emitter.sizes[m.sizeStop]) end);m.sizeStop=m.sizeStop+1
  end,false,#sizes>=32)
  u:button('size:remove','Remove',x+w/2+4,y,w/2-4,40,function() m:change(function(_,l) table.remove(l.emitter.sizes,m.sizeStop) end);m.sizeStop=math.max(1,m.sizeStop-1) end,false,#sizes==1)
  y=y+48
  u:number('size:value','Stop '..m.sizeStop..' / px',sizes[m.sizeStop],x,y,w,function(v) return m:change(function(_,l) l.emitter.sizes[m.sizeStop]=v end) end,{min=0,max=200,step=1,decimals=1})
  return y+56
end
return C
