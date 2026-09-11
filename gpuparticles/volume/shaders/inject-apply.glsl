uniform Image u_injection;
uniform bool u_gas;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);vec4 old=at(state,p),injection=at(u_injection,p);
  float added=(u_gas ? gasSolid(p) : solid(p)) ? 0.0 : min(injection.r,max(0.0,(u_gas ? 1000.0 : 1.0)-old.r));
  float heat=injection.r>0.0 ? injection.b*added/injection.r : 0.0;
  return old+vec4(added,added,heat,0.0);
}
