///|
pub(all) suberror PathEvalError {
  LineToWithoutCurrent
  CubicToWithoutCurrent
  CloseWithoutSubpath
}

///|
pub fn Path2D::eval(self : Path2D) -> Array[Vec2] raise PathEvalError {
  let points : Array[Vec2] = []
  let mut current : Vec2? = None
  let mut subpath_start : Vec2? = None
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
fn append_line(points : Array[Vec2], start : Vec2, anchor : Vec2) -> Unit {
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
  points : Array[Vec2],
  anchor0 : Vec2,
  handle1 : Vec2,
  handle2 : Vec2,
  anchor1 : Vec2,
) -> Unit {
  points.push(anchor0)
  points.push(handle1)
  points.push(handle2)
  points.push(anchor1)
}

///|
fn lerp(start : Vec2, end : Vec2, t : Double) -> Vec2 {
  start.add(end.sub(start).scale(t))
}

///|
fn points_nearly_equal(a : Vec2, b : Vec2) -> Bool {
  Double::abs(a.x - b.x) < 0.000000001 && Double::abs(a.y - b.y) < 0.000000001
}
