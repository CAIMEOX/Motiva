///|
fn assert_layout_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "move_to places an object center at the requested point" {
  let square = @object.into_object(@object.Square::new(side_length=2.0)).move_to(
    @object.Vec3::new(x=3.0, y=-2.0, z=1.0),
  )
  let center = square.center()
  assert_layout_close(center.x, 3.0)
  assert_layout_close(center.y, -2.0)
  assert_layout_close(center.z, 1.0)
}

///|
test "next_to leaves the requested gap between bounding boxes" {
  let square = @object.into_object(@object.Square::new(side_length=2.0))
  let circle = @object.into_object(@object.Circle::new(radius=0.5)).next_to(
    square,
    direction=@object.Vec3::new(x=1.0, y=0.0),
    buff=0.4,
  )
  guard (square.bounds(), circle.bounds())
    is (Some(square_bounds), Some(circle_bounds)) else {
    fail("positioned objects should have bounds")
  }
  assert_layout_close(circle_bounds.min.x - square_bounds.max.x, 0.4)
  assert_layout_close(circle.center().y, square.center().y)
}

///|
test "align_to matches only axes selected by the direction" {
  let target = @object.into_object(
    @object.Rectangle::new(width=3.0, height=2.0),
  ).move_to(@object.Vec3::new(x=2.0, y=1.5))
  let square = @object.into_object(@object.Square::new(side_length=1.0)).move_to(
    @object.Vec3::new(x=-2.0, y=-2.0),
  )
  let aligned = square.align_to(
    target,
    direction=@object.Vec3::new(x=0.0, y=1.0),
  )
  guard (target.bounds(), aligned.bounds())
    is (Some(target_bounds), Some(aligned_bounds)) else {
    fail("aligned objects should have bounds")
  }
  assert_layout_close(aligned_bounds.max.y, target_bounds.max.y)
  assert_layout_close(aligned.center().x, -2.0)
}

///|
test "arrange positions group children in order and centers the family" {
  let arranged = @object.Object::group([
    @object.into_object(@object.Square::new(side_length=1.0)),
    @object.into_object(@object.Circle::new(radius=0.5)),
    @object.into_object(@object.Rectangle::new(width=2.0, height=1.0)),
  ]).arrange(direction=@object.Vec3::new(x=1.0, y=0.0), buff=0.25)
  guard arranged.node is Group(children) else {
    fail("arrange should preserve the object family")
  }
  guard children is [first, second, third] else {
    fail("arrange should preserve child count and order")
  }
  guard (first.bounds(), second.bounds(), third.bounds())
    is (Some(first_bounds), Some(second_bounds), Some(third_bounds)) else {
    fail("arranged children should have bounds")
  }
  assert_layout_close(second_bounds.min.x - first_bounds.max.x, 0.25)
  assert_layout_close(third_bounds.min.x - second_bounds.max.x, 0.25)
  assert_layout_close(arranged.center().x, 0.0)
  assert_layout_close(arranged.center().y, 0.0)
}

///|
test "arrange uses world direction and buffer after a group transform" {
  let parent_transform = @object.Transform::scale(sx=1.5, sy=0.65)
    .then(@object.Transform::rotate(angle=@math.PI / 2.0))
    .then(@object.Transform::translate(@object.Vec3::new(x=2.0, y=-1.0)))
  let arranged = @object.Object::group([
      @object.into_object(@object.Square::new(side_length=1.0)),
      @object.into_object(@object.Square::new(side_length=1.0)),
    ])
    .with_transform(parent_transform)
    .arrange(direction=@object.Vec3::new(x=1.0, y=0.0), buff=0.4, center=false)
  guard arranged.node is Group([first, second]) else {
    fail("arrange should preserve transformed group children")
  }
  let first_world = first.with_transform(
    first.transform.then(arranged.transform),
  )
  let second_world = second.with_transform(
    second.transform.then(arranged.transform),
  )
  guard (first_world.bounds(), second_world.bounds())
    is (Some(first_bounds), Some(second_bounds)) else {
    fail("arranged transformed children should have world bounds")
  }
  assert_layout_close(second_bounds.min.x - first_bounds.max.x, 0.4)
  assert_layout_close(second_world.center().y, first_world.center().y)
}
