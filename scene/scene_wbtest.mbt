///|
fn assert_object_id(actual : ObjectId, expected : Int) -> Unit raise {
  assert_eq(actual.value, expected)
}

///|
fn assert_order(actual : Array[ObjectId], expected : Array[Int]) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for index in 0..<expected.length() {
    guard actual.get(index) is Some(id) else {
      fail("draw order should contain id at index")
    }
    guard expected.get(index) is Some(value) else {
      fail("expected order should contain value at index")
    }
    assert_eq(id.value, value)
  }
}

///|
test "object allocates identity without making it visible" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  assert_object_id(square, 0)
  assert_eq(scene.object_count(), 1)
  assert_eq(scene.visible_count(), 0)
  assert_true(!scene.is_visible(square))
  guard scene.state(square) is Some(Allocated) else {
    fail("newly allocated object should be allocated")
  }
}

///|
test "add allocates identity and appends to draw order" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.add(@object.Circle::new())
  assert_object_id(square, 0)
  assert_object_id(circle, 1)
  assert_order(scene.visible_objects(), [0, 1])
  assert_true(scene.is_visible(square))
  assert_true(scene.is_visible(circle))
}

///|
test "show makes an allocated object visible and moves visible objects to front" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.add(@object.Circle::new())
  scene.show(square)
  assert_order(scene.visible_objects(), [1, 0])
  scene.remove(circle)
  assert_order(scene.visible_objects(), [0])
  scene.show(circle)
  assert_order(scene.visible_objects(), [0, 1])
}

///|
test "remove hides an object without deleting its stored data" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  scene.remove(square)
  assert_eq(scene.object_count(), 1)
  assert_eq(scene.visible_count(), 0)
  assert_true(!scene.is_visible(square))
  guard scene.state(square) is Some(Removed) else {
    fail("removed visible object should be marked removed")
  }
  guard scene.get(square) is Some(_) else {
    fail("removed object data should still be stored")
  }
}

///|
test "replace keeps identity and visibility" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new(side_length=2.0))
  scene.replace(square, @object.Circle::new(radius=2.0))
  assert_order(scene.visible_objects(), [0])
  assert_true(scene.is_visible(square))
  guard scene.get(square) is Some(object) else {
    fail("replaced object should still be present")
  }
  guard object.bounds() is Some(bounds) else {
    fail("replaced circle should have bounds")
  }
  assert_true(bounds.width() > 3.9)
}

///|
test "foreground is tracked separately from draw order" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.object(@object.Circle::new())
  scene.show_foreground(circle)
  assert_order(scene.visible_objects(), [0, 1])
  assert_order(scene.foreground_objects(), [1])
  scene.remove_foreground(circle)
  assert_order(scene.visible_objects(), [0, 1])
  assert_order(scene.foreground_objects(), [])
  scene.remove(square)
  assert_order(scene.visible_objects(), [1])
}

///|
test "clear removes visible objects and preserves allocated objects" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.object(@object.Circle::new())
  scene.clear()
  assert_eq(scene.object_count(), 2)
  assert_order(scene.visible_objects(), [])
  guard scene.state(square) is Some(Removed) else {
    fail("visible object should be marked removed by clear")
  }
  guard scene.state(circle) is Some(Allocated) else {
    fail("allocated object should remain allocated by clear")
  }
}

///|
test "unknown object operations are typed errors" {
  let scene = Scene::new()
  let unknown = { value: 99 }
  let result = try scene.show(unknown) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(UnknownObject(id)) else {
    fail("unknown show should return typed SceneError")
  }
  assert_object_id(id, 99)
}

///|
test "play writer intercepts scene play and can drive immediate playback" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=4.0))
  let calls : Array[Int] = []
  let writer = PlayWriter::new((scene, animations) => {
    calls.push(animations.length())
    scene.play_immediate(animations, config=PlayConfig::image_sequence())
  })
  scene.set_play_writer(Some(writer))
  let square = scene.object(@object.Square::new())
  scene.play([
    square.animate(run_time=1.0).shift(@object.Vec3::new(x=3.0, y=0.0)),
  ])
  assert_eq(calls.length(), 1)
  assert_eq(calls[0], 1)
  assert_true(scene.is_visible(square))
  guard scene.get(square) is Some(object) else {
    fail("writer playback should leave final object in scene")
  }
  assert_true(Double::abs(object.transform.m03 - 3.0) < 0.000001)
  assert_true(Double::abs(scene.time() - 1.0) < 0.000001)
}
