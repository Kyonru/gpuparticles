#pragma language glsl3
#ifdef VERTEX
attribute vec2 PlantRoot;
attribute vec4 PlantData; // scale, rotation, wind phase, spring index
uniform vec2 u_bends[64];
uniform float u_time;
uniform float u_wind;
vec4 position(mat4 transform,vec4 vertex) {
    float height=clamp(-vertex.y/96.0,0.0,1.0);
    float weight=height*height;
    float scale=PlantData.x,angle=PlantData.y,phase=PlantData.z;
    vec2 p=vertex.xy*scale;
    p=mat2(cos(angle),sin(angle),-sin(angle),cos(angle))*p;
    float wind=u_wind*(sin(u_time*1.7+phase)+0.35*sin(u_time*3.1+phase*1.7))*7.0*scale;
    p+=(u_bends[int(PlantData.w)]+vec2(wind,0.0))*weight;
    return transform*vec4(PlantRoot+p,0.0,1.0);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) { return color; }
#endif
