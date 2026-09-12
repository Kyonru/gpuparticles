#pragma language glsl3
uniform float u_time;
uniform Image u_distance;
uniform vec2 u_worldSize;
uniform vec4 u_circle;
varying vec2 worldPosition;
#ifdef VERTEX
vec4 position(mat4 transform,vec4 vertex) {
    vertex.x+=sin(VertexTexCoord.y*23.0-u_time*2.1)*sin(VertexTexCoord.x*3.14159265)*2.0;
    worldPosition=vertex.xy;
    return transform*vertex;
}
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
    float distance=Texel(u_distance,worldPosition/u_worldSize).r;
    if (u_circle.w>0.0) distance=min(distance,length(worldPosition-u_circle.xy)-u_circle.z);
    float edge=smoothstep(0.0,0.13,uv.x)*smoothstep(0.0,0.13,1.0-uv.x);
    float n=noise(vec2(uv.x*23.0,uv.y*8.0-u_time*3.0));
    float fine=noise(vec2(uv.x*81.0,uv.y*4.0-u_time*5.0));
    float ribbons=pow(0.5+0.5*sin(uv.x*94.0+n*4.0+sin(uv.y*9.0-u_time*3.0)),10.0);
    float broken=smoothstep(0.12,0.78,n+fine*0.2);
    float alpha=edge*(0.23+broken*0.47+ribbons*0.3)*smoothstep(0.5,3.0,distance);
    vec3 water=mix(vec3(0.188,0.569,0.839),vec3(0.592,0.855,1.0),clamp(n*0.6+ribbons*0.7+fine*0.12,0.0,1.0));
    return vec4(water,alpha)*color;
}
#endif
