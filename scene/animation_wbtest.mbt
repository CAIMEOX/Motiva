///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "play create shows allocated object and advances time" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  scene.play([Animation::create(square, run_time=0.5)])
  assert_true(scene.is_visible(square))
  assert_close(scene.time(), 0.5)
}

///|
test "play fade out removes visible object and advances maximum run time" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.add(@object.Circle::new())
  scene.play([
    Animation::fade_out(square, run_time=0.25),
    Animation::fade_out(circle, run_time=1.5),
  ])
  assert_true(!scene.is_visible(square))
  assert_true(!scene.is_visible(circle))
  assert_close(scene.time(), 1.5)
}

///|
test "play transform replaces object and shows allocated source" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new(side_length=2.0))
  scene.play([
    Animation::transform(square, @object.Circle::new(radius=2.0), run_time=2.0),
  ])
  assert_true(scene.is_visible(square))
  assert_close(scene.time(), 2.0)
  guard scene.get(square) is Some(object) else {
    fail("transformed object should be present")
  }
  guard object.bounds() is Some(bounds) else {
    fail("transformed object should have bounds")
  }
  assert_true(bounds.width() > 3.9)
}

///|
test "object animate applies object operations" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  scene.play([
    square
    .animate(run_time=0.75)
    .shift(@object.Vec3::new(x=3.0, y=-1.0, z=2.0))
    .set_z_index(4.0),
  ])
  assert_true(scene.is_visible(square))
  assert_close(scene.time(), 0.75)
  guard scene.get(square) is Some(object) else {
    fail("animated object should be present")
  }
  assert_close(object.transform.m03, 3.0)
  assert_close(object.transform.m13, -1.0)
  assert_close(object.transform.m23, 2.0)
  assert_close(object.z_index, 4.0)
}

///|
test "animate builder is pure over existing operation arrays" {
  let square = { value: 0 }
  let base = square.animate()
  let shifted = base.shift(@object.Vec3::new(x=1.0, y=0.0))
  assert_eq(base.ops.length(), 0)
  assert_eq(shifted.ops.length(), 1)
}

///|
test "play unknown animation target returns typed scene error" {
  let scene = Scene::new()
  let unknown = { value: 99 }
  let result = try scene.play([Animation::create(unknown)]) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(UnknownObject(id)) else {
    fail("unknown animation target should return typed SceneError")
  }
  assert_eq(id.value, 99)
}
