local Model=require('editor_support.model')
local UI=require('editor_support.ui')
local View=require('editor_support.view')
local Storage=require('editor_support.storage')
local A={};A.__index=A
function A.new(options) return setmetatable({model=Model.new(options),ui=UI.new(),modal=nil,allowQuit=false},A) end
function A:open(kind)
  if not self.ui:commit() then return end
  self.modal={kind=kind,files=kind=='files' and Storage.list() or nil,scroll=0,previousFocus=self.ui.focus};self.ui.focus=nil;self.ui.items={}
end
function A:close()
  if not self.ui:commit() then return end
  self.ui.focus=self.modal and self.modal.previousFocus or nil;self.modal=nil
end
function A:guard(action)
  if not self.model.dirty then self:close();action();return end
  self.modal={kind='confirm',action=action,message='Your composition has unsaved changes. Save it before continuing?'};self.ui.focus=nil
end
function A:replace(doc) self:guard(function()
  if self.model:replace(doc) then
    if self.model:layer().selfCollision.enabled then self.model.tab='Motion' end
    self.model:message('Loaded '..doc.name)
  end
end) end
function A:update(dt) self.model:update(dt) end
function A:draw() View.draw(self) end
function A:mousepressed(x,y,button)
  if self.ui:mousepressed(x,y,button) or self.modal then return end
  if button~=1 or not self.layout then return end
  local wx,wy,inside=View.world(self.layout,x,y);if not inside then return end
  local layer=self.model:layer()
  self.dragTarget=love.keyboard.isDown('lshift','rshift') and layer.circle.enabled and 'circle' or
    love.keyboard.isDown('lalt','ralt') and layer.attractor.enabled and 'attractor' or 'origin'
  self.model:beginEdit();self:dragWorld(wx,wy)
end
function A:dragWorld(x,y)
  local b=View.bounds(self.layout)
  x=math.max(-2000,math.min(3000,math.max(b.x,math.min(b.x+b.w,x))))
  y=math.max(-2000,math.min(3000,math.max(b.y,math.min(b.y+b.h,y))))
  local l=self.model:layer()
  if self.dragTarget=='origin' then l.emitter.position[1],l.emitter.position[2]=x,y
  else l[self.dragTarget].x,l[self.dragTarget].y=x,y end
end
function A:mousemoved(x,y)
  if self.ui:mousemoved(x,y) then return end
  if self.dragTarget then local wx,wy=View.world(self.layout,x,y);self:dragWorld(wx,wy) end
end
function A:mousereleased(x,y,button)
  if self.ui:mousereleased(x,y,button) then return end
  if self.dragTarget and button==1 then self.dragTarget=nil;self.model:commitEdit() end
end
function A:wheelmoved(_,y)
  if self.modal then
    if self.modal.kind=='files' then
      local delta=y>0 and -1 or y<0 and 1 or 0
      self.modal.scroll=math.max(0,math.min(math.max(0,#self.modal.files-4),self.modal.scroll+delta))
    end
    return
  end
  local x=love.mouse.getX()
  if self.layout and x>=self.layout.width-self.layout.right then self.model.scroll=math.max(0,math.min(self.model.scrollMax or 0,self.model.scroll-y*44)) end
end
function A:keypressed(key)
  if self.ui:keypressed(key) then return end
  if self.modal then if key=='escape' then self:close() end;return end
  local m=self.model;local mod=love.keyboard.isDown('lgui','rgui','lctrl','rctrl')
  if mod and key=='s' then m:save()
  elseif mod and key=='e' then m:export()
  elseif mod and key=='o' then self:open('files')
  elseif mod and key=='d' then m:add(true)
  elseif mod and key=='z' then m:history(love.keyboard.isDown('lshift','rshift'))
  elseif mod and key=='y' then m:history(true)
  elseif key=='space' then m:togglePlayback()
  elseif key=='r' then m:seek(0)
  elseif key=='delete' or key=='backspace' then m:remove()
  elseif key=='f1' then self:open('help')
  elseif key=='escape' then self:requestQuit()
  elseif key=='pageup' or key=='pagedown' then m.scroll=math.max(0,math.min(m.scrollMax or 0,m.scroll+(key=='pagedown' and 264 or -264))) end
end
function A:filedropped(file)
  if self.modal or not self.ui:commit() or self.model.before then self.model:message('Finish the current edit or close the dialog before importing.',true);return end
  local name=file:getFilename():match('[^/\\]+$') or 'Imported texture.png'
  local png=name:lower():match('%.png$')
  local ok,result=pcall(function()
    assert(png or name:lower():match('%.json$'),'Drop a PNG texture or a saved project .json file.')
    assert(file:getSize()<=(png and 1048576 or 8000000),png and 'Use a PNG no larger than 1 MB.' or 'Project exceeds 8 MB.')
    assert(file:open('r'));return assert(file:read())
  end)
  if file:isOpen() then file:close() end
  if ok and png then self.model:importTexture(result,#name<=120 and name or 'Imported texture.png');return end
  if ok then ok,result=pcall(Storage.decode,result) end
  if ok then self:replace(result) else self.model:message('Import failed: '..tostring(result),true) end
end
function A:requestQuit()
  if self.allowQuit then return false end
  if not self.ui:commit() then return true end
  if self.model.before then
    local ok=pcall(require('editor_support.document').validate,self.model.doc)
    if ok then self.model:commitEdit() else self.model:cancelEdit() end
  end
  self:guard(function() self.allowQuit=true;love.event.quit() end);return true
end
function A:release() self.ui:release();self.model:release() end
function A.install()
  local app,frames,smoke,capture,captured,requested=nil,0,false,false,false,false
  local compact,preset,tab=false,1,nil
  for _,value in ipairs(arg or {}) do
    if value=='--smoke' then smoke=true elseif value=='--capture' then capture=true elseif value=='--compact' then compact=true
    elseif value:match('^%-%-preset=[1-7]$') then preset=tonumber(value:sub(-1)) end
    if value=='--texture-tab' then tab='Texture' end
  end
  function love.load()
    love.filesystem.setIdentity('gpuparticles-studio')
    love.window.setMode(compact and 1120 or 1440,compact and 760 or 900,{resizable=true,minwidth=1120,minheight=760,vsync=1})
    love.window.setTitle('Particle Studio — GPU effect editor');love.keyboard.setKeyRepeat(true);app=A.new{preset=preset}
    if preset==3 then app.model:select(1) end
    if smoke then app.model.playing=false;app.model.tab=preset>=5 and 'Effects' or 'Style' end
    if preset==7 then app.model.tab='Motion' end
    if tab then app.model.tab=tab end
  end
  function love.update(dt)
    app:update(dt);frames=frames+1
    if smoke and frames>=8 and not app.model.seekTarget and (not capture or captured) then
      print('Editor standalone render PASS');app.allowQuit=true;love.event.quit()
    end
  end
  function love.draw()
    app:draw()
    if capture and frames>=65 and love.timer.getFPS()>0 and not app.model.seekTarget and not requested then
      requested=true;love.graphics.captureScreenshot(function(data)
        local file=tab and 'editor-texture.png' or preset==7 and (compact and 'editor-self-compact.png' or 'editor-self.png') or preset==5 and (compact and 'editor-pixel-compact.png' or 'editor-pixel.png') or preset==6 and 'editor-shaders.png' or compact and 'editor-compact.png' or preset==3 and 'editor-collision.png' or 'editor.png'
        data:encode('png',file);data:release();captured=true
        print('EDITOR_CAPTURE '..love.filesystem.getSaveDirectory()..'/'..file)
      end)
    end
  end
  function love.mousepressed(x,y,b) app:mousepressed(x,y,b) end
  function love.mousemoved(x,y) app:mousemoved(x,y) end
  function love.mousereleased(x,y,b) app:mousereleased(x,y,b) end
  function love.wheelmoved(x,y) app:wheelmoved(x,y) end
  function love.keypressed(key) app:keypressed(key) end
  function love.textinput(text) app.ui:textinput(text) end
  function love.filedropped(file) app:filedropped(file) end
  function love.quit()
    if app and app:requestQuit() then return true end
    if app then app:release() end
  end
  function love.errorhandler(message) print(message);return function() return 1 end end
end
return A
