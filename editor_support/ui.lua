-- Shared LÖVE control vocabulary, following the existing hybrid editor's focus pattern.
local utf8=require('utf8')
local palette=require('editor_support.palette')
local U={};U.__index=U
U.colors={
  canvas=palette.ink,panel=palette.beige,raised=palette.teal,
  input={1,245/255,230/255},hover={103/255,162/255,197/255},line={103/255,162/255,197/255},
  ink={33/255,54/255,64/255},secondary={51/255,91/255,105/255},muted={78/255,116/255,121/255},
  accent={52/255,114/255,145/255},accentDim={155/255,206/255,193/255},danger={190/255,85/255,76/255},
  dark=palette.ink,peach=palette.peach,beige=palette.beige,teal=palette.teal,blue=palette.blue,
}
function U.color(name,alpha)
  local c=U.colors[name];love.graphics.setColor(c[1],c[2],c[3],alpha or 1)
end
function U.new()
  local fonts={};for _,size in ipairs{11,13,15,19,24} do fonts[size]=love.graphics.newFont(size) end
  return setmetatable({fonts=fonts,items={},focus=nil,edit=nil,active=nil,clip=nil},U)
end
function U:text(text,x,y,color,size,width)
  local g=love.graphics;local font=self.fonts[size or 13];g.setFont(font);U.color(color or 'ink')
  text=tostring(text)
  if width and font:getWidth(text)>width then
    while #text>0 and font:getWidth(text..'…')>width do text=text:sub(1,(utf8.offset(text,-1) or 1)-1) end
    text=text..'…'
  end
  g.print(text,x,y)
end
function U:begin()
  self.items={};self.clip=nil;self.suspend=false;self.mx,self.my=love.mouse.getPosition()
end
function U.contains(_,w,x,y) return x>=w.x and y>=w.y and x<=w.x+w.w and y<=w.y+w.h end
function U:register(w)
  if self.suspend then return end
  if self.clip then
    local top=math.max(w.y,self.clip.y);local bottom=math.min(w.y+w.h,self.clip.y+self.clip.h)
    if bottom<=top then return end
    w.y,w.h=top,bottom-top
  end
  self.items[#self.items+1]=w
end
function U.box(_,x,y,w,h,color)
  U.color(color);love.graphics.rectangle('fill',x,y,w,h,4,4)
end
function U:button(id,label,x,y,w,h,action,selected,disabled)
  local hit={id=id,kind='button',x=x,y=y,w=w,h=h,action=action,disabled=disabled}
  local over=self:contains(hit,self.mx,self.my) and not self.suspend
  local pressed=self.active and self.active.widget.id==id
  self:box(x,y,w,h,(selected or pressed) and 'accentDim' or over and not disabled and 'hover' or 'raised')
  if selected then U.color('accent');love.graphics.rectangle('fill',x,y+8,2,h-16) end
  self:text(label,x+12,y+(h-15)/2,disabled and 'muted' or selected and 'accent' or 'ink',13,w-24)
  if self.focus==id and not self.suspend then U.color('accent');love.graphics.rectangle('line',x+0.5,y+0.5,w-1,h-1,4,4) end
  self:register(hit)
end
function U:input(id,value,x,y,w,h,change,options)
  options=options or {};local current=self.edit and self.edit.id==id
  local over=self.mx>=x and self.mx<=x+w and self.my>=y and self.my<=y+h and not self.suspend
  self:box(x,y,w,h,options.numeric and over and not current and 'hover' or 'input')
  local text=current and self.edit.text or tostring(value)
  if current and self.edit.all then self:box(x+5,y+5,w-10,h-10,'accentDim') end
  self:text(text,x+10,y+(h-15)/2,'ink',13,w-20)
  if current or self.focus==id then U.color(current and self.edit.error and 'danger' or 'accent');love.graphics.rectangle('line',x+0.5,y+0.5,w-1,h-1,4,4) end
  if current and not self.edit.all and math.floor(love.timer.getTime()*2)%2==0 then
    local caret=math.min(w-10,self.fonts[13]:getWidth(self.edit.text:sub(1,self.edit.cursor))+10)
    U.color('accent');love.graphics.line(x+caret,y+9,x+caret,y+h-9)
  end
  self:register{id=id,kind='input',x=x,y=y,w=w,h=h,value=tostring(value),change=change,options=options,scrub=options.scrub}
end
function U:number(id,label,value,x,y,w,change,options)
  local o=options or {};local display=value*(o.scale or 1)
  local scrub={value=display,step=o.step or 1,min=o.min or -math.huge,max=o.max or math.huge,
    decimals=o.integer and 0 or o.decimals or 1,integer=o.integer,change=function(v) return change(v/(o.scale or 1)) end,
    begin=o.begin,move=o.move and function(v) o.move(v/(o.scale or 1)) end,finish=o.finish,cancel=o.cancel}
  local a=self.active
  if a and (a.widget.id==id or a.widget.id==id..':scrub') and a.next then display=a.next end
  local focused=self.focus==id..':scrub'
  self:text(label,x,y+9,focused and 'accent' or 'secondary',13,w-120)
  if focused then U.color('accent');love.graphics.line(x,y+32,x+w-124,y+32) end
  self:input(id,('%.'..(o.decimals or 1)..'f'):format(display),x+w-112,y,112,40,function(text)
    local v=tonumber(text);if not v or v~=v or math.abs(v)==math.huge then return false end
    if o.integer then v=math.floor(v+0.5) end
    if v<(o.min or -math.huge) or v>(o.max or math.huge) then return false end
    return change(v/(o.scale or 1))
  end,{numeric=true,scrub=scrub})
  self:register{id=id..':scrub',kind='scrub',x=x,y=y,w=w-120,h=40,scrub=scrub}
end
local function clamp(v,n) return math.max(n.min,math.min(n.max,v)) end
local function rounded(v,n)
  local factor=10^n.decimals
  return clamp(math.floor(v*factor+0.5)/factor,n)
end
function U:commit()
  local e=self.edit;if not e then return true end
  if e.text~=e.initial then
    local ok,result=pcall(e.change,e.text)
    if not ok or result==false then e.error=true;return false end
  end
  self.edit=nil;love.keyboard.setTextInput(false);return true
end
function U:activate(w)
  self.focus=w.id
  if w.kind=='input' then
    self.edit={id=w.id,text=w.value,initial=w.value,cursor=#w.value,all=true,change=w.change,options=w.options}
    love.keyboard.setTextInput(true,w.x,w.y,w.w,w.h)
  elseif w.action then w.action() end
end
function U:mousepressed(x,y,button)
  if button~=1 then return false end
  for i=#self.items,1,-1 do
    local w=self.items[i]
    if self:contains(w,x,y) then
      local e=self.edit
      local edited=e and w.scrub and (e.id==w.id or e.id..':scrub'==w.id) and e.text~=e.initial and tonumber(e.text)
      if not self:commit() then return true end
      if not w.disabled then
        if edited and w.scrub.integer then edited=math.floor(edited+0.5) end
        local value=w.scrub and (edited or w.scrub.value) or w.value
        if edited then w.value=tostring(edited) end
        self.focus=w.id;self.active={widget=w,x=x,y=y,lastX=x,lastY=y,value=value,raw=value,moved=false}
        if w.kind=='drag' then w.begin(x,y);self.active.moved=true end
      end
      return true
    end
  end
  return not self:commit()
end
function U:mousemoved(x,y)
  local a=self.active;if not a then return false end;local w=a.widget
  local dx,dy=x-a.x,y-a.y
  if w.scrub and (a.moved or math.max(math.abs(dx),math.abs(dy))>3) then
    local n=w.scrub
    -- Lock to the initial direction so diagonal hand motion does not double the change.
    a.axis=a.axis or (math.abs(dx)>=math.abs(dy) and 'x' or 'y');a.moved=true
    local delta=a.axis=='x' and x-a.lastX or a.lastY-y
    local fine=love.keyboard.isDown('lshift','rshift') and 0.1 or 1
    a.raw=clamp(a.raw+delta*n.step*0.2*fine,n)
    local v=rounded(a.raw,n)
    if v~=(a.next or a.value) then
      if not a.started then if n.begin then n.begin() end;a.started=true end
      a.next=v;if n.move then n.move(v) end
    end
    a.lastX,a.lastY=x,y
  elseif w.kind=='drag' then w.move(x,y) end
  return true
end
function U:mousereleased(x,y,button)
  if button~=1 or not self.active then return false end
  self:mousemoved(x,y)
  local a=self.active;self.active=nil;local w=a.widget
  if w.scrub and a.moved then
    local n=w.scrub
    if a.started then
      if a.next==a.value and n.cancel then n.cancel()
      elseif n.finish then n.finish()
      elseif a.next~=a.value then n.change(a.next) end
    end
  elseif a.moved then
    if w.finish then w.finish() elseif a.next then w.change(a.next) end
  elseif self:contains(w,x,y) then self:activate(w) end
  return true
end
function U:textinput(text)
  local e=self.edit;if not e then return false end
  if e.all then e.text='';e.cursor=0;e.all=false end
  if #e.text+#text<=120 then e.text=e.text:sub(1,e.cursor)..text..e.text:sub(e.cursor+1);e.cursor=e.cursor+#text;e.error=false end
  return true
end
function U:keypressed(key)
  local a=self.active
  if a and (a.widget.scrub or a.widget.cancel) then
    if key=='escape' then
      local n=a.widget.scrub
      if n then
        if a.started and n.cancel then n.cancel() end
      elseif a.widget.cancel then a.widget.cancel() end
      self.active=nil
    end
    return true
  end
  local e=self.edit;local mod=love.keyboard.isDown('lgui','rgui','lctrl','rctrl')
  if e then
    if key=='escape' then self.edit=nil;love.keyboard.setTextInput(false)
    elseif key=='return' or key=='kpenter' then self:commit()
    elseif key=='tab' then if self:commit() then return self:keypressed('tab') end
    elseif mod and key=='a' then e.all=true
    elseif mod and key=='c' then if e.all then love.system.setClipboardText(e.text) end
    elseif mod and key=='v' then self:textinput(love.system.getClipboardText():gsub('[\r\n]',''))
    elseif key=='backspace' or key=='delete' then
      if e.all then e.text='';e.cursor=0;e.all=false
      elseif key=='backspace' and e.cursor>0 then
        local at=utf8.offset(e.text,-1,e.cursor+1);e.text=e.text:sub(1,at-1)..e.text:sub(e.cursor+1);e.cursor=at-1
      elseif key=='delete' and e.cursor<#e.text then local nextByte=utf8.offset(e.text,2,e.cursor+1) or #e.text+1;e.text=e.text:sub(1,e.cursor)..e.text:sub(nextByte) end
    elseif key=='home' then e.cursor=0;e.all=false
    elseif key=='end' then e.cursor=#e.text;e.all=false
    elseif key=='left' then e.cursor=e.cursor>0 and (utf8.offset(e.text,-1,e.cursor+1)-1) or 0;e.all=false
    elseif key=='right' then e.cursor=e.cursor<#e.text and ((utf8.offset(e.text,2,e.cursor+1) or #e.text+1)-1) or #e.text;e.all=false end
    return true
  end
  if key=='tab' then
    local index=0;for i,w in ipairs(self.items) do if w.id==self.focus then index=i end end
    local delta=love.keyboard.isDown('lshift','rshift') and -1 or 1
    for _=1,#self.items do index=(index-1+delta)%#self.items+1;if not self.items[index].disabled then self.focus=self.items[index].id;break end end
    return true
  end
  for _,w in ipairs(self.items) do if w.id==self.focus and not w.disabled then
    if w.key and w.key(key) then return true end
    if key=='return' or key=='kpenter' then self:activate(w);return true end
    if w.scrub and (key=='left' or key=='right' or key=='up' or key=='down') then
      local n=w.scrub;n.change(rounded(n.value+((key=='right' or key=='up') and n.step or -n.step),n));return true
    end
  end end
  return false
end
function U:release()
  if self.colorPicker then self.colorPicker:release() end
  for _,font in pairs(self.fonts) do font:release() end
end
return U
