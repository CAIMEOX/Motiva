///|
test "animation group schedules children with lag ratio and auto run time" {
  let scene = Scene::new()
  let first = scene.object(@object.Square::new(side_length=2.0))
  let second = scene.object(@object.Square::new(side_length=2.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::group(
      [
        Animation::create(first, run_time=1.0),
        Animation::create(second, run_time=1.0),
      ],
      lag_ratio=0.5,
    ),
  )
  assert_close(active.run_time(), 1.5)
  let early = active.sample_at_time(0.25)
  assert_true(patch_put_object(early, first) is Some(_))
  assert_true(patch_put_object(early, second) is None)
  let overlap = active.sample_at_time(0.75)
  assert_true(patch_put_object(overlap, first) is Some(_))
  assert_true(patch_put_object(overlap, second) is Some(_))
}

///|
test "animation group fixed run time rescales internal timeline" {
  let scene = Scene::new()
  let first = scene.object(@object.Square::new(side_length=2.0))
  let second = scene.object(@object.Square::new(side_length=2.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::group(
      [
        Animation::create(first, run_time=1.0),
        Animation::create(second, run_time=1.0),
      ],
      run_time=4.0,
      lag_ratio=1.0,
    ),
  )
  assert_close(active.run_time(), 4.0)
  let before_second = active.sample_at_time(1.5)
  assert_true(patch_put_object(before_second, first) is Some(_))
  assert_true(patch_put_object(before_second, second) is None)
  let during_second = active.sample_at_time(3.0)
  assert_true(patch_put_object(during_second, second) is Some(_))
}

///|
test "lagged start uses manim default lag ratio" {
  let scene = Scene::new()
  let first = scene.object(@object.Square::new(side_length=2.0))
  let second = scene.object(@object.Square::new(side_length=2.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::lagged_start([
      Animation::create(first, run_time=1.0),
      Animation::create(second, run_time=1.0),
    ]),
  )
  assert_close(active.run_time(), 1.05)
}

///|
test "replacement group swaps source and target families after child animations" {
  let scene = Scene::new()
  let source = scene.add(@object.Square::new(side_length=2.0))
  let target = scene.object(@object.Circle::new(radius=1.0))
  let animation = Animation::replacement(
    source~,
    target~,
    [Animation::transform(source, @object.Circle::new(radius=1.0))],
    run_time=1.0,
  )
  let plan = scene.compile_play_plan(
    [animation],
    config=PlayConfig::image_sequence(),
  )
  plan.begin(scene)
  assert_true(scene.is_visible(source))
  assert_true(!scene.is_visible(target))
  plan.finish(scene)
  assert_true(!scene.is_visible(source))
  assert_true(scene.is_visible(target))
}

///|
test "replacement finish reveals target siblings after one target child starts" {
  let scene = Scene::new()
  let source = scene.add(@object.Square::new(side_length=2.0))
  let target = scene.object(
    @object.Object::group([
      @object.into_object(@object.Circle::new(radius=1.0)),
      @object.into_object(@object.Square::new(side_length=1.0)),
    ]),
  )
  guard scene.family(target) is [_, first, second] else {
    fail("target should contain two path children")
  }
  let plan = scene.compile_play_plan([
    Animation::replacement(
      source~,
      target~,
      [Animation::fade_in(second, run_time=1.0)],
      run_time=1.0,
    ),
  ])
  plan.begin(scene)
  assert_true(scene.is_visible(target))
  assert_true(!scene.is_visible(first))
  plan.finish(scene)
  assert_true(scene.family(target).all(id => scene.is_visible(id)))
}
