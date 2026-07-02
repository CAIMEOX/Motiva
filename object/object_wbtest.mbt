///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_point_close(actual : Vec2, expected : Vec2) -> Unit raise {
  assert_close(actual.x, expected.x)
  assert_close(actual.y, expected.y)
}

///|
fn assert_buffer_point_close(
  buffer : Array[Vec2],
  index : Int,
  expected : Vec2,
) -> Unit raise {
  guard buffer.get(index) is Some(point) else {
    fail("point buffer should contain the requested point")
  }
  assert_point_close(point, expected)
}

///|
fn eval_result(path : Path2D) -> Result[Array[Vec2], PathEvalError] {
  try path.eval() catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
}

///|
test "circle lowers to path object" {
  let circle = Circle::new(radius=2.0)
  let object = into_object(circle, id="circle")
  guard object.node is Path(path, style) else {
    fail("Circle should lower to Node::Path")
  }
  assert_eq(path.commands.length(), 10)
  guard style.stroke is Some(color) else {
    fail("Circle should have a default stroke color")
  }
  assert_close(color.r, 1.0)
  assert_close(color.g, 0.0)
  assert_close(color.b, 0.0)
}

///|
test "arc path is open by default" {
  let arc = Arc::new(radius=2.0, angle=@math.PI / 2.0, segments=2)
  let path = arc.path()
  assert_eq(path.commands.length(), 3)
}

///|
test "circle path delegates to a closed full arc" {
  let circle = Circle::new(radius=2.0)
  let arc = circle.arc()
  assert_close(arc.radius, 2.0)
  assert_close(arc.start_angle, 0.0)
  assert_close(arc.angle, 2.0 * @math.PI)
  assert_eq(arc.segments, 8)
  assert_true(arc.closed)
  assert_eq(circle.path().commands.length(), arc.path().commands.length())
}

///|
test "circle object bounds include object transform" {
  let circle = Circle::new(radius=2.0)
  let object = into_object(circle).with_transform(
    Transform::translate(Vec2::new(x=3.0, y=-1.0)),
  )
  guard object.bounds() is Some(bounds) else {
    fail("Circle should have bounds")
  }
  assert_close(bounds.min.x, 1.0)
  assert_close(bounds.max.x, 5.0)
  assert_close(bounds.min.y, -3.0)
  assert_close(bounds.max.y, 1.0)
}

///|
test "circle point_at_angle uses local circle geometry" {
  let circle = Circle::new(radius=2.0)
  let point = circle.point_at_angle(@math.PI / 2.0)
  assert_close(point.x, 0.0)
  assert_close(point.y, 2.0)
}

///|
test "circle path eval lowers to one cubic segment per arc segment" {
  let buffer = Circle::new(radius=2.0, segments=8).path().eval()
  assert_eq(buffer.length() / 4, 8)
  assert_eq(buffer.length(), 32)
}

///|
test "square lowers to path object" {
  let square = Square::new(side_length=4.0)
  let object = into_object(square, id="square")
  guard object.node is Path(path, style) else {
    fail("Square should lower to Node::Path")
  }
  assert_eq(path.commands.length(), 5)
  guard style.stroke is Some(color) else {
    fail("Square should have a default stroke color")
  }
  assert_close(color.r, 1.0)
  assert_close(color.g, 0.0)
  assert_close(color.b, 0.0)
}

///|
test "square object bounds include object transform" {
  let square = Square::new(side_length=4.0)
  let object = into_object(square).with_transform(
    Transform::translate(Vec2::new(x=1.0, y=-1.0)),
  )
  guard object.bounds() is Some(bounds) else {
    fail("Square should have bounds")
  }
  assert_close(bounds.min.x, -1.0)
  assert_close(bounds.max.x, 3.0)
  assert_close(bounds.min.y, -3.0)
  assert_close(bounds.max.y, 1.0)
}

///|
test "square path eval lowers lines to cubic point buffer" {
  let buffer = Square::new(side_length=4.0).path().eval()
  assert_eq(buffer.length() / 4, 4)
  assert_eq(buffer.length(), 16)
  assert_buffer_point_close(buffer, 0, Vec2::new(x=-2.0, y=-2.0))
  assert_buffer_point_close(buffer, 1, Vec2::new(x=-2.0 + 4.0 / 3.0, y=-2.0))
  assert_buffer_point_close(buffer, 2, Vec2::new(x=-2.0 + 8.0 / 3.0, y=-2.0))
  assert_buffer_point_close(buffer, 3, Vec2::new(x=2.0, y=-2.0))
  assert_buffer_point_close(buffer, 15, Vec2::new(x=-2.0, y=-2.0))
}

///|
test "point buffer transform maps every point" {
  let buffer = Square::new(side_length=4.0).path().eval()
  let transform = Transform::translate(Vec2::new(x=1.0, y=-1.0))
  let transformed = buffer.map(point => transform.apply_point(point))
  assert_buffer_point_close(transformed, 0, Vec2::new(x=-1.0, y=-3.0))
  assert_buffer_point_close(transformed, 15, Vec2::new(x=-1.0, y=-3.0))
}

///|
test "path eval rejects line without current point" {
  let path = Path2D::empty()
  path.line_to(Vec2::new(x=1.0, y=0.0))
  guard eval_result(path) is Err(LineToWithoutCurrent) else {
    fail("LineTo without current point should fail")
  }
}

///|
test "path eval rejects cubic without current point" {
  let path = Path2D::empty()
  path.cubic_to(
    Vec2::new(x=1.0, y=0.0),
    Vec2::new(x=2.0, y=0.0),
    Vec2::new(x=3.0, y=0.0),
  )
  guard eval_result(path) is Err(CubicToWithoutCurrent) else {
    fail("CubicTo without current point should fail")
  }
}

///|
test "path eval rejects close without current subpath" {
  let path = Path2D::empty()
  path.close()
  guard eval_result(path) is Err(CloseWithoutSubpath) else {
    fail("Close without current subpath should fail")
  }
}
