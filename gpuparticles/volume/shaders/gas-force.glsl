uniform Image u_velocity;
uniform float u_buoyancy;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);vec4 s=at(state,p);
  if (gasSolid(p) || s.r<=0.0) return vec4(0.0);
  float temperature=s.b/max(s.r,0.000001);
  vec2 force=customForce((p+0.5)*u_cell,at(u_velocity,p).xy,s.r,temperature,u_time);
  force.y-=u_buoyancy*temperature*min(s.r,1.0);
  return vec4(clamp(force,vec2(-10000.0),vec2(10000.0)),0.0,0.0);
}
