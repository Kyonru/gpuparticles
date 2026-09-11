uniform vec4 u_brush;
uniform float u_amount;
uniform float u_temperature;
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
  vec2 world=(floor(sc)+0.5)*u_cell;
  float weight=u_brush.w>0.5 && distance(world,u_brush.xy)>u_brush.z ? 0.0 : 1.0;
  return vec4(u_amount*weight,0.0,u_amount*weight*u_temperature,0.0);
}
