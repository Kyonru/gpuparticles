local U=require('editor_support.ui')
local D=require('editor_support.document')
local P={};P.__index=P
local function clamp(v) return math.max(0,math.min(1,v)) end
function P.rgb(h,s,v)
  local function channel(offset)
    local k=(offset+h*6)%6
    return v*(1-s*math.max(0,math.min(k,4-k,1)))
  end
  return channel(5),channel(3),channel(1)
end
local function hsv(c,previous)
  local r,g,b=c[1],c[2],c[3];local v=math.max(r,g,b);local d=v-math.min(r,g,b)
  local h=previous and previous.h or 0
  if d>0 then
    if v==r then h=((g-b)/d)%6 elseif v==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
    h=h/6
  end
  return {h=h,s=v>0 and d/v or previous and previous.s or 0,v=v,r=r,g=g,b=b}
end
local function mesh(colors)
  local positions={{0,0},{1,0},{1,1},{0,1}};local vertices={}
  for i,p in ipairs(positions) do local c=colors[i];vertices[i]={p[1],p[2],0,0,c[1],c[2],c[3],c[4]} end
  return love.graphics.newMesh(vertices,'fan','static')
end
function P.new()
  local white,clear,black,none={1,1,1,1},{1,1,1,0},{0,0,0,1},{0,0,0,0}
  local self=setmetatable({states=setmetatable({},{__mode='k'}),
    saturation=mesh{white,clear,clear,white},brightness=mesh{none,none,black,black},
    opacity=mesh{clear,white,white,clear}},P)
  local vertices={}
  for i=0,6 do
    local r,g,b=P.rgb(i/6,1,1)
    for x=0,1 do vertices[#vertices+1]={x,i/6,0,0,r,g,b,1} end
  end
  self.hue=love.graphics.newMesh(vertices,'strip','static');return self
end
function P:state(color)
  local state=self.states[color]
  if not state or color[1]~=state.r or color[2]~=state.g or color[3]~=state.b then
    state=hsv(color,state);self.states[color]=state
  end
  return state
end
local function checker(x,y,w,h)
  local g=love.graphics
  for row=0,math.ceil(h/8)-1 do for col=0,math.ceil(w/8)-1 do
    U.color((row+col)%2==0 and 'raised' or 'secondary')
    g.rectangle('fill',x+col*8,y+row*8,math.min(8,w-col*8),math.min(8,h-row*8))
  end end
end
local function outline(u,id,x,y,w,h)
  U.color(u.focus==id and 'accent' or 'line');love.graphics.rectangle('line',x+0.5,y+0.5,w-1,h-1)
end
local function marker(x,y,r)
  local g=love.graphics;g.setColor(0,0,0,1);g.setLineWidth(3);g.circle('line',x,y,r)
  g.setColor(1,1,1,1);g.setLineWidth(1);g.circle('line',x,y,r)
end
function P:render(app,id,label,x,y,w,read)
  local u,m,g=app.ui,app.model,love.graphics
  local color=read(m:layer());local channels=#color;local state=self:state(color)
  checker(x,y,40,40);g.setColor(color[1],color[2],color[3],1);g.rectangle('fill',x,y,20,40)
  g.setColor(color);g.rectangle('fill',x+20,y,20,40);outline(u,id..':hex',x,y,40,40)
  u:text(label,x+52,y+12,'secondary',13,w-192)
  local hex='';for i=1,channels do hex=hex..('%02X'):format(math.floor(color[i]*255+0.5)) end
  u:input(id..':hex',hex,x+w-132,y,132,40,function(text)
    text=text:gsub('^#','');if #text~=channels*2 or not text:match('^%x+$') then return false end
    return m:change(function(_,layer) local c=read(layer);for i=1,channels do c[i]=tonumber(text:sub(i*2-1,i*2),16)/255 end end)
  end)
  y=y+48;u:text('Saturation / brightness',x,y,'muted',11);u:text('Hue',x+w-36,y,'muted',11);y=y+20
  local sv={x=x,y=y,w=w-52,h=112};local hue={x=x+w-40,y=y,w=40,h=112}
  g.setColor(P.rgb(state.h,1,1));g.rectangle('fill',sv.x,sv.y,sv.w,sv.h)
  g.setColor(1,1,1,1);g.draw(self.saturation,sv.x,sv.y,0,sv.w,sv.h);g.draw(self.brightness,sv.x,sv.y,0,sv.w,sv.h)
  g.draw(self.hue,hue.x,hue.y,0,hue.w,hue.h)
  outline(u,id..':sv',sv.x,sv.y,sv.w,sv.h);outline(u,id..':hue',hue.x,hue.y,hue.w,hue.h)
  marker(sv.x+math.max(5,math.min(sv.w-5,state.s*sv.w)),sv.y+math.max(5,math.min(sv.h-5,(1-state.v)*sv.h)),4)
  local hy=hue.y+math.max(2,math.min(hue.h-3,state.h*hue.h))
  g.setColor(0,0,0,1);g.rectangle('fill',hue.x,hy-1,hue.w,4);g.setColor(1,1,1,1);g.rectangle('fill',hue.x,hy,hue.w,2)
  local alpha={x=x+72,y=y+120,w=w-72,h=40}
  if channels==4 then
    u:text('Opacity',x,alpha.y+12,'secondary',13)
    checker(alpha.x,alpha.y+8,alpha.w,24);g.setColor(color[1],color[2],color[3],1);g.draw(self.opacity,alpha.x,alpha.y+8,0,alpha.w,24)
    outline(u,id..':alpha',alpha.x,alpha.y+8,alpha.w,24)
    marker(alpha.x+math.max(5,math.min(alpha.w-5,color[4]*alpha.w)),alpha.y+20,4)
  end
  local original,previous
  local function begin()
    local c=read(m:layer());state=self:state(c);original=D.copy(c);previous=D.copy(state);m:beginEdit()
  end
  local function apply(kind,a,b)
    local c=read(m:layer())
    if kind=='alpha' then c[4]=clamp(a)
    else
      if kind=='hue' then state.h=clamp(a) else state.s,state.v=clamp(a),clamp(b) end
      c[1],c[2],c[3]=P.rgb(state.h,state.s,state.v)
      state.r,state.g,state.b=c[1],c[2],c[3]
    end
  end
  local function finish()
    local c=read(m:layer());local changed=false
    for i=1,channels do changed=changed or c[i]~=original[i] end
    -- A hue choice on black/gray changes only picker state; keep the color records and their remembered hues.
    if changed then m:commitEdit() else m.before=nil end
  end
  local function cancel() m:cancelEdit();self.states[read(m:layer())]=previous end
  for _,kind in ipairs(channels==4 and {'sv','hue','alpha'} or {'sv','hue'}) do
    local rect=kind=='sv' and sv or kind=='hue' and hue or alpha
    local function move(px,py)
      if kind=='sv' then apply(kind,(px-rect.x)/rect.w,1-(py-rect.y)/rect.h)
      elseif kind=='hue' then apply(kind,(py-rect.y)/rect.h)
      else apply(kind,(px-rect.x)/rect.w) end
    end
    u:register{id=id..':'..kind,kind='drag',x=rect.x,y=rect.y,w=rect.w,h=rect.h,
      begin=function(px,py) begin();move(px,py) end,move=move,finish=finish,cancel=cancel,
      key=function(key)
        if key~='left' and key~='right' and key~='up' and key~='down' then return false end
        begin();local step=love.keyboard.isDown('lshift','rshift') and 0.001 or 0.01
        if kind=='sv' then
          apply(kind,state.s+(key=='right' and step or key=='left' and -step or 0),state.v+(key=='up' and step or key=='down' and -step or 0))
        elseif kind=='hue' then apply(kind,state.h+((key=='right' or key=='down') and step or -step))
        else apply(kind,read(m:layer())[4]+((key=='right' or key=='up') and step or -step)) end
        finish();return true
      end}
  end
  return y+(channels==4 and 172 or 124)
end
function P.draw(app,...)
  app.ui.colorPicker=app.ui.colorPicker or P.new()
  return app.ui.colorPicker:render(app,...)
end
function P:release()
  self.saturation:release();self.brightness:release();self.opacity:release();self.hue:release()
end
return P
