///|
fn assert_family_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_same_id(
  actual : @scene.ObjectId,
  expected : @scene.ObjectId,
) -> Unit raise {
  assert_eq(actual.value(), expected.value())
}

///|
fn two_object_family() -> @object.Object {
  @object.Object::group([
    @object.into_object(@object.Square::new(side_length=1.0)),
    @object.into_object(@object.Circle::new(radius=0.5)),
  ]).arrange(direction=@object.Vec3::new(x=1.0, y=0.0), buff=0.5)
}

///|
test "scene recursively allocates stable identities for an object family" {
  let scene = @scene.Scene::new()
  let root = scene.add(two_object_family())
  let children = scene.children(root)
  guard children is [square, circle] else {
    fail("family root should expose both direct children")
  }
  assert_eq(scene.object_count(), 3)
  assert_eq(scene.visible_count(), 1)
  assert_true(scene.is_visible(root))
  assert_true(scene.is_visible(square))
  assert_true(scene.is_visible(circle))
  guard scene.parent(square) is Some(square_parent) else {
    fail("square should retain its family parent")
  }
  guard scene.parent(circle) is Some(circle_parent) else {
    fail("circle should retain its family parent")
  }
  assert_same_id(square_parent, root)
  assert_same_id(circle_parent, root)
  guard scene.family(root) is [family_root, family_square, family_circle] else {
    fail("family traversal should be stable pre-order")
  }
  assert_same_id(family_root, root)
  assert_same_id(family_square, square)
  assert_same_id(family_circle, circle)
  guard scene.get(root) is Some(object) && object.node is Group(objects) else {
    fail("scene get should rebuild the complete object family")
  }
  assert_eq(objects.length(), 2)
}

///|
test "animating a child updates its family without changing identity" {
  let scene = @scene.Scene::new()
  let root = scene.add(two_object_family())
  guard scene.children(root) is [square, circle] else {
    fail("family root should expose both children")
  }
  scene.play([
    square.animate(run_time=1.0).move_to(@object.Vec3::new(x=-2.0, y=1.25)),
  ])
  guard scene.children(root) is [same_square, same_circle] else {
    fail("child animation should preserve family shape")
  }
  assert_same_id(same_square, square)
  assert_same_id(same_circle, circle)
  guard scene.get(square) is Some(square_object) else {
    fail("animated child should remain addressable")
  }
  assert_family_close(square_object.center().x, -2.0)
  assert_family_close(square_object.center().y, 1.25)
  guard scene.get(root) is Some(family) && family.node is Group(objects) else {
    fail("family should rebuild after child animation")
  }
  guard objects.get(0) is Some(family_square) else {
    fail("family should contain its animated child")
  }
  let family_square_center = family.transform.apply_point(
    family_square.center(),
  )
  assert_family_close(family_square_center.x, -2.0)
  assert_family_close(family_square_center.y, 1.25)
}

///|
test "animating a family root transforms descendants and preserves child ids" {
  let scene = @scene.Scene::new()
  let root = scene.add(two_object_family())
  guard scene.children(root) is [square, circle] else {
    fail("family root should expose both children")
  }
  guard (scene.get(square), scene.get(circle))
    is (Some(square_before), Some(circle_before)) else {
    fail("family children should be addressable before animation")
  }
  scene.play([
    root.animate(run_time=1.0).shift(@object.Vec3::new(x=1.5, y=-0.75)),
  ])
  guard scene.children(root) is [same_square, same_circle] else {
    fail("family animation should preserve direct child ids")
  }
  assert_same_id(same_square, square)
  assert_same_id(same_circle, circle)
  guard (scene.get(square), scene.get(circle))
    is (Some(square_after), Some(circle_after)) else {
    fail("family children should remain addressable after animation")
  }
  assert_family_close(square_after.center().x, square_before.center().x + 1.5)
  assert_family_close(square_after.center().y, square_before.center().y - 0.75)
  assert_family_close(circle_after.center().x, circle_before.center().x + 1.5)
  assert_family_close(circle_after.center().y, circle_before.center().y - 0.75)
}

///|
test "family keeps its root transform and supports absolute transform reset" {
  let base = two_object_family()
  guard base.node is Group([base_square, base_circle]) else {
    fail("test family should contain two objects")
  }
  let scene = @scene.Scene::new()
  let moved = base.move_to(@object.Vec3::new(x=3.0, y=1.0))
  let root = scene.add(moved)
  guard scene.children(root) is [square, circle] else {
    fail("family root should expose both children")
  }
  guard scene.get(root) is Some(root_before) else {
    fail("family root should remain addressable")
  }
  assert_family_close(root_before.transform.m03, moved.transform.m03)
  assert_family_close(root_before.transform.m13, moved.transform.m13)
  assert_family_close(root_before.center().x, 3.0)
  assert_family_close(root_before.center().y, 1.0)
  scene.play([
    root.animate(run_time=1.0).set_transform(@object.Transform::identity()),
  ])
  guard scene.get(root) is Some(root_after) else {
    fail("family root should remain addressable after reset")
  }
  assert_family_close(root_after.transform.m03, 0.0)
  assert_family_close(root_after.transform.m13, 0.0)
  guard (scene.get(square), scene.get(circle))
    is (Some(square_after), Some(circle_after)) else {
    fail("family children should remain addressable after reset")
  }
  assert_family_close(square_after.center().x, base_square.center().x)
  assert_family_close(square_after.center().y, base_square.center().y)
  assert_family_close(circle_after.center().x, base_circle.center().x)
  assert_family_close(circle_after.center().y, base_circle.center().y)
}

///|
test "showing and removing a child preserves its family identity" {
  let scene = @scene.Scene::new()
  let root = scene.object(two_object_family())
  guard scene.children(root) is [square, circle] else {
    fail("family root should expose both children")
  }
  scene.show(square)
  guard scene.visible_objects() is [draw_root] else {
    fail("a visible child should make its family reachable by the renderer")
  }
  assert_same_id(draw_root, root)
  assert_true(scene.is_visible(root))
  assert_true(scene.is_visible(square))
  assert_true(!scene.is_visible(circle))
  scene.remove(root)
  assert_eq(scene.visible_count(), 0)
  assert_true(!scene.is_visible(square))
  scene.show(square)
  scene.remove(square)
  assert_eq(scene.visible_count(), 0)
  guard scene.parent(square) is Some(square_parent) else {
    fail("removing a child should not detach its stable family identity")
  }
  assert_same_id(square_parent, root)
  guard scene.children(root) is [same_square, same_circle] else {
    fail("removing a child should preserve family topology")
  }
  assert_same_id(same_square, square)
  assert_same_id(same_circle, circle)
}

///|
test "family replacement rejects topology changes before rebinding ids" {
  let scene = @scene.Scene::new()
  let root = scene.add(two_object_family())
  let before = scene.family(root)
  let result = try
    scene.replace(
      root,
      @object.Object::group([
        @object.into_object(@object.Square::new(side_length=2.0)),
      ]),
    )
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(@scene.FamilyTopologyMismatch(id)) else {
    fail("family topology changes should return a typed SceneError")
  }
  assert_same_id(id, root)
  let after = scene.family(root)
  assert_eq(after.length(), before.length())
  for index in 0..<before.length() {
    match (before.get(index), after.get(index)) {
      (Some(expected), Some(actual)) => assert_same_id(actual, expected)
      _ => fail("family traversal should preserve every identity")
    }
  }
}

///|
test "child animation converts world space through an affine parent" {
  let parent_transform = @object.Transform::scale(sx=1.75, sy=0.6)
    .then(@object.Transform::rotate(angle=@math.PI / 3.0))
    .then(@object.Transform::translate(@object.Vec3::new(x=2.0, y=-1.0)))
  let scene = @scene.Scene::new()
  let root = scene.add(
    @object.Object::group([
      @object.into_object(@object.Square::new(side_length=1.0)),
    ]).with_transform(parent_transform),
  )
  guard scene.children(root) is [square] else {
    fail("family root should expose its child")
  }
  let target = @object.Vec3::new(x=-1.25, y=2.5)
  scene.play([square.animate(run_time=1.0).move_to(target)])
  guard scene.get(square) is Some(moved) else {
    fail("animated child should remain addressable")
  }
  assert_family_close(moved.center().x, target.x)
  assert_family_close(moved.center().y, target.y)
  guard scene.parent(square) is Some(parent) else {
    fail("world-space animation should preserve the child parent")
  }
  assert_same_id(parent, root)
}

///|
test "transform animation rebuilds a smaller target family" {
  let scene = @scene.Scene::new()
  let root = scene.object(two_object_family())
  guard scene.children(root) is [first, second] else {
    fail("source family should begin with two children")
  }
  scene.play([
    @scene.Animation::transform(
      root,
      @object.Object::group([
        @object.into_object(@object.Circle::new(radius=1.0)),
      ]),
      run_time=1.0,
    ),
  ])
  guard scene.children(root) is [remaining] else {
    fail("transform should rebuild the smaller target family")
  }
  assert_same_id(remaining, first)
  assert_true(scene.state(second) == Some(@scene.Removed))
  assert_true(scene.is_visible(root))
  assert_family_close(scene.time(), 1.0)
}

///|
test "animation groups reject overlapping family targets before mutation" {
  let scene = @scene.Scene::new()
  let root = scene.object(two_object_family())
  guard scene.children(root) is [square, _] else {
    fail("family root should expose its first child")
  }
  let result = try
    scene.play([
      @scene.Animation::group([
        root.animate(run_time=1.0).shift(@object.Vec3::new(x=1.0, y=0.0)),
        square.animate(run_time=1.0).shift(@object.Vec3::new(x=0.0, y=1.0)),
      ]),
    ])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(@scene.ConflictingFamilyAnimations(first, second)) else {
    fail("overlapping family animations should return a typed SceneError")
  }
  assert_same_id(first, root)
  assert_same_id(second, square)
  assert_eq(scene.visible_count(), 0)
  assert_family_close(scene.time(), 0.0)
}

///|
test "parallel scene play rejects overlapping family targets" {
  let scene = @scene.Scene::new()
  let root = scene.object(two_object_family())
  guard scene.children(root) is [square, _] else {
    fail("family root should expose its first child")
  }
  let result = try
    scene.play([
      root.animate(run_time=1.0).shift(@object.Vec3::new(x=1.0, y=0.0)),
      square.animate(run_time=1.0).shift(@object.Vec3::new(x=0.0, y=1.0)),
    ])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(@scene.ConflictingFamilyAnimations(first, second)) else {
    fail("parallel family animations should return a typed SceneError")
  }
  assert_same_id(first, root)
  assert_same_id(second, square)
  assert_eq(scene.visible_count(), 0)
}
