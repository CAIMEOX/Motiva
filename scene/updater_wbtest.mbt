///|
fn assert_update_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "animated value trackers drive always_redraw in the same frame" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=2.0))
  let value = scene.value_tracker(0.0)
  let dot = scene.always_redraw(context => {
    @object.Dot::new(point=@object.Vec3::new(x=context.value(value), y=0.0))
  })
  let plan = scene.compile_play_plan(
    [value.animate_to(2.0, run_time=2.0, rate_func=Linear)],
    config=PlayConfig::image_sequence(),
  )
  plan.begin(scene)
  plan.apply_frame(scene, {
    frame_index: 2,
    play_time: 1.0,
    absolute_time: 1.0,
    dt: 0.5,
  })
  guard scene.get(dot) is Some(midpoint) else {
    fail("always_redraw object should remain addressable")
  }
  assert_update_close(scene.value(value), 1.0)
  assert_update_close(midpoint.center().x, 1.0)
  plan.finish(scene)
  guard scene.get(dot) is Some(endpoint) else {
    fail("always_redraw object should remain addressable after finish")
  }
  assert_update_close(scene.value(value), 2.0)
  assert_update_close(endpoint.center().x, 2.0)
}

///|
test "updaters read a frozen frame and chain locally on one target" {
  let scene = Scene::new()
  let left = scene.add(
    @object.Square::new(side_length=1.0)
    .to_object()
    .move_to(@object.Vec3::new(x=-2.0, y=0.0)),
  )
  let right = scene.add(
    @object.Circle::new(radius=0.5)
    .to_object()
    .move_to(@object.Vec3::new(x=2.0, y=0.0)),
  )
  ignore(
    scene.add_updater(
      Updater::object(left, (object, context) => {
        object.move_to(
          @object.Vec3::new(x=context.object(right).center().x, y=0.0),
        )
      }),
    ),
  )
  ignore(
    scene.add_updater(
      Updater::object(right, (object, context) => {
        object.move_to(
          @object.Vec3::new(x=context.object(left).center().x, y=0.0),
        )
      }),
    ),
  )
  ignore(
    scene.add_updater(
      Updater::object(left, (object, _context) => {
        object.move_to(@object.Vec3::new(x=object.center().x, y=1.5))
      }),
    ),
  )
  scene.advance(0.25)
  guard (scene.get(left), scene.get(right)) is (Some(left), Some(right)) else {
    fail("updated objects should remain addressable")
  }
  assert_update_close(left.center().x, 2.0)
  assert_update_close(left.center().y, 1.5)
  assert_update_close(right.center().x, -2.0)
}

///|
test "value phase feeds object phase independent of registration order" {
  let scene = Scene::new()
  let signal = scene.value_tracker(0.0)
  let dot = scene.add(@object.Dot::new())
  ignore(
    scene.add_updater(
      Updater::object(dot, (object, context) => {
        object.move_to(@object.Vec3::new(x=context.value(signal), y=0.0))
      }),
    ),
  )
  ignore(
    scene.add_updater(
      Updater::value(signal, (value, context) => value + context.dt()),
    ),
  )
  scene.advance(0.75)
  guard scene.get(dot) is Some(dot) else {
    fail("updated dot should remain addressable")
  }
  assert_update_close(scene.value(signal), 0.75)
  assert_update_close(dot.center().x, 0.75)
}

///|
test "call_now evaluates an updater even for an allocated object" {
  let scene = Scene::new()
  let dot = scene.object(@object.Dot::new())
  ignore(
    scene.add_updater(
      Updater::object(dot, (object, _context) => {
        object.move_to(@object.Vec3::new(x=1.25, y=-0.5))
      }),
      call_now=true,
    ),
  )
  guard scene.get(dot) is Some(dot_object) else {
    fail("allocated object should remain addressable")
  }
  assert_update_close(dot_object.center().x, 1.25)
  assert_update_close(dot_object.center().y, -0.5)
  assert_true(!scene.is_visible(dot))
}

///|
test "object animations suspend their target updaters and resume at finish" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=2.0))
  let square = scene.add(@object.Square::new(side_length=1.0))
  ignore(
    scene.add_updater(
      Updater::object(square, (object, context) => {
        object.with_transform(
          object.transform.then(
            @object.Transform::translate(
              @object.Vec3::new(x=10.0 * context.dt(), y=0.0),
            ),
          ),
        )
      }),
    ),
  )
  let plan = scene.compile_play_plan([
    square.animate(run_time=2.0).shift(@object.Vec3::new(x=2.0, y=0.0)),
  ])
  plan.begin(scene)
  plan.apply_frame(scene, {
    frame_index: 2,
    play_time: 1.0,
    absolute_time: 1.0,
    dt: 0.5,
  })
  guard scene.get(square) is Some(midpoint) else {
    fail("animated object should remain addressable")
  }
  assert_update_close(midpoint.center().x, 1.0)
  plan.finish(scene)
  guard scene.get(square) is Some(endpoint) else {
    fail("finished object should remain addressable")
  }
  assert_update_close(endpoint.center().x, 2.0)
  scene.advance(0.5)
  guard scene.get(square) is Some(advanced) else {
    fail("resumed object should remain addressable")
  }
  assert_update_close(advanced.center().x, 7.0)
}

///|
test "always_redraw keeps its root id while rebuilding family topology" {
  let scene = Scene::new()
  let count = scene.value_tracker(1.0)
  let root = scene.always_redraw(context => {
    let children = if context.value(count) < 2.0 {
      [@object.into_object(@object.Dot::new())]
    } else {
      [
        @object.into_object(
          @object.Dot::new(point=@object.Vec3::new(x=-1.0, y=0.0)),
        ),
        @object.into_object(
          @object.Dot::new(point=@object.Vec3::new(x=1.0, y=0.0)),
        ),
      ]
    }
    @object.Object::group(children)
  })
  assert_eq(scene.children(root).length(), 1)
  scene.set_value(count, 2.0)
  scene.advance(0.0)
  assert_eq(scene.children(root).length(), 2)
  assert_eq(scene.family(root).length(), 3)
  scene.set_value(count, 1.0)
  scene.advance(0.0)
  assert_eq(scene.children(root).length(), 1)
  scene.set_value(count, 2.0)
  scene.advance(0.0)
  assert_eq(scene.children(root).length(), 2)
  assert_eq(scene.object_count(), 3)
}

///|
test "value and camera updaters share handles and can be removed" {
  let scene = Scene::new()
  let elapsed = scene.value_tracker(0.0)
  let value_updater = scene.add_updater(
    Updater::value(elapsed, (value, context) => value + context.dt()),
  )
  let camera_updater = scene.add_updater(
    Updater::camera((camera, context) => {
      camera.with_view(theta=camera.theta + context.dt())
    }),
  )
  scene.advance(0.5)
  assert_update_close(scene.value(elapsed), 0.5)
  assert_update_close(scene.camera().theta, -@math.PI / 2.0 + 0.5)
  assert_true(scene.remove_updater(value_updater))
  assert_true(scene.remove_updater(camera_updater))
  assert_eq(scene.updater_count(), 0)
  scene.advance(0.5)
  assert_update_close(scene.value(elapsed), 0.5)
  assert_update_close(scene.camera().theta, -@math.PI / 2.0 + 0.5)
}

///|
test "value animations suspend value updaters unless explicitly disabled" {
  let scene = Scene::new()
  let value = scene.value_tracker(0.0)
  ignore(
    scene.add_updater(
      Updater::value(value, (current, context) => current + 10.0 * context.dt()),
    ),
  )
  let suspended = scene.compile_play_plan([
    value.animate_to(2.0, run_time=2.0, rate_func=Linear),
  ])
  suspended.begin(scene)
  suspended.apply_frame(scene, {
    frame_index: 1,
    play_time: 1.0,
    absolute_time: 1.0,
    dt: 1.0,
  })
  assert_update_close(scene.value(value), 1.0)
  suspended.finish(scene)
  assert_update_close(scene.value(value), 2.0)
  let unsuspended = scene.compile_play_plan([
    value
    .animate_to(4.0, run_time=2.0, rate_func=Linear)
    .with_updater_suspension(false),
  ])
  unsuspended.begin(scene)
  unsuspended.apply_frame(scene, {
    frame_index: 1,
    play_time: 1.0,
    absolute_time: 3.0,
    dt: 1.0,
  })
  assert_update_close(scene.value(value), 13.0)
}

///|
test "parallel animations reject duplicate value tracker targets" {
  let scene = Scene::new()
  let value = scene.value_tracker(0.0)
  let result = try
    scene.compile_play_plan([value.animate_to(1.0), value.animate_by(2.0)])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(ConflictingValueAnimations(conflict)) else {
    fail("duplicate tracker animations should return a typed SceneError")
  }
  assert_eq(conflict.id(), value.id())
  assert_update_close(scene.value(value), 0.0)
}

///|
test "topology-preserving updater failures are transactional" {
  let scene = Scene::new()
  let root = scene.add(
    @object.Object::group([
      @object.into_object(@object.Square::new(side_length=1.0)),
    ]),
  )
  let value = scene.value_tracker(0.0)
  ignore(
    scene.add_updater(
      Updater::value(value, (current, _context) => current + 1.0),
    ),
  )
  ignore(
    scene.add_updater(
      Updater::object(root, (_object, _context) => {
        @object.Object::group([
          @object.into_object(@object.Dot::new()),
          @object.into_object(@object.Dot::new()),
        ])
      }),
    ),
  )
  let result = try scene.advance(0.1) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(FamilyTopologyMismatch(id)) else {
    fail("ordinary object updaters should preserve family topology")
  }
  assert_eq(id.value(), root.value())
  assert_update_close(scene.value(value), 0.0)
  assert_update_close(scene.time(), 0.0)
  assert_eq(scene.children(root).length(), 1)
}

///|
test "frame transaction rolls back a late family conversion error" {
  let scene = Scene::new()
  let root = scene.add(
    @object.Object::group([@object.into_object(@object.Dot::new())]),
  )
  guard scene.children(root) is [child] else {
    fail("test family should expose one child")
  }
  ignore(
    scene.add_updater(
      Updater::object(root, (object, _context) => {
        object.with_transform(@object.Transform::scale(sx=0.0, sy=1.0))
      }),
    ),
  )
  ignore(
    scene.add_updater(
      Updater::object(child, (object, _context) => {
        object.move_to(@object.Vec3::new(x=2.0, y=0.0))
      }),
    ),
  )
  let result = try scene.advance(0.1) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(NonInvertibleFamilyTransform(id)) else {
    fail("late local conversion should return a typed SceneError")
  }
  assert_eq(id.value(), child.value())
  guard (scene.get(root), scene.get(child)) is (Some(root), Some(child)) else {
    fail("rolled back family should remain addressable")
  }
  assert_update_close(root.transform.m00, 1.0)
  assert_update_close(child.center().x, 0.0)
  assert_update_close(scene.time(), 0.0)
}

///|
test "play plan rolls back animation sampling when an updater fails" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new(side_length=1.0))
  let observer = scene.add(@object.Dot::new())
  let failing = scene.add_updater(
    Updater::object(observer, (object, context) => {
      ignore(context.object({ value: 999 }))
      object
    }),
  )
  let plan = scene.compile_play_plan([
    square.animate(run_time=2.0).shift(@object.Vec3::new(x=2.0, y=0.0)),
  ])
  plan.begin(scene)
  let result = try
    plan.apply_frame(scene, {
      frame_index: 1,
      play_time: 1.0,
      absolute_time: 1.0,
      dt: 1.0,
    })
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(UnknownObject(id)) else {
    fail("updater failure should escape as a typed SceneError")
  }
  assert_eq(id.value(), 999)
  guard scene.get(square) is Some(square_before) else {
    fail("animated object should remain addressable after rollback")
  }
  assert_update_close(square_before.center().x, 0.0)
  assert_update_close(scene.time(), 0.0)
  assert_true(scene.remove_updater(failing))
  plan.finish(scene)
  guard scene.get(square) is Some(square_after) else {
    fail("animation should still be finishable after removing the bad updater")
  }
  assert_update_close(square_after.center().x, 2.0)
  assert_update_close(scene.time(), 2.0)
}

///|
test "play_immediate advances time based updaters across a wait" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=4.0))
  let elapsed = scene.value_tracker(0.0)
  ignore(
    scene.add_updater(
      Updater::value(elapsed, (value, context) => value + context.dt()),
    ),
  )
  scene.play([Animation::wait(1.0)])
  assert_update_close(scene.time(), 1.0)
  assert_update_close(scene.value(elapsed), 1.0)
}

///|
test "advance rejects a negative or non-finite delta" {
  let scene = Scene::new()
  let negative = try scene.advance(-0.1) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard negative is Err(InvalidDeltaTime(value)) else {
    fail("negative delta should return a typed SceneError")
  }
  assert_update_close(value, -0.1)
  let infinite = try scene.advance(1.0 / 0.0) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard infinite is Err(InvalidDeltaTime(_)) else {
    fail("non-finite delta should return a typed SceneError")
  }
}
