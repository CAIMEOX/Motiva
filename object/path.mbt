///|
pub(all) enum PathCommand {
  MoveTo(Vec3)
  LineTo(Vec3)
  CubicTo(Vec3, Vec3, Vec3)
  Close
}

///|
pub(all) struct Path3D {
  commands : Array[PathCommand]
}

///|
pub fn Path3D::empty() -> Path3D {
  { commands: [] }
}

///|
pub fn Path3D::move_to(self : Path3D, point : Vec3) -> Unit {
  self.commands.push(MoveTo(point))
}

///|
pub fn Path3D::line_to(self : Path3D, point : Vec3) -> Unit {
  self.commands.push(LineTo(point))
}

///|
pub fn Path3D::cubic_to(
  self : Path3D,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor : Vec3,
) -> Unit {
  self.commands.push(CubicTo(handle1, handle2, anchor))
}

///|
pub fn Path3D::close(self : Path3D) -> Unit {
  self.commands.push(Close)
}

///|
pub fn Path3D::bounds(self : Path3D) -> Aabb? {
  self.commands.fold(init=None, (bounds : Aabb?, command) => {
    include_command_bounds(bounds, command)
  })
}

///|
fn include_optional_point(bounds : Aabb?, point : Vec3) -> Aabb? {
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
