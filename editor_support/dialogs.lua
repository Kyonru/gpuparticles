local U=require('editor_support.ui')
local Presets=require('editor_support.presets')
local Storage=require('editor_support.storage')
local D={}
function D.draw(app)
  local u,m,g,modal=app.ui,app.model,love.graphics,app.modal
  local w,h=g.getDimensions();local width,height=580,modal.kind=='help' and 620 or modal.kind=='presets' and 548 or 444
  local x,y=(w-width)/2,(h-height)/2
  g.setColor(0,0,0,0.66);g.rectangle('fill',0,0,w,h)
  u:box(x,y,width,height,'raised');u.suspend=false;u.items={};u.clip=nil
  local titles={presets='Start from an effect',files='Open a project',help='A small guide to Particle Studio',confirm='Unsaved changes',project='Project settings'}
  u:text(titles[modal.kind],x+24,y+24,'ink',24,width-96)
  u:button('modal:close','X',x+width-56,y+20,36,40,function() app:close() end)
  if modal.kind=='presets' then
    local notes={'Flame, rising embers, and a smoke veil.','Two layers of curled, orbiting light.','Stateful droplets, a circle, a floor, and mist.','Flash, timed sparks, and lingering afterglow.',
      'Embedded sprite sheet, crisp pixels, and a stepped palette.','Dissolve, distortion, outlines, and a soft glow.'}
    for i,name in ipairs(Presets.names) do
      local row=y+88+(i-1)*72
      u:button('preset:'..i,name,x+24,row,width-48,44,function() app:replace(Presets.make(i)) end)
      u:text(notes[i],x+36,row+48,'secondary',11,width-72)
    end
  elseif modal.kind=='files' then
    local files=modal.files or {};local offset=modal.scroll or 0
    u:text('Saved projects · or drop a project .json onto the window.',x+24,y+72,'secondary',13,width-48)
    if #files==0 then u:text('No saved projects yet. Save your composition first.',x+24,y+132,'muted',13,width-48) end
    for i=offset+1,math.min(#files,offset+4) do
      u:button('file:'..i,files[i],x+24,y+108+(i-offset-1)*48,width-48,40,function()
        local ok,doc=pcall(Storage.load,files[i]);if ok then app:replace(doc) else m:message(tostring(doc),true) end
      end)
    end
    u:button('files:previous','Previous',x+24,y+height-108,112,36,function() modal.scroll=math.max(0,offset-4) end,false,offset==0)
    u:button('files:next','Next',x+width-136,y+height-108,112,36,function() modal.scroll=math.min(math.max(0,#files-4),offset+4) end,false,offset+4>=#files)
    u:button('files:folder','Show project folder',x+24,y+height-64,width-48,40,function()
      love.filesystem.createDirectory('projects')
      local path=love.filesystem.getSaveDirectory():gsub('[^%w%-%._~/]',function(c) return ('%%%02X'):format(c:byte()) end)
      love.system.openURL('file://'..path..'/projects')
    end)
  elseif modal.kind=='confirm' then
    g.setFont(u.fonts[15]);U.color('secondary');g.printf(modal.message or 'Save this composition before continuing?',x+24,y+104,width-48)
    u:button('confirm:save','Save and continue',x+24,y+height-176,width-48,40,function() if m:save() then local action=modal.action;app:close();action() end end,true)
    u:button('confirm:discard','Discard changes',x+24,y+height-128,width-48,40,function() local action=modal.action;app:close();action() end)
    u:button('confirm:cancel','Cancel',x+24,y+height-80,width-48,40,function() app:close() end)
  elseif modal.kind=='project' then
    u:text('Scene size: 960 × 640 pixels. Export uses the same coordinates.',x+24,y+80,'secondary',13,width-48)
    u:number('project:duration','Loop duration / seconds',m.doc.duration,x+24,y+128,width-48,function(v)
      return m:change(function(doc)
        doc.duration=v
        for _,layer in ipairs(doc.layers) do
          layer.start=math.min(layer.start,v)
          for _,b in ipairs(layer.bursts) do b.time=math.min(b.time,v) end
        end
      end)
    end,{min=0.25,max=30,step=0.25,decimals=2})
    u:button('project:loop',m.doc.loop and 'Loop playback enabled' or 'Play once',x+24,y+184,width-48,40,function() m:change(function(doc) doc.loop=not doc.loop end) end,m.doc.loop)
    u:text('Shortening the project moves later burst events to its end.',x+24,y+244,'muted',13,width-48)
    u:button('project:done','Done',x+24,y+height-64,width-48,40,function() app:close() end,true)
  else
    local rows={
      {'Build a composition','Add or duplicate emitters. Visibility exports; solo is preview-only.'},
      {'Shape an emitter','Click a number to type; drag its label to scrub. Scroll the inspector.'},
      {'Draw the motion','Drag the origin. Shift-drag the circle; Alt-drag the attractor.'},
      {'Shape its lifetime','Style edits up to 32 color/size stops. Drag size-curve nodes.'},
      {'Textures and shaders','Drop a PNG; Texture sets frames. Effects adds pixels and shaders.'},
      {'Compose in time','Timing sets emission windows and bursts. Drag the playhead to seek.'},
      {'Save or take it to a game','Save creates a JSON project. Export Lua needs only gpuparticles/.'},
      {'Keyboard','Space play/pause · Cmd/Ctrl S save · Z undo · Shift Z redo'},
      {'More shortcuts','Cmd/Ctrl D duplicate · E export · O open · Tab focus · Enter activate'},
    }
    for i,row in ipairs(rows) do local py=y+86+(i-1)*52;u:text(row[1],x+24,py,'ink',13);u:text(row[2],x+24,py+20,'secondary',11,width-48) end
    u:text('Stateful seeks replay in batches. Analytic effects stay analytic.',x+24,y+height-36,'accent',11,width-48)
  end
end
return D
