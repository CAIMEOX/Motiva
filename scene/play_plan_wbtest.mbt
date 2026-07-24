///|
fn assert_plan_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "play plan frame times use scene frame rate" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=10.0))
  let square = scene.object(@object.Square::new())
  let plan = scene.compile_play_plan(
    [Animation::create(square, run_time=0.25)],
    config=PlayConfig::image_sequence(),
  )
  assert_plan_close(plan.start_time(), 0.0)
  assert_plan_close(plan.run_time(), 0.25)
  assert_plan_close(plan.frame_rate(), 10.0)
  assert_eq(plan.frame_count(), 4)
  let frames = plan.frame_times()
  guard frames.get(0) is Some(first) else {
    fail("plan should contain start frame")
  }
  guard frames.get(2) is Some(third) else {
    fail("plan should contain third frame")
  }
  guard frames.get(3) is Some(last) else {
    fail("plan should contain explicit end frame")
  }
  assert_plan_close(first.play_time, 0.0)
  assert_plan_close(third.play_time, 0.2)
  assert_plan_close(last.play_time, 0.25)
}

///|
test "default play plan samples a half-open time interval" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=10.0))
  let square = scene.object(@object.Square::new())
  let plan = scene.compile_play_plan([Animation::create(square, run_time=0.25)])
  assert_eq(plan.frame_count(), 3)
  guard plan.frame_times().last() is Some(last) else {
    fail("continuous play plan should contain sampled frames")
  }
  assert_plan_close(last.play_time, 0.2)
}

///|
test "play plan applies sampled animation state to scene" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let plan = scene.compile_play_plan([
    square.animate(run_time=2.0).shift(@object.Vec3::new(x=4.0, y=0.0)),
  ])
  plan.begin(scene)
  assert_true(scene.is_visible(square))
  plan.apply_frame(scene, {
    frame_index: 0,
    play_time: 1.0,
    absolute_time: 1.0,
    dt: 1.0,
  })
  guard scene.get(square) is Some(sampled) else {
    fail("sampled object should exist")
  }
  assert_plan_close(sampled.center().x, 2.0)
  assert_plan_close(scene.time(), 1.0)
  plan.finish(scene)
  guard scene.get(square) is Some(finished) else {
    fail("finished object should exist")
  }
  assert_plan_close(finished.center().x, 4.0)
  assert_plan_close(scene.time(), 2.0)
}

///|
test "compile play plan rejects empty animation list" {
  let scene = Scene::new()
  let animations : Array[Animation] = []
  let result = try scene.compile_play_plan(animations) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(EmptyPlay) else {
    fail("empty play should return typed SceneError")
  }
}

///|
test "compile play plan rejects invalid frame rate" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=0.0))
  let square = scene.object(@object.Square::new())
  let result = try scene.compile_play_plan([Animation::create(square)]) catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(InvalidFrameRate(rate)) else {
    fail("invalid frame rate should return typed SceneError")
  }
  assert_plan_close(rate, 0.0)
}

///|
test "compile play plan rejects non-finite timing inputs" {
  let infinite_rate = Scene::new(config=SceneConfig::new(frame_rate=1.0 / 0.0))
  let rate_object = infinite_rate.object(@object.Dot::new())
  let rate_result = try
    infinite_rate.compile_play_plan([Animation::create(rate_object)])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard rate_result is Err(InvalidFrameRate(_)) else {
    fail("infinite frame rate should return a typed SceneError")
  }
  let scene = Scene::new()
  let object = scene.object(@object.Dot::new())
  let duration_result = try
    scene.compile_play_plan([Animation::create(object, run_time=1.0 / 0.0)])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard duration_result is Err(InvalidRunTime(_)) else {
    fail("infinite run time should return a typed SceneError")
  }
}
