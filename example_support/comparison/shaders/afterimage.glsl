#pragma language glsl3
uniform Image u_history;
uniform float u_decay;
uniform vec2 u_texel;
uniform float u_trailPixels;
#ifdef VERTEX
vec4 position(mat4 transform_projection,vec4 vertex_position) {
  return transform_projection*vertex_position;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image current,vec2 tc,vec2 sc) {
  vec4 now=Texel(current,tc);
  vec4 result=max(now,Texel(u_history,tc)*u_decay);
  // Rain travels down, so samples below this pixel extend the image behind it.
  for (int i=1;i<=8;i++) {
    float distance=float(i)/8.0;
    vec4 echo=Texel(current,tc+vec2(0.0,u_trailPixels*distance)*u_texel);
    result=max(result,echo*(0.92-distance*0.58));
  }
  return result*color;
}
#endif
