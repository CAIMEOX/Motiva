///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_point_close(actual : Vec3, expected : Vec3) -> Unit raise {
  assert_close(actual.x, expected.x)
  assert_close(actual.y, expected.y)
  assert_close(actual.z, expected.z)
}

///|
fn assert_buffer_point_close(
  buffer : PathBuffer3D,
  index : Int,
  expected : Vec3,
) -> Unit raise {
  guard buffer.point(index) is Some(point) else {
    fail("point buffer should contain the requested point")
  }
  assert_point_close(point, expected)
}

///|
fn eval_result(path : Path3D) -> Result[PathBuffer3D, PathEvalError] {
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
    Transform::translate(Vec3::new(x=3.0, y=-1.0, z=2.0)),
  )
  guard object.bounds() is Some(bounds) else {
    fail("Circle should have bounds")
  }
  assert_close(bounds.min.x, 1.0)
  assert_close(bounds.max.x, 5.0)
  assert_close(bounds.min.y, -3.0)
  assert_close(bounds.max.y, 1.0)
  assert_close(bounds.min.z, 2.0)
  assert_close(bounds.max.z, 2.0)
}

///|
test "circle point_at_angle uses local circle geometry" {
  let circle = Circle::new(radius=2.0)
  let point = circle.point_at_angle(@math.PI / 2.0)
  assert_close(point.x, 0.0)
  assert_close(point.y, 2.0)
  assert_close(point.z, 0.0)
}

///|
test "circle path eval lowers to one cubic segment per arc segment" {
  let buffer = Circle::new(radius=2.0, segments=8).path().eval()
  assert_eq(buffer.curve_count(), 8)
  assert_eq(buffer.point_count(), 32)
  guard buffer.subpaths().get(0) is Some(span) else {
    fail("closed circle should have one subpath")
  }
  assert_eq(span.curve_count, 8)
  assert_true(span.closed)
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
    Transform::translate(Vec3::new(x=1.0, y=-1.0, z=3.0)),
  )
  guard object.bounds() is Some(bounds) else {
    fail("Square should have bounds")
  }
  assert_close(bounds.min.x, -1.0)
  assert_close(bounds.max.x, 3.0)
  assert_close(bounds.min.y, -3.0)
  assert_close(bounds.max.y, 1.0)
  assert_close(bounds.min.z, 3.0)
  assert_close(bounds.max.z, 3.0)
}

///|
test "3d transform applies translation scale and z rotation" {
  let transform = Transform::scale(sx=2.0, sy=3.0, sz=4.0)
    .then(Transform::translate(Vec3::new(x=1.0, y=2.0, z=3.0)))
    .then(Transform::rotate_z(angle=@math.PI / 2.0))
  let point = transform.apply_point(Vec3::new(x=1.0, y=1.0, z=1.0))
  assert_close(point.x, -5.0)
  assert_close(point.y, 3.0)
  assert_close(point.z, 7.0)
  let vector = transform.apply_vec(Vec3::new(x=1.0, y=1.0, z=1.0))
  assert_close(vector.x, -3.0)
  assert_close(vector.y, 2.0)
  assert_close(vector.z, 4.0)
}

///|
test "square path eval lowers lines to cubic point buffer" {
  let buffer = Square::new(side_length=4.0).path().eval()
  assert_eq(buffer.curve_count(), 4)
  assert_eq(buffer.point_count(), 16)
  assert_buffer_point_close(buffer, 0, Vec3::new(x=-2.0, y=-2.0))
  assert_buffer_point_close(buffer, 1, Vec3::new(x=-2.0 + 4.0 / 3.0, y=-2.0))
  assert_buffer_point_close(buffer, 2, Vec3::new(x=-2.0 + 8.0 / 3.0, y=-2.0))
  assert_buffer_point_close(buffer, 3, Vec3::new(x=2.0, y=-2.0))
  assert_buffer_point_close(buffer, 15, Vec3::new(x=-2.0, y=-2.0))
}

///|
test "point buffer maps every 3d point" {
  let buffer = Square::new(side_length=4.0).path().eval()
  let offset = Vec3::new(x=1.0, y=-1.0, z=2.0)
  let transformed = buffer.map_points(point => point.add(offset))
  assert_buffer_point_close(transformed, 0, Vec3::new(x=-1.0, y=-3.0, z=2.0))
  assert_buffer_point_close(transformed, 15, Vec3::new(x=-1.0, y=-3.0, z=2.0))
}

///|
test "point buffer from_points rejects invalid cubic point count" {
  let result = try
    PathBuffer3D::from_points([Vec3::zero(), Vec3::new(x=1.0, y=0.0)])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(InvalidPointCount(count)) else {
    fail("invalid point count should return typed PathBufferError")
  }
  assert_eq(count, 2)
}

///|
test "point buffer normalizes square and circle curve counts" {
  let square = Square::new(side_length=4.0).path().eval()
  let circle = Circle::new(radius=2.0, segments=8).path().eval()
  let (normalized_square, normalized_circle) = square.normalize_pair(circle)
  assert_eq(normalized_square.curve_count(), 8)
  assert_eq(normalized_circle.curve_count(), 8)
  assert_eq(normalized_square.point_count(), normalized_circle.point_count())
  guard normalized_square.subpaths().get(0) is Some(square_span) else {
    fail("normalized square should have one subpath")
  }
  guard normalized_circle.subpaths().get(0) is Some(circle_span) else {
    fail("normalized circle should have one subpath")
  }
  assert_true(square_span.closed)
  assert_true(circle_span.closed)
}

///|
test "point buffer lerp returns compatible cubic path" {
  let square = Square::new(side_length=4.0).path().eval()
  let circle = Circle::new(radius=2.0, segments=8).path().eval()
  let midpoint = square.lerp(circle, 0.5)
  assert_eq(midpoint.curve_count(), 8)
  let path = midpoint.to_path()
  assert_eq(path.commands.length(), 10)
}

///|
test "path eval rejects line without current point" {
  let path = Path3D::empty()
  path.line_to(Vec3::new(x=1.0, y=0.0))
  guard eval_result(path) is Err(LineToWithoutCurrent) else {
    fail("LineTo without current point should fail")
  }
}

///|
test "path eval rejects cubic without current point" {
  let path = Path3D::empty()
  path.cubic_to(
    Vec3::new(x=1.0, y=0.0),
    Vec3::new(x=2.0, y=0.0),
    Vec3::new(x=3.0, y=0.0),
  )
  guard eval_result(path) is Err(CubicToWithoutCurrent) else {
    fail("CubicTo without current point should fail")
  }
}

///|
test "path eval rejects close without current subpath" {
  let path = Path3D::empty()
  path.close()
  guard eval_result(path) is Err(CloseWithoutSubpath) else {
    fail("Close without current subpath should fail")
  }
}
