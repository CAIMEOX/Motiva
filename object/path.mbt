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
