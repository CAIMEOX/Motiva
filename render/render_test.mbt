///|
fn has_nonzero_byte(bytes : Bytes) -> Bool {
  for index in 0..<bytes.length() {
    if bytes[index].to_int() != 0 {
      return true
    }
  }
  false
}

///|
test "snapshot separates foreground from main draw items" {
  let scene = @scene.Scene::new()
  let square = scene.add(@object.Square::new())
  let circle = scene.add_foreground(@object.Circle::new())
  let snapshot = FrameSnapshot::from_scene(scene)
  assert_eq(snapshot.items.length(), 2)
  guard snapshot.items.get(0) is Some(main) else {
    fail("snapshot should contain main item")
  }
  guard snapshot.items.get(1) is Some(foreground) else {
    fail("snapshot should contain foreground item")
  }
  assert_true(main.id == square)
  assert_true(main.layer == Main)
  assert_true(foreground.id == circle)
  assert_true(foreground.layer == Foreground)
}

///|
test "cairo renderer renders visible path objects into argb32 bytes" {
  let scene = @scene.Scene::new()
  let style = @object.ShapeStyle::filled(color=@object.Rgba::white())
  ignore(scene.add(@object.Square::new(side_length=2.0, style~)))
  let renderer = CairoRenderer::new(
    camera=Camera::new(
      pixel_width=64,
      pixel_height=64,
      frame_width=4.0,
      frame_height=4.0,
      background=@object.Rgba::black(),
    ),
  )
  let frame = renderer.render_scene(scene)
  assert_eq(frame.width, 64)
  assert_eq(frame.height, 64)
  assert_eq(frame.byte_length(), 64 * 64 * 4)
  assert_true(has_nonzero_byte(frame.data))
}
