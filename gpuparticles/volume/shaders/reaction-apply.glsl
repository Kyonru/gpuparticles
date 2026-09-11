uniform Image u_transfer;
uniform float u_sign;
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) { return Texel(state,tc)+u_sign*Texel(u_transfer,tc); }
