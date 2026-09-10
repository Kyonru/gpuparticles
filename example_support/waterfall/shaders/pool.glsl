#pragma language glsl3
uniform float u_time;
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen) {
    float depth=smoothstep(0.0,1.0,uv.y);
    vec3 water=mix(vec3(0.07,0.33,0.33),vec3(0.025,0.10,0.14),depth);
    float waves=sin(uv.x*93.0+sin(uv.y*42.0+u_time)*3.0-u_time*2.0)*sin(uv.y*80.0+u_time*2.3);
    float highlight=pow(max(0.0,waves),9.0)*(1.0-depth)*0.18;
    float reflection=exp(-pow((uv.x-0.64)*7.0,2.0))*(1.0-depth);
    water+=vec3(0.16,0.4,0.36)*reflection+vec3(0.55,0.85,0.72)*highlight;
    return vec4(water,1.0)*color;
}
