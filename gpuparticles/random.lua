-- Park–Miller fits exactly in Lua's double mantissa; independent of global RNG.
local R={}
R.__index=R
function R:setSeed(seed) self.state=math.floor(math.abs(seed))%2147483646+1 end
function R:random()
  self.state=(self.state*16807)%2147483647
  return (self.state-1)/2147483646
end
function R:randomNormal(sigma)
  return math.sqrt(-2*math.log(math.max(self:random(),1e-12)))*math.cos(self:random()*math.pi*2)*sigma
end
function R.release() end
return {new=function(seed) local r=setmetatable({},R);r:setSeed(seed);return r end}
