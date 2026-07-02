///|
pub(all) struct Circle {
  radius : Double
  segments : Int
  style : ShapeStyle
}

///|
pub fn Circle::new(
  radius? : Double = 1.0,
  segments? : Int = 8,
  style? : ShapeStyle = ShapeStyle::default(),
) -> Circle {
  { radius, segments, style }
}

///|
pub fn Circle::arc(self : Circle) -> Arc {
  Arc::new(
    radius=self.radius,
    start_angle=0.0,
    angle=2.0 * @math.PI,
    segments=self.segments,
    closed=true,
    style=self.style,
  )
}

///|
pub fn Circle::path(self : Circle) -> Path3D {
  self.arc().path()
}

///|
pub impl IntoObject for Circle with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub fn Circle::point_at_angle(self : Circle, angle : Double) -> Vec3 {
  Vec3::new(x=self.radius * @math.cos(angle), y=self.radius * @math.sin(angle))
}

///|
pub(all) struct Square {
  side_length : Double
  style : ShapeStyle
}

///|
pub fn Square::new(
  side_length? : Double = 2.0,
  style? : ShapeStyle = ShapeStyle::default(),
) -> Square {
  { side_length, style }
}

///|
pub fn Square::path(self : Square) -> Path3D {
  let half = self.side_length / 2.0
  let path = Path3D::empty()
  path.move_to(Vec3::new(x=0.0 - half, y=0.0 - half))
  path.line_to(Vec3::new(x=half, y=0.0 - half))
  path.line_to(Vec3::new(x=half, y=half))
  path.line_to(Vec3::new(x=0.0 - half, y=half))
  path.close()
  path
}

///|
pub impl IntoObject for Square with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}
