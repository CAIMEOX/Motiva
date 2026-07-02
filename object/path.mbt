///|
pub(all) enum PathCommand {
  MoveTo(Vec2)
  LineTo(Vec2)
  CubicTo(Vec2, Vec2, Vec2)
  Close
}

///|
pub(all) struct Path2D {
  commands : Array[PathCommand]
}

///|
pub fn Path2D::empty() -> Path2D {
  { commands: [] }
}

///|
pub fn Path2D::move_to(self : Path2D, point : Vec2) -> Unit {
  self.commands.push(MoveTo(point))
}

///|
pub fn Path2D::line_to(self : Path2D, point : Vec2) -> Unit {
  self.commands.push(LineTo(point))
}

///|
pub fn Path2D::cubic_to(
  self : Path2D,
  handle1 : Vec2,
  handle2 : Vec2,
  anchor : Vec2,
) -> Unit {
  self.commands.push(CubicTo(handle1, handle2, anchor))
}

///|
pub fn Path2D::close(self : Path2D) -> Unit {
  self.commands.push(Close)
}

///|
pub fn Path2D::circle(radius~ : Double, segments? : Int = 8) -> Path2D {
  let segment_count = if segments < 4 { 4 } else { segments }
  let path = Path2D::empty()
  let tau = 2.0 * @math.PI
  let delta = tau / Double::from_int(segment_count)
  for i in 0..<segment_count {
    let a0 = delta * Double::from_int(i)
    let a1 = delta * Double::from_int(i + 1)
    let p0 = Vec2::new(x=radius * @math.cos(a0), y=radius * @math.sin(a0))
    let p3 = Vec2::new(x=radius * @math.cos(a1), y=radius * @math.sin(a1))
    let k = 4.0 / 3.0 * @math.tan(delta / 4.0)
    let h1 = Vec2::new(
      x=p0.x + k * radius * (0.0 - @math.sin(a0)),
      y=p0.y + k * radius * @math.cos(a0),
    )
    let h2 = Vec2::new(
      x=p3.x - k * radius * (0.0 - @math.sin(a1)),
      y=p3.y - k * radius * @math.cos(a1),
    )
    if i == 0 {
      path.move_to(p0)
    }
    path.cubic_to(h1, h2, p3)
  }
  path.close()
  path
}

///|
pub fn Path2D::bounds(self : Path2D) -> Aabb? {
  self.commands.fold(init=None, (bounds : Aabb?, command) => {
    include_command_bounds(bounds, command)
  })
}

///|
fn include_optional_point(bounds : Aabb?, point : Vec2) -> Aabb? {
  match bounds {
    None => Some(Aabb::point(point))
    Some(bounds) => Some(bounds.include_point(point))
  }
}

///|
fn include_command_bounds(bounds : Aabb?, command : PathCommand) -> Aabb? {
  match command {
    MoveTo(point) | LineTo(point) => include_optional_point(bounds, point)
    CubicTo(handle1, handle2, anchor) => {
      let bounds = include_optional_point(bounds, handle1)
      let bounds = include_optional_point(bounds, handle2)
      include_optional_point(bounds, anchor)
    }
    Close => bounds
  }
}
