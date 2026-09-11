-- A layer compositor, shared verbatim with standalone Lua exports.
local A={};A.__index=A
local source=[[#pragma language glsl3
uniform vec2 u_texel;
uniform vec2 u_cellOrigin;
uniform vec4 u_region;
uniform float u_time;
uniform float u_dissolve;
uniform float u_outline;
uniform vec3 u_outlineColor;
uniform float u_levels;
uniform vec3 u_tint;
uniform float u_distortion;
uniform float u_glow;
uniform float u_glowRadius;
vec4 sampleLayer(Image tex,vec2 uv) {
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return vec4(0.0);
    vec4 c=Texel(tex,uv);
    float n=fract(sin(dot(floor(uv/u_texel)+u_cellOrigin,vec2(12.9898,78.233)))*43758.5453);
    return c*step(u_dissolve,n);
}
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
    vec2 worldUV=uv*u_region.zw+u_region.xy;
    uv+=vec2(sin(worldUV.y*45.0-u_time*3.0),cos(worldUV.x*37.0+u_time*2.0))*u_texel*u_distortion;
    vec4 c=sampleLayer(tex,uv);
    // Input and output are premultiplied, including transparent filtered edges.
    vec3 rgb=c.a>0.00001 ? c.rgb/c.a : vec3(0.0);
    if (u_levels>1.0) rgb=floor(clamp(rgb,0.0,1.0)*(u_levels-1.0)+0.5)/(u_levels-1.0);
    c.rgb=rgb*u_tint*c.a;
    float edge=0.0;vec4 halo=vec4(0.0);
    for (int i=0;i<8;i++) {
        float angle=float(i)*0.785398163;
        vec2 direction=vec2(cos(angle),sin(angle));
        if (u_outline>0.0) edge=max(edge,sampleLayer(tex,uv+direction*u_texel*u_outline).a);
        if (u_glow>0.0) {
            halo+=sampleLayer(tex,uv+direction*u_texel*u_glowRadius);
            halo+=sampleLayer(tex,uv+direction*u_texel*u_glowRadius*0.5);
        }
    }
    float border=max(0.0,edge-c.a);
    c.rgb+=u_outlineColor*border;c.a+=border;
    halo*=u_glow/16.0;
    float alpha=clamp(halo.a,0.0,1.0)*(1.0-c.a);
    c.rgb+=halo.rgb*u_tint*(1.0-c.a);c.a+=alpha;
    return c*vec4(color.rgb*color.a,color.a);
}
]]
function A.needed(f)
  return f.pixelSize>1 or f.dissolve>0 or f.outline>0 or f.levels>0 or f.distortion>0 or f.glow>0 or
    f.tint[1]~=1 or f.tint[2]~=1 or f.tint[3]~=1
end
function A.new(settings,width,height)
  if not A.needed(settings) then return nil end
  local self=setmetatable({settings=settings,width=width,height=height},A)
  local ok,err=pcall(function()
    -- This fragment shader also runs on the older shader language used by fallback devices.
    local shaderSource=love.graphics.getSupported().glsl3 and source or source:gsub('#pragma language glsl3\n','',1)
    self.shader=love.graphics.newShader(shaderSource)
    self:resize()
    for _,k in ipairs{'dissolve','outline','levels','tint','distortion','glow','glowRadius','outlineColor'} do self.shader:send('u_'..k,settings[k]) end
  end)
  if not ok then self:release();error(err) end
  return self
end
function A:resize(bounds)
  local pixel=self.settings.pixelSize
  local padding=bounds and math.ceil(math.max(self.settings.outline,self.settings.glow>0 and self.settings.glowRadius or 0)+self.settings.distortion)*pixel or 0
  local left=math.floor(((bounds and bounds.x or 0)-padding)/pixel)*pixel
  local top=math.floor(((bounds and bounds.y or 0)-padding)/pixel)*pixel
  local right=math.ceil(((bounds and bounds.x+bounds.w or self.width)+padding)/pixel)*pixel
  local bottom=math.ceil(((bounds and bounds.y+bounds.h or self.height)+padding)/pixel)*pixel
  local width,height=(right-left)/pixel,(bottom-top)/pixel
  if self.left==left and self.top==top and self.canvasWidth==width and self.canvasHeight==height then return end
  if self.canvasWidth~=width or self.canvasHeight~=height then
    local canvas=love.graphics.newCanvas(width,height,{dpiscale=1,msaa=0})
    if self.canvas then self.canvas:release() end
    self.canvas=canvas;self.canvas:setFilter('nearest','nearest')
  end
  self.left,self.top,self.canvasWidth,self.canvasHeight=left,top,width,height
  self.shader:send('u_texel',{1/width,1/height})
  self.shader:send('u_cellOrigin',{left/pixel,top/pixel})
  self.shader:send('u_region',{left/self.width,top/self.height,width*pixel/self.width,height*pixel/self.height})
end
function A:draw(emitter,time,x,y,bounds)
  local g=love.graphics;local pixel=self.settings.pixelSize
  self:resize(bounds)
  g.push('all')
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setStencilTest();g.setShader();g.setColor(1,1,1,1)
  g.clear(0,0,0,0);g.scale(1/pixel);g.translate(-self.left,-self.top);emitter:draw()
  g.pop()
  g.push('all');g.setShader(self.shader);self.shader:send('u_time',time)
  g.setBlendMode(emitter.config.blendMode,'premultiplied');g.draw(self.canvas,(x or 0)+self.left,(y or 0)+self.top,0,pixel,pixel);g.pop()
end
function A:release()
  if self.canvas then self.canvas:release();self.canvas=nil end
  if self.shader then self.shader:release();self.shader=nil end
end
return A
