uniform float u_threshold;
uniform float u_fraction;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec4 s=Texel(state,tc);
  float fraction=s.r>0.0 && s.b/s.r>=u_threshold ? u_fraction : 0.0;
  return vec4(s.r*fraction,0.0,s.b*fraction,0.0);
}
