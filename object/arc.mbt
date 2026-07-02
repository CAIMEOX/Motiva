///|
pub(all) struct Arc {
  radius : Double
  start_angle : Double
  angle : Double
  segments : Int
  closed : Bool
  style : ShapeStyle
}

///|
pub fn Arc::new(
  radius? : Double = 1.0,
  start_angle? : Double = 0.0,
  angle? : Double = 2.0 * @math.PI,
  segments? : Int = 8,
  closed? : Bool = false,
  style? : ShapeStyle = ShapeStyle::default(),
) -> Arc {
  { radius, start_angle, angle, segments, closed, style }
}

///|
pub fn Arc::path(self : Arc) -> Path3D {
  let segment_count = if self.segments < 1 { 1 } else { self.segments }
  let path = Path3D::empty()
  let delta = self.angle / Double::from_int(segment_count)
  for i in 0..<segment_count {
    let a0 = self.start_angle + delta * Double::from_int(i)
    let a1 = self.start_angle + delta * Double::from_int(i + 1)
    let p0 = Vec3::new(
      x=self.radius * @math.cos(a0),
      y=self.radius * @math.sin(a0),
    )
    let p3 = Vec3::new(
      x=self.radius * @math.cos(a1),
      y=self.radius * @math.sin(a1),
    )
    let k = 4.0 / 3.0 * @math.tan(delta / 4.0)
    let h1 = Vec3::new(
      x=p0.x + k * self.radius * (0.0 - @math.sin(a0)),
      y=p0.y + k * self.radius * @math.cos(a0),
    )
    let h2 = Vec3::new(
      x=p3.x - k * self.radius * (0.0 - @math.sin(a1)),
      y=p3.y - k * self.radius * @math.cos(a1),
    )
    if i == 0 {
      path.move_to(p0)
    }
    path.cubic_to(h1, h2, p3)
  }
  if self.closed {
    path.close()
  }
  path
}

///|
pub impl IntoObject for Arc with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}
