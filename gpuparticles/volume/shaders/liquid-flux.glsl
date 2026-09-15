uniform Image u_velocity;
uniform float u_dt;
float mass(Image state,vec2 p) { return inside(p) ? at(state,p).r : 0.0; }
vec4 effect(vec4 color,Image state,vec2 tc,vec2 sc) {
  vec2 p=floor(tc*u_grid);
  float m=mass(state,p);
  vec4 f=vec4(0.0);
  vec2 neighbors[4];
  neighbors[0]=p+vec2(-1,0);neighbors[1]=p+vec2(1,0);
  neighbors[2]=p+vec2(0,1);neighbors[3]=p+vec2(0,-1);
  if (m<=0.0) return f;
  if (obstacleDistance(p)<0.0) {
    for (int i=0;i<4;i++) {
      bool movingObstacle=dynamicDistance(p)<0.0;
      if (inside(neighbors[i]) && (!movingObstacle || Texel(u_terrain,uv(neighbors[i])).r>=0.0)) {
        float current=movingObstacle ? dynamicDistance(p) : obstacleDistance(p);
        float next=movingObstacle ? dynamicDistance(neighbors[i]) : obstacleDistance(neighbors[i]);
        f[i]=max(0.0,next-current);
      }
    }
    float weights=dot(f,vec4(1.0));
    return weights>0.0 ? f*(0.5*m/weights) : vec4(0.0);
  }
  vec2 cells=at(u_velocity,p).xy*u_dt/u_cell;
  f=vec4(max(-cells.x,0.0),max(cells.x,0.0),max(cells.y,0.0),max(-cells.y,0.0))*m;
  for (int i=0;i<4;i++) {
    if (i==3 && p.y<0.5) continue;
    if (solid(neighbors[i])) f[i]=0.0;
  }
  float total=dot(f,vec4(1.0));
  return f*min(1.0,0.9*m/max(total,0.0000001));
}
