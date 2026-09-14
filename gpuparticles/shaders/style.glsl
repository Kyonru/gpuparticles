uniform Image u_colors;
uniform Image u_sizes;
uniform Image u_quads;
uniform float u_colorCount;
uniform float u_sizeCount;
uniform float u_quadCount;
uniform vec2 u_offset;
uniform float u_sizeVariation;
uniform bool u_relativeRotation;
uniform float u_stretch;   // seconds of travel a velocity streak covers; 0 for none
varying vec4 particleColor;
varying vec2 particleUV;
#ifdef PARTICLE_DEPTH
// Optional depth. Only z variants compile this; every other emitter keeps the plain shader.
uniform float u_depthCut;    // 0 draw everything, 1 only what is behind z = 0, 2 only what is in front
uniform float u_depthRange;  // z distance that counts as fully behind or fully in front
uniform float u_depthSize;   // size cue: sizes scale by 1 + size * depth
uniform float u_depthDim;    // brightness cue: the back loses up to this fraction
varying float particleDepth; // z / range, clamped to [-1, 1]
#endif
vec4 curve(Image image, float count, float age01) {
    float at=clamp(age01,0.0,1.0)*(count-1.0);
    float lo=floor(at), hi=min(lo+1.0,count-1.0);
    return mix(Texel(image,vec2((lo+0.5)/count,0.5)),Texel(image,vec2((hi+0.5)/count,0.5)),fract(at));
}
#ifdef VERTEX
#ifdef PARTICLE_DEPTH
float particleZ=0.0; // set by the z variant before styleVertex runs
#endif
vec4 styleVertex(mat4 transform, vec4 vertex, vec2 p, vec2 velocity, vec4 style, vec3 clock, float life,float seed) {
    float age01=clock.x/life;
    float size=curve(u_sizes,u_sizeCount,age01).r*(1.0-u_sizeVariation*randomTerm(seed,6.0));
    particleColor=curve(u_colors,u_colorCount,age01)*clock.y;
#ifdef PARTICLE_DEPTH
    particleDepth=clamp(particleZ/max(u_depthRange,0.000001),-1.0,1.0);
    size*=max(0.0,1.0+u_depthSize*particleDepth);
    particleColor.rgb*=1.0-u_depthDim*0.5*(1.0-particleDepth);
#endif
    float quadIndex=min(floor(clamp(age01,0.0,1.0)*u_quadCount),u_quadCount-1.0);
    vec4 uv=Texel(u_quads,vec2((quadIndex+0.5)/u_quadCount,0.5));
    particleUV=uv.xy+VertexTexCoord.xy*uv.zw;
    float angle=style.x+style.y*clock.x;
    float speed=length(velocity);
    // A streak lies along travel, so stretching aligns to velocity even without relative rotation.
    if ((u_relativeRotation || u_stretch>0.0) && speed>0.00001) angle+=atan(velocity.y,velocity.x);
    float ca=cos(angle),sa=sin(angle);
    vec2 localVertex=vertex.xy*size-u_offset;
    // Velocity stretch: the trailing edge (vertex.x = -0.5) moves back by speed * u_stretch
    // and the leading edge stays on the particle. A particle stopped by a collision has no speed
    // and therefore no streak.
    localVertex.x+=(vertex.x-0.5)*u_stretch*speed;
    vec2 rotated=vec2(ca*localVertex.x-sa*localVertex.y,sa*localVertex.x+ca*localVertex.y);
    return transform*vec4(p+rotated,0.0,1.0);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 result=Texel(tex,particleUV)*color*particleColor;
#ifdef PARTICLE_DEPTH
    // Complementary weights on alpha only: emitters draw with alpha-multiplied blending, so
    // weighting colour as well would square the weight and dim the blend band.
    if (u_depthCut>1.5) result.a*=smoothstep(-0.25,0.25,particleDepth);
    else if (u_depthCut>0.5) result.a*=1.0-smoothstep(-0.25,0.25,particleDepth);
#endif
    return result;
}
#endif
