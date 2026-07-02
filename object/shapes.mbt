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
pub fn Circle::path(self : Circle) -> Path2D {
  self.arc().path()
}

///|
pub impl IntoObject for Circle with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub fn Circle::point_at_angle(self : Circle, angle : Double) -> Vec2 {
  Vec2::new(x=self.radius * @math.cos(angle), y=self.radius * @math.sin(angle))
}
