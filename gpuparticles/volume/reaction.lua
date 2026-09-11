local U=require((...):gsub('reaction$','util'))
local R={};R.__index=R
function R.new(w,options)
  U.alive(w);options=options or {}
  U.keys(options,'from to temperatureAbove rate','reaction')
  local a,b=options.from,options.to
  assert(a and b and a~=b and a.world==w and b.world==w and not a.released and not b.released,'reaction materials must belong to this world')
  assert(b.model=='gas','volume reactions currently convert into gas only')
  assert(#w.reactions<16,'volume reaction limit is 16')
  local self=setmetatable({world=w,from=a,to=b,active=true,
    temperatureAbove=U.number(options.temperatureAbove,1,'reaction threshold',0,1000),
    rate=U.number(options.rate,1,'reaction rate',0,100)},R)
  w.reactions[#w.reactions+1]=self;return self
end
function R:setRate(rate) U.alive(self);self.rate=U.number(rate,nil,'reaction rate',0,100);return self end
function R:start() U.alive(self);self.active=true;return self end
function R:stop() U.alive(self);self.active=false;return self end
function R:release()
  if self.released then return end
  self.released=true
  for i,r in ipairs(self.world.reactions) do if r==self then table.remove(self.world.reactions,i);break end end
end
return R
