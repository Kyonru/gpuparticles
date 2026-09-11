#pragma language glsl3
uniform Image u_state;
uniform Image u_neighbors;
uniform float u_texSize;
uniform float u_count;
uniform float u_radius;
uniform float u_bounce;
uniform float u_strength;
// COLLISION
vec4 effect(vec4 color,Image tex,vec2 tc,vec2 sc) {
    float index=floor(sc.y)*u_texSize+floor(sc.x);
    if (index>=u_count) return vec4(0.0);
    vec4 state=Texel(u_state,tc);
    if (Texel(u_neighbors,tc).z<0.5) return state;
    vec2 correction=vec2(0.0),impulse=vec2(0.0);
    float contacts=0.0,diameter=2.0*u_radius;
    // Capacity is checked in Lua: at most 24000 slots, including inactive slots.
    for (int j=0;j<int(u_count);j++) {
        float other=float(j);
        if (other==index) continue;
        vec2 uv=(vec2(mod(other,u_texSize),floor(other/u_texSize))+0.5)/u_texSize;
        vec4 neighbor=Texel(u_neighbors,uv);
        if (neighbor.z<0.5) continue;
        vec2 delta=state.xy-neighbor.xy;
        float d2=dot(delta,delta);
        if (d2>=diameter*diameter) continue;
        float distance=sqrt(d2);
        vec2 normal;
        if (distance>0.00001) normal=delta/distance;
        else {
            float angle=fract(sin(min(index,other)*127.1+max(index,other)*311.7)*43758.5453)*6.2831853;
            normal=vec2(cos(angle),sin(angle))*(index<other ? 1.0 : -1.0);
        }
        correction+=normal*(0.5*(diameter-distance)*u_strength);
        float closing=dot(state.zw-Texel(u_state,uv).zw,normal);
        impulse-=normal*(0.5*(1.0+u_bounce)*min(closing,0.0));
        contacts+=1.0;
    }
    // Averaging stabilizes dense clusters; this is a visual approximation, not a rigid-body solver.
    vec2 p=state.xy+correction/max(contacts,1.0);
    vec2 velocity=state.zw+impulse/max(contacts,1.0);
    collide(p,velocity);
    return vec4(p,velocity);
}
