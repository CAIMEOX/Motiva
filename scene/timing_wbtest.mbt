///|
fn assert_timing_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "timing maps elapsed time through built in rate functions" {
  let linear = Timing::new(run_time=2.0, rate_func=Linear)
  assert_timing_close(linear.alpha_at(0.5), 0.25)
  assert_timing_close(linear.alpha_at(4.0), 1.0)
  let reversed = Timing::new(
    run_time=2.0,
    rate_func=Linear,
    reverse_rate_function=true,
  )
  assert_timing_close(reversed.alpha_at(0.5), 0.75)
  let there_and_back = Timing::new(run_time=2.0, rate_func=ThereAndBack)
  assert_timing_close(there_and_back.alpha_at(0.0), 0.0)
  assert_timing_close(there_and_back.alpha_at(1.0), 1.0)
  assert_timing_close(there_and_back.alpha_at(2.0), 0.0)
}

///|
test "timing accepts custom rate functions" {
  let timing = Timing::new(run_time=2.0, rate_func=Custom(t => t * t))
  assert_timing_close(timing.alpha_at(1.0), 0.25)
}

///|
test "auto timing resolves against natural run time" {
  let timing = Timing::auto(lag_ratio=0.25)
  assert_timing_close(timing.resolve_run_time(2.0), 2.0)
  assert_timing_close(timing.alpha_at_run_time(1.0, 2.0), 0.5)
  assert_timing_close(timing.lag_ratio, 0.25)
}

///|
test "active animation samples builder custom rate function" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let animation = square
    .animate(run_time=2.0, rate_func=Custom(t => t * t))
    .shift(@object.Vec3::new(x=4.0, y=0.0))
    .to_animation()
  let active = ActiveAnimation::compile(scene, animation)
  guard patch_put_object(active.sample_at_time(1.0), square) is Some(sampled) else {
    fail("custom rate function should sample an object")
  }
  assert_timing_close(sampled.center().x, 1.0)
}
