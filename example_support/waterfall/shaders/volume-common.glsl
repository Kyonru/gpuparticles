uniform vec2 u_grid;
uniform vec2 u_cell;
uniform Image u_terrain;
uniform vec4 u_circle;
bool inside(vec2 p) { return all(greaterThanEqual(p,vec2(0.0))) && all(lessThan(p,u_grid)); }
vec2 uv(vec2 p) { return (p+0.5)/u_grid; }
float circleDistance(vec2 p) {
  return u_circle.w>0.5 ? length((p+0.5)*u_cell-u_circle.xy)-u_circle.z : 1.0e6;
}
bool rock(vec2 p) { return !inside(p) || Texel(u_terrain,uv(p)).r<0.0; }
bool solid(vec2 p) { return rock(p) || circleDistance(p)<0.0; }
