local C={};C.__index=C
function C.new(defaultName,options)
  local enabled,name=false,defaultName
  for _,value in ipairs(arg or {}) do
    if value=='--gif' then enabled=true end
    local requested=value:match('^%-%-gif%-name=([%w%-]+)$')
    if requested then name=requested end
  end
  if not enabled then return nil end
  options=options or {}
  return setmetatable({name=name,start=options.start or 30,every=options.every or 5,count=options.count or 24,
    index=1,pending=false,done=false},C)
end
function C:draw(frame)
  if self.done or self.pending or frame<self.start+(self.index-1)*self.every then return end
  self.pending=true
  local index=self.index
  love.graphics.captureScreenshot(function(data)
    local file=('%s-frame-%03d.png'):format(self.name,index)
    data:encode('png',file);data:release()
    self.index=index+1;self.pending=false
    if index==self.count then
      self.done=true
      print(('GIF_FRAMES %s/%s-frame-%%03d.png'):format(love.filesystem.getSaveDirectory(),self.name))
    end
  end)
end
return C
