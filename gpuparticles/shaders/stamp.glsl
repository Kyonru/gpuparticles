#pragma language glsl3
uniform float u_texSize;
uniform vec2 u_origin;
varying vec4 spawnRecord;
varying vec4 motionRecord;
varying vec4 styleRecord;
#ifdef VERTEX
attribute vec4 ParticleSpawn;
attribute vec4 ParticleMotion;
attribute vec4 ParticleStyle;
attribute float ParticleIndex;
vec4 position(mat4 transform, vec4 vertex) {
    spawnRecord=ParticleSpawn;
    motionRecord=ParticleMotion;
    styleRecord=ParticleStyle;
    vec2 pixel=vec2(mod(ParticleIndex,u_texSize),floor(ParticleIndex/u_texSize))+0.5;
    return transform*vec4(vertex.xy+pixel,0.0,1.0);
}
#endif
#ifdef PIXEL
void effect() {
    love_Canvases[0]=vec4(motionRecord.xy+(spawnRecord.w<0.0 ? styleRecord.zw : u_origin),motionRecord.zw);
    love_Canvases[1]=spawnRecord;
    love_Canvases[2]=motionRecord;
    love_Canvases[3]=styleRecord;
}
#endif
