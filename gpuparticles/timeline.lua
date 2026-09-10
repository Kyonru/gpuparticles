-- A piecewise translation from emission time to wall time preserves living
-- particles across any number of pauses. Only control changes upload this LUT.
local M={}
function M.upload(e)
  local segments=e.timeline
  local data=love.image.newImageData(#segments,1,'rgba32f')
  for i,s in ipairs(segments) do data:setPixel(i-1,0,s[1],s[2],0,1) end
  local texture=love.graphics.newImage(data);texture:setFilter('nearest','nearest');data:release()
  if e.timelineTexture then e.timelineTexture:release() end
  e.timelineTexture=texture
end
function M.new(e)
  e.emissionTime=0
  e.remaining=e.config.emitterLifetime
  e.timeline={{0,e.time}}
  M.upload(e)
end
function M.advance(e,dt)
  e.time=e.time+dt
  if not e.running then return end
  local emitted=e.remaining<0 and dt or math.min(dt,e.remaining)
  e.emissionTime=e.emissionTime+emitted
  if e.remaining>=0 then
    e.remaining=math.max(0,e.remaining-emitted)
    if e.remaining==0 then e.running=false end
  end
end
function M.resume(e)
  local at=e.emissionTime
  -- At a boundary, the earlier segment owns the exact endpoint.
  local segment={at,e.time}
  if at==0 then e.timeline[1]=segment
  elseif e.timeline[#e.timeline][1]~=at then e.timeline[#e.timeline+1]=segment
  else e.timeline[#e.timeline]=segment end
  M.upload(e)
end
function M.wallBirth(e,birth)
  local segments=e.timeline
  local lo,hi=1,#segments
  while lo<hi do
    local mid=math.ceil((lo+hi)/2)
    if segments[mid][1]<birth then lo=mid else hi=mid-1 end
  end
  local s=segments[lo]
  return birth+s[2]-s[1]
end
function M.send(e,s)
  if s:hasUniform('u_emissionTime') then s:send('u_emissionTime',e.emissionTime) end
  if s:hasUniform('u_timeline') then s:send('u_timeline',e.timelineTexture);s:send('u_timelineCount',#e.timeline) end
end
function M.release(e) if e.timelineTexture then e.timelineTexture:release();e.timelineTexture=nil end end
return M
