///|
fn solid_face(color : @object.Rgba, depth : Double) -> @object.Object {
  @object.Object::mesh(
    @object.Mesh3D::polygon([
      @object.Vec3::new(x=-1.0, y=-1.0, z=depth),
      @object.Vec3::new(x=1.0, y=-1.0, z=depth),
      @object.Vec3::new(x=1.0, y=1.0, z=depth),
      @object.Vec3::new(x=-1.0, y=1.0, z=depth),
    ]),
    style=@object.ShapeStyle::new(
      fill=color,
      fill_opacity=1.0,
      stroke_width=0.0,
    ),
  )
}

///|
test "perspective surface clipping removes geometry beyond the focal plane" {
  let camera = @camera.Camera::new(projection=Perspective, focal_distance=10.0)
  let hidden = lower_surface_face(
    camera,
    [
      @object.Vec3::new(x=-1.0, y=-1.0, z=11.0),
      @object.Vec3::new(x=1.0, y=-1.0, z=11.0),
      @object.Vec3::new(x=0.0, y=1.0, z=11.0),
    ],
    @object.ShapeStyle::surface(),
    World,
    Main,
    0.0,
  )
  assert_true(hidden is None)
  let crossing = lower_surface_face(
    camera,
    [
      @object.Vec3::new(x=-1.0, y=-1.0, z=9.0),
      @object.Vec3::new(x=1.0, y=-1.0, z=11.0),
      @object.Vec3::new(x=0.0, y=1.0, z=9.0),
    ],
    @object.ShapeStyle::surface(),
    World,
    Main,
    0.0,
  )
  guard crossing is Some(face) else {
    fail("a crossing face should be clipped rather than discarded")
  }
  assert_true(face.projected.length() >= 3)
}

///|
test "cairo painter order draws nearer mesh faces over later far faces" {
  let camera = @camera.Camera::new(
    pixel_width=32,
    pixel_height=32,
    frame_width=4.0,
    frame_height=4.0,
    projection=Orthographic,
  ).with_shading(false)
  let scene = @scene.Scene::new(camera~)
  ignore(scene.add(solid_face(@object.Rgba::red(), 1.0)))
  ignore(scene.add(solid_face(@object.Rgba::blue(), -1.0)))
  let frame = CairoRenderer::new().render_scene(scene)
  let center = (16 * frame.width + 16) * 4
  assert_eq(frame.data[center].to_int(), 0)
  assert_eq(frame.data[center + 1].to_int(), 0)
  assert_eq(frame.data[center + 2].to_int(), 255)
  assert_eq(frame.data[center + 3].to_int(), 255)
}

///|
test "snapshot includes mesh leaves without changing flat path semantics" {
  let scene = @scene.Scene::new()
  let cube = scene.add(@object.Cube::new())
  let square = scene.add(@object.Square::new())
  let snapshot = FrameSnapshot::from_scene(scene)
  assert_eq(snapshot.items.length(), 7)
  assert_true(snapshot.items.any(item => item.id == square))
  assert_true(
    snapshot.items.any(item => item.id != cube && item.object.node is Mesh(_, _)),
  )
}
