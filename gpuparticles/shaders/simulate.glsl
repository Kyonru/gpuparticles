#pragma language glsl3
// COMMON
// FORCES
uniform Image u_state;
uniform Image u_spawn;
uniform Image u_motion;
uniform Image u_style;
uniform float u_dt;
uniform float u_texSize;
uniform Image u_flow;
uniform bool u_hasFlow;
uniform vec4 u_flowRegion;
uniform vec2 u_flowEncoding;
uniform float u_flowStrength;
uniform Image u_attractors;
uniform int u_attractorCount;
uniform Image u_collision;
uniform int u_collisionType;
uniform vec4 u_collisionRegion;
uniform vec2 u_collisionTexel;
uniform vec2 u_collisionEncoding;
uniform vec4 u_collisionResponse;
uniform vec4 u_circle; // center.xy, obstacle radius, enabled
uniform vec4 u_circleResponse; // particle radius, bounce, friction
vec2 externalAcceleration(vec2 p,vec2 velocity,float seed,float age) {
    vec2 a=statefulAcceleration(p,velocity,seed,age);
    if (u_hasFlow) {
        vec2 uv=(p-u_flowRegion.xy)/u_flowRegion.zw;
        a+=(Texel(u_flow,uv).rg*u_flowEncoding.x+u_flowEncoding.y)*u_flowStrength;
    }
    for (int i=0;i<u_attractorCount;i++) {
        vec4 attractor=Texel(u_attractors,vec2((float(i)+0.5)/float(u_attractorCount),0.5));
        vec2 d=attractor.xy-p;
        float r2=max(dot(d,d),max(attractor.w*attractor.w,0.0001));
        a+=d*attractor.z/(r2*sqrt(r2));
    }
    return a;
}
float distanceSample(vec2 uv) { return Texel(u_collision,uv).r*u_collisionEncoding.x+u_collisionEncoding.y; }
void collide(inout vec2 p,inout vec2 velocity) {
    if (u_collisionType==0 && u_circle.w==0.0) return;
    float distance=1.0e30;
    vec2 normal=vec2(0,-1);
    vec4 response=u_collisionResponse;
    vec2 uv=(p-u_collisionRegion.xy)/u_collisionRegion.zw;
    if (u_collisionType==1) {
        distance=u_collisionRegion.y-p.y; normal=vec2(0,-1);
    } else if (u_collisionType==2) {
        float height=distanceSample(vec2(uv.x,0.5))+u_collisionRegion.y;
        float left=distanceSample(vec2(uv.x-u_collisionTexel.x,0.5));
        float right=distanceSample(vec2(uv.x+u_collisionTexel.x,0.5));
        float slope=(right-left)/(2.0*u_collisionTexel.x*u_collisionRegion.z);
        normal=normalize(vec2(slope,-1)); distance=(height-p.y)*(-normal.y);
    } else if (u_collisionType==3) {
        distance=distanceSample(uv);
        vec2 gradient=vec2(distanceSample(uv+vec2(u_collisionTexel.x,0))-distanceSample(uv-vec2(u_collisionTexel.x,0)),
          distanceSample(uv+vec2(0,u_collisionTexel.y))-distanceSample(uv-vec2(0,u_collisionTexel.y)));
        gradient/=2.0*u_collisionTexel*u_collisionRegion.zw;
        normal=length(gradient)>0.00001 ? normalize(gradient) : vec2(0,-1);
    }
    if (u_circle.w>0.0) {
        vec2 offset=p-u_circle.xy;
        float separation=length(offset);
        float circleDistance=separation-u_circle.z;
        if (circleDistance-u_circleResponse.x<distance-response.x) {
            distance=circleDistance;
            normal=separation>0.00001 ? offset/separation : vec2(0,-1);
            response=u_circleResponse;
        }
    }
    float penetration=response.x-distance;
    if (penetration>0.0) {
        p+=normal*penetration;
        float vn=dot(velocity,normal);
        if (vn<0.0) velocity-=(1.0+response.y)*vn*normal;
        vec2 tangent=velocity-dot(velocity,normal)*normal;
        velocity-=tangent*response.z;
    }
}
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
    float index=floor(sc.y)*u_texSize+floor(sc.x);
    if (index>=u_count) return vec4(0.0);
    vec4 spawn=Texel(u_spawn,tc), motion=Texel(u_motion,tc), style=Texel(u_style,tc);
    vec3 clock=particleClock(spawn,index);
    vec4 state=Texel(u_state,tc);
    if (clock.y==0.0) return state;
    float stepTime=min(u_dt,clock.x);
    if (clock.z>u_time-u_dt) state=vec4(motion.xy+particleOrigin(spawn,style),motion.zw);
    float seed=spawn.z;
    vec2 radial=state.xy-u_origin;
    if (length(radial)<0.00001) radial=motion.zw;
    vec2 acceleration=accelerationFor(seed,radial);
    acceleration+=externalAcceleration(state.xy,state.zw,seed,clock.x);
    float damping=mix(u_damping.x,u_damping.y,randomTerm(seed,5.0));
    vec2 velocity=(state.zw+acceleration*stepTime)*exp(-damping*stepTime);
    vec2 p=state.xy+velocity*stepTime;
    p+=forceDisplacement(seed,clock.x)-forceDisplacement(seed,max(clock.x-stepTime,0.0));
    collide(p,velocity);
    return vec4(p,velocity);
}
