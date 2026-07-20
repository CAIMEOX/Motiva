///|
fn assert_camera_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
test "scene owns and updates camera state" {
  let scene = Scene::new(
    camera=@camera.Camera::new(projection=Perspective, phi=0.25, zoom=1.5),
  )
  assert_true(scene.camera().projection == Perspective)
  assert_camera_close(scene.camera().phi, 0.25)
  scene.set_camera_orientation(theta=0.75, zoom=2.0)
  assert_camera_close(scene.camera().phi, 0.25)
  assert_camera_close(scene.camera().theta, 0.75)
  assert_camera_close(scene.camera().zoom, 2.0)
  scene.set_camera_projection(ExponentialPerspective)
  assert_true(scene.camera().projection == ExponentialPerspective)
}

///|
test "fixed orientation shares the family root center" {
  let group = @object.Object::group([
    @object.into_object(@object.Square::new()).with_transform(
      @object.Transform::translate(@object.Vec3::new(x=-2.0, y=0.0)),
    ),
    @object.into_object(@object.Circle::new()).with_transform(
      @object.Transform::translate(@object.Vec3::new(x=2.0, y=0.0)),
    ),
  ])
  let scene = Scene::new()
  let root = scene.add(group)
  guard scene.children(root) is [left, right] else {
    fail("group should expose both children")
  }
  scene.add_fixed_orientation(root)
  guard (scene.camera_space(left), scene.camera_space(right))
    is (FixedOrientation(left_center), FixedOrientation(right_center)) else {
    fail("both family leaves should have fixed orientation")
  }
  assert_camera_close(left_center.x, 0.0)
  assert_camera_close(right_center.x, 0.0)
  assert_camera_close(left_center.y, right_center.y)
}

///|
test "fixed orientation supports static and custom centers" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  scene.add_fixed_orientation(square, use_static_center_func=true)
  guard scene.camera_space(square) is FixedOrientation(static_center) else {
    fail("static center should produce fixed orientation")
  }
  assert_camera_close(static_center.x, 0.0)
  scene.remove_fixed_orientation(square)
  assert_true(scene.camera_space(square) is World)
  scene.add_fixed_orientation(square, center_func=() => {
    @object.Vec3::new(x=3.0, y=4.0, z=5.0)
  })
  guard scene.camera_space(square) is FixedOrientation(custom_center) else {
    fail("custom center should produce fixed orientation")
  }
  assert_camera_close(custom_center.x, 3.0)
  assert_camera_close(custom_center.y, 4.0)
  assert_camera_close(custom_center.z, 5.0)
}

///|
test "fixed in frame is independent from foreground ordering" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  scene.add_fixed_in_frame(square)
  assert_true(scene.camera_space(square) is FixedInFrame)
  assert_eq(scene.foreground_objects().length(), 0)
  scene.remove_fixed_in_frame(square)
  assert_true(scene.camera_space(square) is World)
}

///|
test "camera motion is sampled by play plan" {
  let scene = Scene::new(config=SceneConfig::new(frame_rate=2.0))
  let plan = scene.compile_play_plan(
    [
      Animation::move_camera(
        phi=1.0,
        theta=0.5,
        zoom=2.0,
        run_time=1.0,
        rate_func=Linear,
      ),
    ],
    config=PlayConfig::image_sequence(),
  )
  plan.begin(scene)
  guard plan.frame_times().get(1) is Some(midpoint) else {
    fail("two fps plan should contain midpoint")
  }
  plan.apply_frame(scene, midpoint)
  assert_camera_close(scene.camera().phi, 0.5)
  assert_camera_close(scene.camera().theta, (0.0 - @math.PI / 2.0 + 0.5) / 2.0)
  assert_camera_close(scene.camera().zoom, 1.5)
  plan.finish(scene)
  assert_camera_close(scene.camera().phi, 1.0)
  assert_camera_close(scene.camera().theta, 0.5)
  assert_camera_close(scene.camera().zoom, 2.0)
}

///|
test "camera orbit resolves relative to compile-time camera" {
  let scene = Scene::new()
  scene.orbit_camera(
    phi_delta=0.25,
    theta_delta=0.5,
    gamma_delta=-0.75,
    run_time=1.0,
  )
  assert_camera_close(scene.camera().phi, 0.25)
  assert_camera_close(scene.camera().theta, 0.5 - @math.PI / 2.0)
  assert_camera_close(scene.camera().gamma, -0.75)
}

///|
test "parallel camera animations return a typed conflict" {
  let scene = Scene::new()
  let result = try
    scene.compile_play_plan([
      Animation::move_camera(phi=1.0),
      Animation::move_camera(theta=1.0),
    ])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  assert_true(result is Err(ConflictingCameraAnimations))
}

///|
test "camera animation validates its resolved target" {
  let scene = Scene::new()
  let result = try
    scene.compile_play_plan([Animation::move_camera(zoom=0.0)])
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  assert_true(result is Err(Camera(InvalidZoom(0.0))))
}

///|
test "camera and object animations can share a play" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  scene.play_immediate([
    Animation::move_camera(phi=0.5, run_time=1.0),
    square
    .animate(run_time=1.0)
    .shift(@object.Vec3::new(x=2.0, y=0.0))
    .to_animation(),
  ])
  assert_camera_close(scene.camera().phi, 0.5)
  guard scene.get(square) is Some(object) else {
    fail("square should remain in scene")
  }
  assert_camera_close(object.transform.m03, 2.0)
}
