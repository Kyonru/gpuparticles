-- Built-in monochrome sheets inherit each emitter's lifetime colors.
-- Only encoded PNG strings are cached; GPU resources belong to the runtime.
local S={entries={
  {id='sparks',name='Pixel sparks',file='pixel-spark-sheet.png',size=8,frames=3},
  {id='flame',name='Pixel flame',file='pixel-flame-sheet.png',size=16,frames=4},
  {id='smoke',name='Pixel smoke',file='pixel-smoke-sheet.png',size=16,frames=4},
  {id='splash',name='Pixel splash',file='pixel-splash-sheet.png',size=16,frames=4},
}}
local encoded={}
local masks={}
function masks.sparks(x,y,frame)
  local dx,dy=math.abs(x-3.5),math.abs(y-3.5)
  return (dx+dy<4-frame or (frame==0 and (dx<1 or dy<1))) and 1 or 0
end
function masks.flame(x,y,frame)
  if y<2+frame%2*2 or y>14 then return 0 end
  local center=7.5+math.floor(math.sin(y*0.6+frame*1.8)*1.4)
  local width=y<10 and (y-1)*0.4 or (15-y)*0.9+0.3
  if math.abs(x-center)>width then return 0 end
  return y>8 and math.abs(x-center)<1.5 and 1 or 0.65
end
function masks.smoke(x,y,frame)
  local radius=2.5+frame*1.2
  local dx,dy=x-7.5,y-8.5
  local core=dx*dx+dy*dy
  local lobe=(dx+2)^2+(dy+2.5)^2
  local edge=(dx-2.5)^2+(dy+1.5)^2
  if core>radius^2 and lobe>(radius*0.7)^2 and edge>(radius*0.65)^2 then return 0 end
  if frame==3 and (x+2*y)%3==0 then return 0 end
  return core<(radius-1)^2 and 1 or 0.5
end
function masks.splash(x,y,frame)
  local dx,dy=x-7.5,y-7.5;local radius=math.sqrt(dx*dx+dy*dy)
  if frame==0 then return radius<2.3 and 1 or 0 end
  local ring=2+frame*1.7
  if math.abs(radius-ring)>0.85 then return 0 end
  if frame>=2 and (x+y+frame)%4==0 then return 0 end
  return frame==3 and 0.75 or 1
end
function S.make(id)
  local entry
  for _,candidate in ipairs(S.entries) do if candidate.id==id then entry=candidate;break end end
  assert(entry,'Unknown built-in sprite sheet: '..tostring(id))
  if not encoded[id] then
    local size=entry.size
    local data=love.image.newImageData(size*entry.frames,size)
    data:mapPixel(function(x,y) return 1,1,1,masks[id](x%size,y,math.floor(x/size)) end)
    local png=data:encode('png');data:release()
    encoded[id]=love.data.encode('string','base64',png:getString());png:release()
  end
  return {name=entry.file,png=encoded[id],columns=entry.frames,rows=1,frames=entry.frames,filter='nearest'}
end
function S.identify(sprite)
  for _,entry in ipairs(S.entries) do
    if sprite.name==entry.file and sprite.png==S.make(entry.id).png then return entry.id end
  end
end
return S
