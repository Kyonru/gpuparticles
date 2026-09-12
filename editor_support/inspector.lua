local U=require('editor_support.ui')
local I={tabs={'Emitter','Motion','Style','Texture','Effects','Timing'}}
local function get(t,path) for _,k in ipairs(path) do t=t[k] end;return t end
local function put(t,path,v) for i=1,#path-1 do t=t[path[i]] end;t[path[#path]]=v end
function I.draw(app,x,top,w,bottom)
  local m,u=app.model,app.ui;local l=m:layer();local g=love.graphics
  u:text('INSPECTOR',x+16,top+16,'muted',11)
  u:text(l.name,x+16,top+37,'ink',19,w-32)
  local tabW=(w-24)/3
  for i,name in ipairs(I.tabs) do u:button('tab:'..name,name,x+12+(i-1)%3*tabW,top+72+math.floor((i-1)/3)*44,tabW-2,40,function() m.tab=name;m.scroll=0 end,m.tab==name) end
  local contentTop=top+172;local y=contentTop-m.scroll;local left,width=x+16,w-32
  g.setScissor(x,contentTop,w,bottom-contentTop);u.clip={y=contentTop,h=bottom-contentTop}
  local function title(label) u:text(label,left,y+8,'ink',13);y=y+36 end
  local function paragraph(text,size)
    local font=u.fonts[size or 11];g.setFont(font);U.color('secondary')
    local _,lines=font:getWrap(text,width);g.printf(text,left,y,width)
    y=y+#lines*font:getHeight()*font:getLineHeight()+16
  end
  local function number(label,path,lo,hi,step,decimals,scale,integer)
    local id=table.concat(path,'.')
    local options={min=lo,max=hi,step=step,decimals=decimals,scale=scale,integer=integer,
      begin=function() m:beginEdit() end,
      move=function(v) put(m:layer(),path,v) end,
      cancel=function() m:cancelEdit() end,
      finish=function()
        local ok,err=pcall(require('editor_support.document').validate,m.doc)
        if ok then m:commitEdit() else m:cancelEdit();m:message(tostring(err),true) end
      end}
    u:number(id,label,get(l,path),left,y,width,function(v) return m:change(function(_,layer) put(layer,path,v) end) end,options);y=y+44
  end
  local function toggle(label,path)
    local value=get(l,path)
    u:button(table.concat(path,'.'),(value and 'ON   ' or 'OFF  ')..label,left,y,width,40,function()
      m:change(function(_,layer) put(layer,path,not value) end)
    end,value);y=y+48
  end
  local function select(label,path,values)
    local value=get(l,path)
    u:button(table.concat(path,'.'),label..'  /  '..tostring(value),left,y,width,40,function()
      local index=1;for i,v in ipairs(values) do if v==value then index=i end end
      m:change(function(_,layer) put(layer,path,values[index%#values+1]) end)
    end);y=y+48
  end
  if m.tab=='Emitter' then
    u:text('Layer name',left,y+9,'secondary',13)
    u:input('layer:name',l.name,left+96,y,width-96,36,function(v) return m:change(function(_,layer) layer.name=v end) end);y=y+48
    title('Emission')
    number('Capacity',{'emitter','max'},1,l.selfCollision.enabled and require('editor_support.document').selfCollisionLimit or 250000,100,0,nil,true)
    number('Particles / sec',{'emitter','rate'},0,100000,100,0)
    number('Lifetime min',{'emitter','lifetime',1},0.01,l.emitter.lifetime[2],0.1,2)
    number('Lifetime max',{'emitter','lifetime',2},l.emitter.lifetime[1],30,0.1,2)
    number('Seed',{'emitter','seed'},0,2147483646,1,0,nil,true)
    title('Spawn shape')
    number('Position X',{'emitter','position',1},-2000,3000,5,0)
    number('Position Y',{'emitter','position',2},-2000,3000,5,0)
    number('Direction °',{'emitter','direction'},-720,720,5,0,180/math.pi)
    number('Spread °',{'emitter','spread'},0,360,5,0,180/math.pi)
    number('Speed min',{'emitter','speed',1},-4000,l.emitter.speed[2],5,0)
    number('Speed max',{'emitter','speed',2},l.emitter.speed[1],4000,5,0)
    select('Area',{'emitter','emissionArea','distribution'},{'none','uniform','normal','ellipse','borderellipse','borderrectangle'})
    number('Area width / 2',{'emitter','emissionArea','x'},0,500,2,0)
    number('Area height / 2',{'emitter','emissionArea','y'},0,500,2,0)
    number('Area angle °',{'emitter','emissionArea','angle'},-720,720,5,0,180/math.pi)
    toggle('Direction follows area',{'emitter','emissionArea','directionRelative'})
  elseif m.tab=='Motion' then
    title('Particles against particles')
    local enabled=l.selfCollision.enabled
    u:button('selfCollision.enabled',(enabled and 'ON   ' or 'OFF  ')..'Self collision / 2048 max',left,y,width,40,function()
      local capacity=m:layer().emitter.max
      m:change(function(_,layer)
        layer.selfCollision.enabled=not enabled
        if not enabled then layer.emitter.max=math.min(layer.emitter.max,require('editor_support.document').selfCollisionLimit) end
      end)
      if not enabled and capacity>m:layer().emitter.max then m:message(('Particle collisions enabled; capacity reduced from %d to 2048. Undo restores it.'):format(capacity)) end
    end,enabled);y=y+48
    if enabled then
      number('Contact radius',{'selfCollision','radius'},0.1,64,0.5,1)
      number('Particle bounce',{'selfCollision','bounce'},0,1,0.05,2)
      number('Separation',{'selfCollision','strength'},0,1,0.05,2)
      number('Iterations',{'selfCollision','iterations'},1,4,1,0,nil,true)
      paragraph('Approximate equal-radius circles within this layer. More particles and iterations cost more GPU time. Use a smaller timestep for fast motion.')
    end
    title('Base motion')
    number('Gravity X',{'emitter','gravity',1},-4000,4000,10,0)
    number('Gravity Y',{'emitter','gravity',2},-4000,4000,10,0)
    number('Damping',{'emitter','damping'},0,20,0.1,2)
    number('Radial accel.',{'emitter','radialAcceleration'},-3000,3000,10,0)
    number('Tangential accel.',{'emitter','tangentialAcceleration'},-3000,3000,10,0)
    toggle('Sinusoidal turbulence',{'turbulence','enabled'})
    if l.turbulence.enabled then
      number('Amplitude X',{'turbulence','amplitude',1},0,300,2,1);number('Amplitude Y',{'turbulence','amplitude',2},0,300,2,1)
      number('Frequency X',{'turbulence','frequency',1},0,30,0.1,2);number('Frequency Y',{'turbulence','frequency',2},0,30,0.1,2)
    end
    toggle('Curl noise',{'curl','enabled'})
    if l.curl.enabled then number('Amplitude',{'curl','amplitude'},0,200,1,1);number('Frequency',{'curl','frequency'},0,10,0.1,2) end
    title('Forces at current position')
    toggle('Attractor',{'attractor','enabled'})
    if l.attractor.enabled then
      number('Center X',{'attractor','x'},-2000,3000,5,0);number('Center Y',{'attractor','y'},-2000,3000,5,0)
      -- Inverse-square coefficient / 100² gives acceleration at a useful scene distance.
      number('Strength',{'attractor','strength'},-1000,1000,1,1,1/10000)
      paragraph('Pull at 100 px (px/s²), before softening. Negative values repel.')
      number('Softening',{'attractor','softening'},1,300,2,0)
    end
    toggle('Procedural flow field',{'flow','enabled'})
    if l.flow.enabled then number('Strength',{'flow','strength'},-1000,1000,10,0);number('Frequency',{'flow','frequency'},0.1,12,0.1,2) end
    title('Collision')
    toggle('Ground plane',{'ground','enabled'});if l.ground.enabled then number('Floor Y',{'ground','y'},-2000,3000,5,0) end
    toggle('Circle obstacle',{'circle','enabled'})
    if l.circle.enabled then number('Circle X',{'circle','x'},-2000,3000,5,0);number('Circle Y',{'circle','y'},-2000,3000,5,0);number('Radius',{'circle','radius'},1,300,2,0) end
    if l.circle.enabled or l.ground.enabled then
      select('On contact',{'response','mode'},{'bounce','slide','stop','disappear','respawn'})
      number('Particle radius',{'response','radius'},0,40,0.5,1);number('Bounce',{'response','bounce'},0,1,0.05,2);number('Friction',{'response','friction'},0,1,0.05,2)
    end
  elseif m.tab=='Style' then
    select('Blending',{'emitter','blendMode'},{'add','alpha'})
    y=require('editor_support.curves').draw(app,left,y,width)
    number('Size variation',{'emitter','sizeVariation'},0,1,0.05,2)
    number('Spin min',{'emitter','spin',1},-100,l.emitter.spin[2],0.2,2)
    number('Spin max',{'emitter','spin',2},l.emitter.spin[1],100,0.2,2)
    number('Rotation min °',{'emitter','rotation',1},-720,l.emitter.rotation[2]*180/math.pi,5,0,180/math.pi)
    number('Rotation max °',{'emitter','rotation',2},l.emitter.rotation[1]*180/math.pi,720,5,0,180/math.pi)
    toggle('Rotate with velocity',{'emitter','relativeRotation'})
  elseif m.tab=='Texture' then
    title('Particle image')
    local sprites=require('editor_support.sprites');local selected=sprites.identify(l.sprite);local cell=(width-8)/2
    for i,entry in ipairs(sprites.entries) do
      u:button('texture:builtin:'..entry.id,entry.name,left+(i-1)%2*(cell+8),y+math.floor((i-1)/2)*48,cell,40,function()
        m:change(function(_,layer) layer.sprite=sprites.make(entry.id) end)
      end,selected==entry.id)
    end
    y=y+96
    paragraph('Choose a built-in sheet or drop a PNG. Images travel with your project.',13)
    local emitter=m.runtime.emitters[m.selected]
    U.color('canvas');g.rectangle('fill',left,y,width,96,4,4)
    if emitter then
      local image=emitter.texture;local iw,ih=image:getDimensions();local scale=math.min((width-24)/iw,80/ih)
      g.setColor(1,1,1,1);g.draw(image,left+(width-iw*scale)/2,y+(96-ih*scale)/2,0,scale,scale)
    end
    y=y+108
    u:text(l.sprite.png~='' and l.sprite.name or 'Generated '..l.shape,left,y,'ink',13,width);y=y+28
    if l.sprite.png~='' then
      u:button('texture:remove','Use generated shape',left,y,width,40,function()
        m:change(function(_,layer) layer.sprite=require('editor_support.document').layer().sprite end)
      end);y=y+48
      title('Sprite sheet · frames over lifetime')
      number('Columns',{'sprite','columns'},1,256,1,0,nil,true)
      number('Rows',{'sprite','rows'},1,256,1,0,nil,true)
      number('Frames',{'sprite','frames'},1,math.min(256,l.sprite.columns*l.sprite.rows),1,0,nil,true)
      paragraph('Frames run left to right, then top to bottom. Billboards are square.')
    else select('Particle shape',{'shape'},{'disc','spark','ring','smoke'}) end
    select('Filtering',{'sprite','filter'},{'linear','nearest'})
    u:text('PNG · up to 1024 × 1024 · 1 MB per image',left,y,'muted',11,width);y=y+32
  elseif m.tab=='Effects' then
    title('Pixel grid')
    select('World pixels / cell',{'appearance','pixelSize'},{1,2,4,8,16})
    paragraph('1 = full resolution. Larger cells use nearest scaling; motion and collision stay precise.')
    title('Layer shader')
    number('Dissolve',{'appearance','dissolve'},0,1,0.05,2)
    number('Outline / cells',{'appearance','outline'},0,8,0.5,1)
    if l.appearance.outline>0 then
      y=require('editor_support.colorpicker').draw(app,'outline','Outline color',left,y,width,function(layer) return layer.appearance.outlineColor end)
      for i,label in ipairs{'Red','Green','Blue'} do number('Outline '..label,{'appearance','outlineColor',i},0,1,0.05,2) end
    end
    select('Palette levels',{'appearance','levels'},{0,2,3,4,6,8,16,32})
    u:text('0 = original colors; levels apply per channel.',left,y,'muted',11,width);y=y+28
    y=require('editor_support.colorpicker').draw(app,'tint','Tint',left,y,width,function(layer) return layer.appearance.tint end)
    for i,label in ipairs{'Red','Green','Blue'} do number('Tint '..label,{'appearance','tint',i},0,1,0.05,2) end
    number('Distortion / cells',{'appearance','distortion'},0,20,0.5,1)
    number('Glow strength',{'appearance','glow'},0,2,0.05,2)
    if l.appearance.glow>0 then number('Glow radius / cells',{'appearance','glowRadius'},1,16,0.5,1) end
    paragraph('Effects process this layer together. Glow adds a soft local halo.')
    u:button('effects:reset','Reset appearance',left,y,width,40,function()
      m:change(function(_,layer) layer.appearance=require('editor_support.document').layer().appearance end)
    end);y=y+48
  else
    title('Emission window')
    number('Start / sec',{'start'},0,m.doc.duration,0.1,2)
    number('Duration / sec',{'span'},0.01,30,0.1,2)
    u:text('Particles keep aging after emission ends.',left,y,'muted',11,width);y=y+32
    title('Timed bursts')
    for i,b in ipairs(l.bursts) do
      u:button('burst:select:'..i,('%02d    %.2f s     %d particles'):format(i,b.time,b.count),left,y,width,40,function() m.burstStop=i end,m.burstStop==i);y=y+44
    end
    u:button('burst:add','+ Add burst at playhead',left,y,width,40,function()
      if #l.bursts>=32 then m:message('Use up to 32 bursts per emitter.',true);return end
      m:change(function(_,layer) layer.bursts[#layer.bursts+1]={time=math.min(m.runtime.time,m.doc.duration),count=256} end);m.burstStop=#m:layer().bursts
    end);y=y+48
    m.burstStop=math.min(m.burstStop,math.max(1,#l.bursts))
    if l.bursts[m.burstStop] then
      number('Burst time',{'bursts',m.burstStop,'time'},0,m.doc.duration,0.05,2)
      number('Particle count',{'bursts',m.burstStop,'count'},1,250000,16,0,nil,true)
      u:button('burst:delete','Remove burst',left,y,width,40,function() m:change(function(_,layer) table.remove(layer.bursts,m.burstStop) end) end);y=y+48
    end
    u:text('Use rate = 0 for a burst-only emitter.',left,y,'muted',11,width);y=y+32
  end
  m.scrollMax=math.max(0,y+m.scroll-bottom+16)
  g.setScissor();u.clip=nil
  if m.scrollMax>0 then
    U.color('line');g.rectangle('fill',x+w-5,contentTop,3,bottom-contentTop)
    local thumb=math.max(30,(bottom-contentTop)^2/(bottom-contentTop+m.scrollMax))
    U.color('secondary');g.rectangle('fill',x+w-5,contentTop+(bottom-contentTop-thumb)*math.min(1,m.scroll/m.scrollMax),3,thumb)
  end
end
return I
