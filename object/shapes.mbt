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
pub(all) struct Line {
  start : Vec3
  end : Vec3
  style : ShapeStyle
}

///|
pub fn Line::new(
  start? : Vec3 = Vec3::new(x=-1.0, y=0.0),
  end? : Vec3 = Vec3::new(x=1.0, y=0.0),
  style? : ShapeStyle = ShapeStyle::default(),
) -> Line {
  { start, end, style }
}

///|
pub fn Line::path(self : Line) -> Path3D {
  let path = Path3D::empty()
  path.move_to(self.start)
  path.line_to(self.end)
  path
}

///|
pub impl IntoObject for Line with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub(all) struct Polygon {
  vertices : Array[Vec3]
  style : ShapeStyle
}

///|
pub fn Polygon::new(
  vertices : Array[Vec3],
  style? : ShapeStyle = ShapeStyle::default(),
) -> Polygon {
  { vertices: vertices.copy(), style }
}

///|
pub fn Polygon::path(self : Polygon) -> Path3D {
  polygon_path(self.vertices)
}

///|
pub impl IntoObject for Polygon with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub(all) struct Rectangle {
  width : Double
  height : Double
  style : ShapeStyle
}

///|
pub fn Rectangle::new(
  width? : Double = 4.0,
  height? : Double = 2.0,
  style? : ShapeStyle = ShapeStyle::default(),
) -> Rectangle {
  { width, height, style }
}

///|
pub fn Rectangle::polygon(self : Rectangle) -> Polygon {
  let half_width = self.width / 2.0
  let half_height = self.height / 2.0
  Polygon::new(
    [
      Vec3::new(x=0.0 - half_width, y=0.0 - half_height),
      Vec3::new(x=half_width, y=0.0 - half_height),
      Vec3::new(x=half_width, y=half_height),
      Vec3::new(x=0.0 - half_width, y=half_height),
    ],
    style=self.style,
  )
}

///|
pub fn Rectangle::path(self : Rectangle) -> Path3D {
  self.polygon().path()
}

///|
pub impl IntoObject for Rectangle with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
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
  Rectangle::new(
    width=self.side_length,
    height=self.side_length,
    style=self.style,
  ).path()
}

///|
pub impl IntoObject for Square with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
pub(all) struct Dot {
  point : Vec3
  radius : Double
  segments : Int
  style : ShapeStyle
}

///|
pub fn Dot::new(
  point? : Vec3,
  radius? : Double,
  segments? : Int,
  style? : ShapeStyle,
) -> Dot {
  let defaults = Dot::default()
  {
    point: point.map_or(defaults.point, value => value),
    radius: radius.map_or(defaults.radius, value => value),
    segments: segments.map_or(defaults.segments, value => value),
    style: style.map_or(defaults.style, value => value),
  }
}

///|
pub impl Default for Dot with fn default() -> Dot {
  {
    point: Vec3::zero(),
    radius: 0.08,
    segments: 8,
    style: ShapeStyle::new(
      fill=Rgba::white(),
      fill_opacity=1.0,
      stroke=Rgba::white(),
      stroke_width=0.0,
    ),
  }
}

///|
pub fn Dot::path(self : Dot) -> Path3D {
  translate_path(
    Circle::new(radius=self.radius, segments=self.segments, style=self.style).path(),
    self.point,
  )
}

///|
pub impl IntoObject for Dot with fn to_object(self, id? : String = "") -> Object {
  Object::path(self.path(), style=self.style, id~)
}

///|
fn polygon_path(vertices : Array[Vec3]) -> Path3D {
  let path = Path3D::empty()
  match vertices.get(0) {
    None => path
    Some(first) => {
      path.move_to(first)
      for index in 1..<vertices.length() {
        path.line_to(vertices[index])
      }
      if vertices.length() > 1 {
        path.close()
      }
      path
    }
  }
}

///|
fn translate_path(path : Path3D, offset : Vec3) -> Path3D {
  let translated = Path3D::empty()
  for command in path.commands {
    match command {
      MoveTo(point) => translated.move_to(point.add(offset))
      LineTo(point) => translated.line_to(point.add(offset))
      CubicTo(handle1, handle2, anchor) =>
        translated.cubic_to(
          handle1.add(offset),
          handle2.add(offset),
          anchor.add(offset),
        )
      Close => translated.close()
    }
  }
  translated
}
