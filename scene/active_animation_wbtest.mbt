///|
fn patch_put_object(patch : FramePatch, id : ObjectId) -> @object.Object? {
  let mut result : @object.Object? = None
  for op in patch.ops {
    match (result, op) {
      (Some(_), _) => ()
      (None, Put(current, object)) => if current == id { result = Some(object) }
      _ => ()
    }
  }
  result
}

///|
test "active animation compile captures object op target without mutating scene" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let animation = square
    .animate(run_time=2.0)
    .shift(@object.Vec3::new(x=4.0, y=0.0))
    .to_animation()
  let active = ActiveAnimation::compile(scene, animation)
  assert_close(active.run_time(), 2.0)
  guard active.affected_ids().get(0) is Some(id) else {
    fail("active animation should report affected id")
  }
  assert_true(id == square)
  guard scene.get(square) is Some(start) else {
    fail("source object should still exist")
  }
  assert_close(start.transform.m03, 0.0)
  let patch = active.sample(0.5)
  guard patch_put_object(patch, square) is Some(sampled) else {
    fail("sample should put interpolated object")
  }
  assert_close(sampled.transform.m03, 2.0)
}

///|
test "active animation finish patch for fade out hides object" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let active = ActiveAnimation::compile(scene, Animation::fade_out(square))
  assert_true(active.lifecycle.remover)
  scene.apply_frame_patch(active.finish_patch())
  assert_true(!scene.is_visible(square))
  guard scene.state(square) is Some(Removed) else {
    fail("fade out finish patch should remove visible object")
  }
}

///|
test "active transform finish preserves visible draw order" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  ignore(scene.add(@object.Circle::new()))
  let active = ActiveAnimation::compile(
    scene,
    Animation::transform(square, @object.Circle::new(radius=2.0)),
  )
  scene.apply_frame_patch(active.finish_patch())
  assert_order(scene.visible_objects(), [0, 1])
}

///|
test "active transform begin makes allocated source visible" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let active = ActiveAnimation::compile(
    scene,
    Animation::transform(square, @object.Circle::new(radius=2.0)),
  )
  scene.apply_frame_patch(active.begin_patch())
  assert_true(scene.is_visible(square))
  assert_order(scene.visible_objects(), [0])
}

///|
test "wait active animation has no affected ids and empty patches" {
  let scene = Scene::new()
  let active = ActiveAnimation::compile(scene, Animation::wait(1.0))
  assert_eq(active.affected_ids().length(), 0)
  assert_true(active.begin_patch().is_empty())
  assert_true(active.sample(0.5).is_empty())
  assert_true(active.finish_patch().is_empty())
}

///|
test "sample_at_time clamps elapsed time to local alpha" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let active = ActiveAnimation::compile(
    scene,
    square
    .animate(run_time=2.0)
    .shift(@object.Vec3::new(x=4.0, y=0.0))
    .to_animation(),
  )
  guard patch_put_object(active.sample_at_time(8.0), square) is Some(sampled) else {
    fail("sample_at_time should put object")
  }
  assert_close(sampled.transform.m03, 4.0)
}
