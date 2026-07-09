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
fn assert_render_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
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
test "camera derives missing frame dimension from pixel aspect" {
  let wide = Camera::new(pixel_width=1280, pixel_height=720, frame_width=6.0)
  assert_render_close(wide.frame_width, 6.0)
  assert_render_close(wide.frame_height, 3.375)
  let tall = Camera::new(pixel_width=1280, pixel_height=720, frame_height=4.0)
  assert_render_close(tall.frame_width, 64.0 / 9.0)
  assert_render_close(tall.frame_height, 4.0)
  let square = Camera::new(pixel_width=64, pixel_height=64)
  assert_render_close(square.frame_width, 8.0)
  assert_render_close(square.frame_height, 8.0)
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

///|
test "cairo renderer renders play plan frames" {
  let scene = @scene.Scene::new(config=@scene.SceneConfig::new(frame_rate=2.0))
  let square = scene.object(@object.Square::new(side_length=2.0))
  let renderer = CairoRenderer::new(
    camera=Camera::new(
      pixel_width=64,
      pixel_height=64,
      frame_width=4.0,
      frame_height=4.0,
      background=@object.Rgba::black(),
    ),
  )
  let frames = renderer.render_play(scene, [
    square.animate(run_time=1.0).shift(@object.Vec3::new(x=1.0, y=0.0)),
  ])
  assert_eq(frames.length(), 3)
  for frame in frames {
    assert_eq(frame.width, 64)
    assert_eq(frame.height, 64)
    assert_eq(frame.byte_length(), 64 * 64 * 4)
    assert_true(has_nonzero_byte(frame.data))
  }
  guard scene.get(square) is Some(object) else {
    fail("rendered animation should leave final object in scene")
  }
  assert_render_close(object.transform.m03, 1.0)
  assert_render_close(scene.time(), 1.0)
}

///|
test "write play pngs rejects wrong path count" {
  let scene = @scene.Scene::new(config=@scene.SceneConfig::new(frame_rate=2.0))
  let square = scene.object(@object.Square::new(side_length=2.0))
  let renderer = CairoRenderer::new()
  let result = try
    renderer.write_play_pngs(
      scene,
      [@scene.Animation::create(square, run_time=1.0)],
      [],
    )
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(OutputFrameCountMismatch(expected~, actual~)) else {
    fail("wrong png path count should return typed RenderError")
  }
  assert_eq(expected, 3)
  assert_eq(actual, 0)
}
