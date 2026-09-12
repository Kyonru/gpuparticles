#pragma language glsl3
uniform float u_time;
uniform float u_glow;
uniform vec2 u_texel;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection*vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 core=Texel(tex,tc);
    vec4 halo=vec4(0.0);
    vec2 radius=u_texel*(3.0+sin(u_time*1.7));
    halo+=Texel(tex,tc+vec2(radius.x,0.0));
    halo+=Texel(tex,tc-vec2(radius.x,0.0));
    halo+=Texel(tex,tc+vec2(0.0,radius.y));
    halo+=Texel(tex,tc-vec2(0.0,radius.y));
    halo+=Texel(tex,tc+radius);
    halo+=Texel(tex,tc-radius);
    halo+=Texel(tex,tc+vec2(radius.x,-radius.y));
    halo+=Texel(tex,tc+vec2(-radius.x,radius.y));
    halo*=0.125;

    vec3 split=vec3(
        Texel(tex,tc+vec2(u_texel.x*2.0,0.0)).r,
        core.g,
        Texel(tex,tc-vec2(u_texel.x*2.0,0.0)).b
    );
    vec3 glowColor=halo.rgb*vec3(0.22,0.72,1.35)*u_glow;
    float alpha=max(core.a,halo.a*u_glow*0.72);
    return vec4(split+glowColor,alpha)*color;
}
#endif
