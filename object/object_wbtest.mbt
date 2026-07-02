///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
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
