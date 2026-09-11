uniform Image u_force;
uniform vec2 u_wind;
uniform float u_dt;
uniform float u_damping;
vec4 effect(vec4 color,Image velocity,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  if (gasSolid(p)) return vec4(0.0);
  vec2 v=at(velocity,p).xy;
  v=sampleGas(velocity,traceGas(p,v*u_dt/u_cell)).xy;
  v+=(at(u_force,p).xy+2.0*(u_wind-v))*u_dt;
  v*=exp(-u_damping*u_dt);
  return vec4(clamp(v,-0.75*u_cell/u_dt,0.75*u_cell/u_dt),0.0,0.0);
}
