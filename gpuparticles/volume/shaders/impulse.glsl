uniform vec4 u_brush;
uniform vec2 u_impulse;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);vec4 s=Texel(state,tc);
  float weight=max(0.0,1.0-distance((p+0.5)*u_cell,u_brush.xy)/u_brush.z);
  if (!gasSolid(p)) s.xy+=u_impulse*weight;
  return s;
}
