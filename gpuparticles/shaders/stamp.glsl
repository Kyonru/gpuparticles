#pragma language glsl3
uniform float u_texSize;
uniform vec2 u_origin;
#ifdef PARTICLE_DEPTH_STATE
// Birth z for explicit bursts, which are written here rather than born in the simulation.
// Must match depthBirth in simulate.glsl, including randomTerm from common.glsl.
uniform float u_depthAxis;
uniform vec2 u_depthOrbit;
uniform float u_depthEmission;
uniform vec2 u_depthSpeed;
float depthRandom(float seed, float salt) { return fract(sin(seed*127.1+salt*311.7)*43758.5453); }
#endif
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
#ifdef PARTICLE_DEPTH_STATE
    float seed=spawnRecord.z;
    float x=love_Canvases[0].x;
    float orbit=mix(u_depthOrbit.x,u_depthOrbit.y,depthRandom(seed,13.0));
    love_Canvases[4]=vec4((depthRandom(seed,11.0)*2.0-1.0)*u_depthEmission,
        (x-u_depthAxis)*orbit+mix(u_depthSpeed.x,u_depthSpeed.y,depthRandom(seed,12.0)),0.0,0.0);
#endif
}
#endif
