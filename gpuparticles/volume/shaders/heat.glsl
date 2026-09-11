uniform vec4 u_brush;
uniform float u_heat;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec4 s=Texel(state,tc);
  float weight=max(0.0,1.0-distance((floor(tc*u_grid)+0.5)*u_cell,u_brush.xy)/u_brush.z);
  s.b=clamp(s.b+s.r*u_heat*weight,0.0,s.r*1000.0);return s;
}
