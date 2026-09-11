uniform Image u_pressure;
float pressureAt(vec2 p,float center) { return gasSolid(p) ? center : at(u_pressure,p).r; }
vec4 effect(vec4 color,Image velocity,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (gasSolid(p)) return vec4(0.0);
  float c=at(u_pressure,p).r;
  vec2 gradient=vec2(pressureAt(p+vec2(1,0),c)-pressureAt(p-vec2(1,0),c),
    pressureAt(p+vec2(0,1),c)-pressureAt(p-vec2(0,1),c))/(2.0*u_cell);
  vec2 v=at(velocity,p).xy-gradient;
  if (gasSolid(p+vec2(1,0))) v.x=min(v.x,0.0);
  if (gasSolid(p-vec2(1,0))) v.x=max(v.x,0.0);
  if (gasSolid(p+vec2(0,1))) v.y=min(v.y,0.0);
  if (gasSolid(p-vec2(0,1))) v.y=max(v.y,0.0);
  return vec4(v,0.0,0.0);
}
