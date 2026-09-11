uniform Image u_velocity;
uniform Image u_injection;
uniform float u_dt;
uniform float u_decay;
uniform float u_cooling;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);vec4 old=at(state,p);
  if (gasSolid(p)) return vec4(0.0,old.g,0.0,old.a+old.r);
  vec2 v=at(u_velocity,p).xy;
  vec4 carried=sampleGas(state,traceGas(p,v*u_dt/u_cell));
  vec4 injection=at(u_injection,p);
  float mass=carried.r*u_decay;
  float added=min(injection.r,max(0.0,1000.0-mass));
  float heat=injection.r>0.0 ? injection.b*added/injection.r : 0.0;
  return vec4(mass+added,old.g+added,carried.b*u_decay*u_cooling+heat,old.a+carried.r*(1.0-u_decay));
}
