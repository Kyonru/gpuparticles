uniform Image u_colors;
uniform Image u_sizes;
uniform Image u_quads;
uniform float u_colorCount;
uniform float u_sizeCount;
uniform float u_quadCount;
uniform vec2 u_offset;
uniform float u_sizeVariation;
uniform bool u_relativeRotation;
varying vec4 particleColor;
varying vec2 particleUV;
vec4 curve(Image image, float count, float age01) {
    float at=clamp(age01,0.0,1.0)*(count-1.0);
    float lo=floor(at), hi=min(lo+1.0,count-1.0);
    return mix(Texel(image,vec2((lo+0.5)/count,0.5)),Texel(image,vec2((hi+0.5)/count,0.5)),fract(at));
}
#ifdef VERTEX
vec4 styleVertex(mat4 transform, vec4 vertex, vec2 p, vec2 velocity, vec4 style, vec3 clock, float life,float seed) {
    float age01=clock.x/life;
    float size=curve(u_sizes,u_sizeCount,age01).r*(1.0-u_sizeVariation*randomTerm(seed,6.0));
    particleColor=curve(u_colors,u_colorCount,age01)*clock.y;
    float quadIndex=min(floor(clamp(age01,0.0,1.0)*u_quadCount),u_quadCount-1.0);
    vec4 uv=Texel(u_quads,vec2((quadIndex+0.5)/u_quadCount,0.5));
    particleUV=uv.xy+VertexTexCoord.xy*uv.zw;
    float angle=style.x+style.y*clock.x;
    if (u_relativeRotation && length(velocity)>0.00001) angle+=atan(velocity.y,velocity.x);
    float ca=cos(angle),sa=sin(angle);
    vec2 localVertex=vertex.xy*size-u_offset;
    vec2 rotated=vec2(ca*localVertex.x-sa*localVertex.y,sa*localVertex.x+ca*localVertex.y);
    return transform*vec4(p+rotated,0.0,1.0);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    return Texel(tex,particleUV)*color*particleColor;
}
#endif
