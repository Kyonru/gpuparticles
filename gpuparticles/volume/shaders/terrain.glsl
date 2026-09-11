uniform vec4 u_brush;
uniform bool u_solid;
vec4 effect(vec4 color,Image terrain,vec2 tc,vec2 sc) {
  float d=distance((floor(tc*u_grid)+0.5)*u_cell,u_brush.xy)-u_brush.z;
  float old=Texel(terrain,tc).r;
  return vec4(u_solid ? min(old,d) : max(old,-d),0.0,0.0,1.0);
}
