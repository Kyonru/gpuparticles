uniform Image u_collision;
uniform int u_collisionType;
uniform vec4 u_collisionRegion;
uniform vec2 u_collisionTexel;
uniform vec2 u_collisionEncoding;
uniform vec4 u_collisionResponse;
uniform vec4 u_circle; // center.xy, obstacle radius, enabled
uniform vec4 u_circleResponse; // particle radius, bounce, friction
uniform vec4 u_box; // center.xy, half extents.xy
uniform vec4 u_boxResponse; // particle radius, bounce, friction, enabled
uniform vec4 u_capsule; // segment start.xy, end.xy
uniform vec4 u_capsuleResponse; // obstacle radius, particle radius, bounce, friction
uniform bool u_capsuleEnabled;
uniform int u_collisionAction;
float distanceSample(vec2 uv) { return Texel(u_collision,uv).r*u_collisionEncoding.x+u_collisionEncoding.y; }
bool collideWithAction(inout vec2 p,inout vec2 velocity,int action) {
    if (u_collisionType==0 && u_circle.w==0.0 && u_boxResponse.w==0.0 && !u_capsuleEnabled) return false;
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
    if (u_boxResponse.w>0.0) {
        vec2 local=p-u_box.xy;
        vec2 q=abs(local)-u_box.zw;
        float boxDistance=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0);
        if (boxDistance-u_boxResponse.x<distance-response.x) {
            vec2 outside=max(q,vec2(0.0));
            if (length(outside)>0.00001) normal=normalize(outside)*vec2(local.x<0.0 ? -1.0 : 1.0,local.y<0.0 ? -1.0 : 1.0);
            else normal=q.x>q.y ? vec2(local.x<0.0 ? -1.0 : 1.0,0.0) : vec2(0.0,local.y<0.0 ? -1.0 : 1.0);
            distance=boxDistance;
            response=vec4(u_boxResponse.xyz,0.0);
        }
    }
    if (u_capsuleEnabled) {
        vec2 a=u_capsule.xy,segment=u_capsule.zw-a;
        float segmentLength2=dot(segment,segment);
        float along=segmentLength2>0.00001 ? clamp(dot(p-a,segment)/segmentLength2,0.0,1.0) : 0.0;
        vec2 offset=p-(a+segment*along);
        float separation=length(offset);
        float capsuleDistance=separation-u_capsuleResponse.x;
        if (capsuleDistance-u_capsuleResponse.y<distance-response.x) {
            distance=capsuleDistance;
            normal=separation>0.00001 ? offset/separation : segmentLength2>0.00001 ? normalize(vec2(-segment.y,segment.x)) : vec2(0,-1);
            response=vec4(u_capsuleResponse.yzw,0.0);
        }
    }
    float penetration=response.x-distance;
    if (penetration>0.0) {
        p+=normal*penetration;
        float vn=dot(velocity,normal);
        if (action==0) {
            if (vn<0.0) velocity-=(1.0+response.y)*vn*normal;
            vec2 tangent=velocity-dot(velocity,normal)*normal;
            velocity-=tangent*response.z;
        } else if (action==1) {
            if (vn<0.0) velocity-=vn*normal;
            velocity-=velocity*response.z;
        } else velocity=vec2(0.0);
        return true;
    }
    return false;
}
bool collide(inout vec2 p,inout vec2 velocity) { return collideWithAction(p,velocity,u_collisionAction); }
void projectCollision(inout vec2 p,inout vec2 velocity) { collideWithAction(p,velocity,0); }
