local D=require('editor_support.document')
local Presets=require('editor_support.presets')
local Runtime=require('editor_support.runtime')
local Storage=require('editor_support.storage')
local M={};M.__index=M
function M.new(options)
  options=options or {}
  local self=setmetatable({doc=Presets.make(options.preset or 1),selected=2,undoStack={},redoStack={},dirty=false,
    tab='Emitter',scroll=0,colorStop=1,sizeStop=1,burstStop=1,playing=true,speed=1,grid=true,solo=nil,
    status='Ready. Drag an emitter in the preview, or choose a property.',statusTime=0,pending=0,builds=0},M)
  self.selected=math.min(self.selected,#self.doc.layers);self:rebuild(1.8);return self
end
function M:layer() return self.doc.layers[self.selected] end
function M:message(text,error)
  self.status,self.statusTime,self.error=text,6,error or false
end
function M:rebuild(target)
  local ok,result=xpcall(function() return Runtime.new(self.doc) end,debug.traceback)
  self.pending=0
  if not ok then self:message('Preview could not rebuild: '..tostring(result),true);return false end
  if self.runtime then self.runtime:release() end
  self.runtime=result;self.runtime.solo=self.solo;self.builds=self.builds+1
  self.seekTarget=math.max(0,math.min(target or 0,self.doc.duration));return true
end
function M:beginEdit()
  if not self.before then self.before=D.copy(self.doc) end
end
function M:commitEdit()
  if not self.before then return end
  self.undoStack[#self.undoStack+1]=self.before
  if #self.undoStack>64 then table.remove(self.undoStack,1) end
  self.before=nil;self.redoStack={};self.dirty=true;self.pending=0.12
end
function M:cancelEdit()
  if self.before then self.doc=self.before;self.before=nil end
end
function M:change(fn)
  self:beginEdit()
  local ok,err=pcall(function() fn(self.doc,self:layer());D.validate(self.doc) end)
  if not ok then self:cancelEdit();self:message(tostring(err),true);return false end
  self:commitEdit();return true
end
function M:history(redo)
  self:cancelEdit()
  local source,target=redo and self.redoStack or self.undoStack,redo and self.undoStack or self.redoStack
  if #source==0 then return end
  target[#target+1]=D.copy(self.doc);self.doc=table.remove(source);self.selected=math.min(self.selected,#self.doc.layers)
  self.solo=nil;self.dirty=true;self.pending=0.01;self:message(redo and 'Redo' or 'Undo')
end
function M:select(index)
  self.selected=index;self.scroll=0;self.colorStop=1;self.sizeStop=1;self.burstStop=1
end
function M:add(duplicate)
  if #self.doc.layers>=D.maxLayers then self:message('A composition can have up to 12 layers.',true);return end
  local ok=self:change(function(doc,l)
    local nextLayer=duplicate and D.copy(l) or D.layer('Emitter '..(#doc.layers+1))
    if duplicate then nextLayer.name=nextLayer.name..' copy' end
    nextLayer.emitter.seed=(l.emitter.seed+97)%2147483646;doc.layers[#doc.layers+1]=nextLayer
  end)
  if ok then self:select(#self.doc.layers) end
end
function M:remove()
  if #self.doc.layers==1 then self:message('Keep at least one emitter layer.',true);return end
  self:change(function(doc) table.remove(doc.layers,self.selected) end)
  self.solo=nil;self:select(math.min(self.selected,#self.doc.layers))
end
function M:move(delta)
  local i,j=self.selected,self.selected+delta
  if j<1 or j>#self.doc.layers then return end
  self:change(function(doc) doc.layers[i],doc.layers[j]=doc.layers[j],doc.layers[i] end);self:select(j);self.solo=nil
end
function M:replace(doc)
  D.validate(doc);local previous=self.doc;self.doc=D.copy(doc)
  if not self:rebuild(doc.name=='Impact burst' and 0.35 or 1.8) then self.doc=previous;return false end
  self.selected=math.min(2,#doc.layers);self.undoStack={};self.redoStack={};self.dirty=false;self.scroll=0;self.solo=nil
  self.runtime.solo=nil;self.colorStop=1;self.sizeStop=1;self.burstStop=1;return true
end
function M:seek(time)
  if self.pending>0 then self:rebuild(time) else self.runtime:reset();self.seekTarget=math.max(0,math.min(time,self.doc.duration)) end
end
function M:play()
  if self.runtime.time>=self.doc.duration-1e-8 then self:seek(0) end
  self.playing=true;self.runtime.playing=true
end
function M:togglePlayback() if self.playing then self.playing=false else self:play() end end
function M:update(dt)
  self.statusTime=math.max(0,self.statusTime-dt)
  if self.pending>0 and not self.before then
    self.pending=self.pending-dt
    if self.pending<=0 then self:rebuild(self.seekTarget or self.runtime.time) end
  end
  if self.seekTarget then
    if self.runtime:advanceTo(self.seekTarget,32) then self.seekTarget=nil end
  elseif self.playing and not self.before then
    self.runtime:update(math.min(dt,0.1)*self.speed)
    if not self.runtime.playing then self.playing=false end
  end
end
function M:save()
  local ok,path=pcall(Storage.save,self.doc)
  if ok then self.dirty=false;self:message('Saved: '..path) else self:message('Save failed: '..tostring(path),true) end
  return ok,path
end
function M:export()
  local ok,path=pcall(Storage.export,self.doc)
  self:message(ok and ('Exported: '..path) or ('Export failed: '..tostring(path)),not ok);return ok,path
end
function M:release() if self.runtime then self.runtime:release() end end
return M
