vec2 velocityAt(Image velocity,vec2 p) { return gasSolid(p) ? vec2(0.0) : at(velocity,p).xy; }
vec4 effect(vec4 color,Image velocity,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (gasSolid(p)) return vec4(0.0);
  float d=(velocityAt(velocity,p+vec2(1,0)).x-velocityAt(velocity,p-vec2(1,0)).x)/(2.0*u_cell.x)
    +(velocityAt(velocity,p+vec2(0,1)).y-velocityAt(velocity,p-vec2(0,1)).y)/(2.0*u_cell.y);
  return vec4(d,0.0,0.0,0.0);
}
