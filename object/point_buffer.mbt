///|
pub(all) suberror PathEvalError {
  LineToWithoutCurrent
  CubicToWithoutCurrent
  CloseWithoutSubpath
}

///|
pub fn Path3D::eval(self : Path3D) -> Array[Vec3] raise PathEvalError {
  let points : Array[Vec3] = []
  let mut current : Vec3? = None
  let mut subpath_start : Vec3? = None
  for command in self.commands {
    match (command, current, subpath_start) {
      (MoveTo(point), _, _) => {
        current = Some(point)
        subpath_start = Some(point)
      }
      (LineTo(_), None, _) => raise LineToWithoutCurrent
      (LineTo(anchor), Some(start), _) => {
        append_line(points, start, anchor)
        current = Some(anchor)
      }
      (CubicTo(_, _, _), None, _) => raise CubicToWithoutCurrent
      (CubicTo(handle1, handle2, anchor), Some(start), _) => {
        append_cubic(points, start, handle1, handle2, anchor)
        current = Some(anchor)
      }
      (Close, Some(point), Some(start)) =>
        if !points_nearly_equal(point, start) {
          append_line(points, point, start)
          current = Some(start)
        }
      (Close, _, _) => raise CloseWithoutSubpath
    }
  }
  points
}

///|
fn append_line(points : Array[Vec3], start : Vec3, anchor : Vec3) -> Unit {
  append_cubic(
    points,
    start,
    lerp(start, anchor, 1.0 / 3.0),
    lerp(start, anchor, 2.0 / 3.0),
    anchor,
  )
}

///|
fn append_cubic(
  points : Array[Vec3],
  anchor0 : Vec3,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor1 : Vec3,
) -> Unit {
  points.push(anchor0)
  points.push(handle1)
  points.push(handle2)
  points.push(anchor1)
}

///|
fn lerp(start : Vec3, end : Vec3, t : Double) -> Vec3 {
  start.add(end.sub(start).scale(t))
}

///|
fn points_nearly_equal(a : Vec3, b : Vec3) -> Bool {
  Double::abs(a.x - b.x) < 0.000000001 &&
  Double::abs(a.y - b.y) < 0.000000001 &&
  Double::abs(a.z - b.z) < 0.000000001
}
