///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_vec3_close(
  actual : @object.Vec3,
  expected : @object.Vec3,
) -> Unit raise {
  assert_close(actual.x, expected.x)
  assert_close(actual.y, expected.y)
  assert_close(actual.z, expected.z)
}

///|
test "camera derives frame shape from pixel aspect" {
  let wide = Camera::new(pixel_width=1280, pixel_height=720, frame_width=6.0)
  assert_close(wide.frame_width, 6.0)
  assert_close(wide.frame_height, 3.375)
  let tall = Camera::new(pixel_width=1280, pixel_height=720, frame_height=4.0)
  assert_close(tall.frame_width, 64.0 / 9.0)
  assert_close(tall.frame_height, 4.0)
}

///|
test "default camera preserves world orientation" {
  let camera = Camera::default()
  let point = @object.Vec3::new(x=1.0, y=2.0, z=3.0)
  assert_vec3_close(camera.world_to_camera(point), point)
  assert_vec3_close(camera.project_point(point), point)
}

///|
test "camera uses Manim phi theta gamma rotation order" {
  let camera = Camera::new(phi=@math.PI / 2.0)
  assert_vec3_close(
    camera.world_to_camera(@object.Vec3::unit_z()),
    @object.Vec3::new(x=0.0, y=1.0, z=0.0),
  )
}

///|
test "perspective and exponential projection use camera depth" {
  let perspective = Camera::new(projection=Perspective, focal_distance=10.0)
  assert_vec3_close(
    perspective.project_point(@object.Vec3::new(x=1.0, y=2.0, z=5.0)),
    @object.Vec3::new(x=2.0, y=4.0, z=5.0),
  )
  let exponential = perspective.with_projection(ExponentialPerspective)
  let depth = 10.0 * @math.ln(2.0)
  assert_close(
    exponential.project_point(@object.Vec3::new(x=1.0, y=0.0, z=depth)).x,
    2.0,
  )
  assert_close(
    exponential.project_point(@object.Vec3::new(x=1.0, y=0.0, z=-10.0)).x,
    0.5,
  )
}

///|
test "projection and pixel transforms round trip" {
  let camera = Camera::new(
    pixel_width=640,
    pixel_height=360,
    frame_center=@object.Vec3::new(x=1.0, y=-2.0, z=0.5),
    projection=Perspective,
    phi=0.4,
    theta=-0.7,
    gamma=0.2,
    zoom=1.3,
    focal_distance=20.0,
  )
  let point = @object.Vec3::new(x=2.0, y=1.0, z=-1.0)
  let projected = camera.project_point(point)
  assert_vec3_close(camera.unproject_point(projected), point)
  let frame = @object.Vec3::new(x=2.5, y=-1.25, z=3.0)
  assert_vec3_close(camera.pixel_to_frame(camera.frame_to_pixel(frame)), frame)
}

///|
test "fixed camera spaces match Manim semantics" {
  let camera = Camera::new(projection=Perspective, focal_distance=10.0)
  let center = @object.Vec3::new(x=1.0, y=0.0, z=5.0)
  let point = @object.Vec3::new(x=2.0, y=1.0, z=5.0)
  assert_vec3_close(
    camera.transform_point(point, FixedOrientation(center)),
    @object.Vec3::new(x=3.0, y=1.0, z=5.0),
  )
  assert_vec3_close(camera.transform_point(point, FixedInFrame), point)
}

///|
test "camera target and orbit resolve against current state" {
  let camera = Camera::default()
  let moved = CameraTarget::new(
    phi=1.0,
    zoom=2.0,
    frame_center=@object.Vec3::new(x=3.0, y=4.0),
  ).resolve(camera)
  assert_close(moved.phi, 1.0)
  assert_close(moved.theta, camera.theta)
  assert_close(moved.zoom, 2.0)
  let orbited = CameraOrbit::new(theta_delta=0.5, gamma_delta=-0.25).resolve(
    moved,
  )
  assert_close(orbited.theta, moved.theta + 0.5)
  assert_close(orbited.gamma, moved.gamma - 0.25)
}

///|
test "camera interpolation covers continuous state and switches discrete state at end" {
  let start = Camera::new(
    pixel_width=640,
    pixel_height=360,
    frame_width=8.0,
    background=@object.Rgba::black(),
    projection=Orthographic,
    light_source=@object.Vec3::zero(),
  )
  let target = Camera::new(
    pixel_width=1280,
    pixel_height=720,
    frame_width=12.0,
    background=@object.Rgba::white(),
    projection=Perspective,
    light_source=@object.Vec3::new(x=2.0, y=4.0, z=6.0),
  )
  let midpoint = start.interpolate(target, 0.5)
  assert_eq(midpoint.pixel_width, 640)
  assert_close(midpoint.frame_width, 10.0)
  assert_close(midpoint.background.r, 0.5)
  assert_vec3_close(
    midpoint.light_source,
    @object.Vec3::new(x=1.0, y=2.0, z=3.0),
  )
  assert_true(midpoint.projection == Orthographic)
  let finish = start.interpolate(target, 1.0)
  assert_eq(finish.pixel_width, 1280)
  assert_true(finish.projection == Perspective)
}

///|
test "camera projects bounds and checks frame overlap" {
  let camera = Camera::new(frame_width=4.0, frame_height=4.0)
  let visible = @object.Aabb::new(
    min=@object.Vec3::new(x=-1.0, y=-1.0),
    max=@object.Vec3::new(x=1.0, y=1.0),
  )
  let hidden = @object.Aabb::new(
    min=@object.Vec3::new(x=3.0, y=3.0),
    max=@object.Vec3::new(x=4.0, y=4.0),
  )
  assert_true(camera.is_in_frame(visible))
  assert_true(!camera.is_in_frame(hidden))
}

///|
test "camera shading follows Manim cubic light response" {
  let camera = Camera::default().with_light_source(
    @object.Vec3::new(x=0.0, y=0.0, z=10.0),
  )
  let color = @object.Rgba::rgb(r=0.2, g=0.3, b=0.4)
  let lit = camera.shade(
    color,
    point=@object.Vec3::zero(),
    normal=@object.Vec3::unit_z(),
  )
  assert_close(lit.r, 0.7)
  assert_close(lit.g, 0.8)
  assert_close(lit.b, 0.9)
  assert_close(lit.a, 1.0)
}

///|
test "camera validation returns typed errors" {
  try Camera::new(zoom=0.0).validate() catch {
    error => assert_true(error is InvalidZoom(0.0))
  } noraise {
    _ => fail("invalid zoom should raise CameraError")
  }
  try Camera::new(phi=(-1.0).sqrt()).validate() catch {
    error => assert_true(error is InvalidOrientation(..))
  } noraise {
    _ => fail("invalid orientation should raise CameraError")
  }
}
