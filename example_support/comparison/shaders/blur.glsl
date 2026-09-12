#pragma language glsl3
uniform vec2 u_direction;
#ifdef VERTEX
vec4 position(mat4 transform_projection,vec4 vertex_position) {
  return transform_projection*vertex_position;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image image,vec2 tc,vec2 sc) {
  vec4 value=Texel(image,tc)*0.227027;
  value+=Texel(image,tc+u_direction*1.384615)*0.316216;
  value+=Texel(image,tc-u_direction*1.384615)*0.316216;
  value+=Texel(image,tc+u_direction*3.230769)*0.070270;
  value+=Texel(image,tc-u_direction*3.230769)*0.070270;
  return value*color;
}
#endif
