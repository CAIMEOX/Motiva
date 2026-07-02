///|
pub(all) struct Circle {
  radius : Double
  style : ShapeStyle
}

///|
pub fn Circle::new(
  radius? : Double = 1.0,
  style? : ShapeStyle = ShapeStyle::default(),
) -> Circle {
  { radius, style }
}

///|
pub fn Circle::path(self : Circle) -> Path2D {
  Path2D::circle(radius=self.radius)
}

///|
pub impl IntoObject for Circle with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub fn Circle::point_at_angle(self : Circle, angle : Double) -> Vec2 {
  Vec2::new(x=self.radius * @math.cos(angle), y=self.radius * @math.sin(angle))
}
