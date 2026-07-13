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
fn assert_pixel_bytes_equal(actual : Bytes, expected : Bytes) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for index in 0..<actual.length() {
    if actual[index] != expected[index] {
      fail("pixel data differs at byte \{index}")
    }
  }
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
test "snapshot expands only visible leaves of an object family" {
  let scene = @scene.Scene::new()
  let root = scene.object(
    @object.Object::group([
      @object.into_object(@object.Square::new()),
      @object.into_object(@object.Circle::new()),
    ]),
  )
  guard scene.children(root) is [square, circle] else {
    fail("family should expose both child ids")
  }
  scene.show(square)
  let snapshot = FrameSnapshot::from_scene(scene)
  guard snapshot.items is [item] else {
    fail("snapshot should contain only the visible family leaf")
  }
  assert_true(item.id == square)
  assert_true(item.layer == Main)
  assert_true(!scene.is_visible(circle))
}

///|
test "foreground family child is rendered once above its siblings" {
  let scene = @scene.Scene::new()
  let root = scene.add(
    @object.Object::group([
      @object.into_object(@object.Square::new()),
      @object.into_object(@object.Circle::new()),
    ]),
  )
  guard scene.children(root) is [square, circle] else {
    fail("family should expose both child ids")
  }
  scene.show_foreground(square)
  let snapshot = FrameSnapshot::from_scene(scene)
  guard snapshot.items is [main, foreground] else {
    fail("foreground child should not remain nested in a main render item")
  }
  assert_true(main.id == circle)
  assert_true(main.layer == Main)
  assert_true(foreground.id == square)
  assert_true(foreground.layer == Foreground)
}

///|
test "snapshot sorts family leaves and top-level objects by z index" {
  let scene = @scene.Scene::new()
  let root = scene.add(
    @object.Object::group([
      @object.into_object(@object.Square::new()).with_z_index(2.0),
      @object.into_object(@object.Circle::new()).with_z_index(-2.0),
    ]),
  )
  guard scene.children(root) is [square, circle] else {
    fail("family should expose both child ids")
  }
  let dot = scene.add(@object.into_object(@object.Dot::new()).with_z_index(0.0))
  let snapshot = FrameSnapshot::from_scene(scene)
  guard snapshot.items is [back, middle, front] else {
    fail("snapshot should flatten all visible leaves")
  }
  assert_true(back.id == circle)
  assert_true(middle.id == dot)
  assert_true(front.id == square)
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
test "SVG context rendering matches PNG golden" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="4" height="2" viewBox="0 0 40 20">
    #|  <defs>
    #|    <symbol id="tile" viewBox="0 0 10 10">
    #|      <rect width="10" height="10" rx="2" fill="currentColor" />
    #|    </symbol>
    #|  </defs>
    #|  <use href="#tile" width="20" height="20" color="red" />
    #|  <use href="#tile" x="20" width="20" height="20" color="blue" />
    #|</svg>
  let scene = @scene.Scene::new()
  ignore(scene.add(@svg.SvgObject::parse_string(source, center=false)))
  let renderer = CairoRenderer::new(
    camera=Camera::new(
      pixel_width=80,
      pixel_height=40,
      frame_width=4.0,
      frame_height=2.0,
      frame_center=@object.Vec3::new(x=2.0, y=-1.0),
      background=@object.Rgba::black(),
    ),
  )
  let actual = renderer.render_scene(scene).data
  let golden = @cairoon.Surface::image_from_png(
    "render/testdata/svg_context_golden.png",
  )
  golden.flush()
  assert_pixel_bytes_equal(actual, golden.copy_data())
}

///|
async test "Manim SVG fixture rendering matches PNG golden" {
  let svg = @loader.SvgLoader::new().load(
    "svg/testdata/manim/A.svg",
    height=3.0,
  )
  let scene = @scene.Scene::new()
  ignore(scene.add(svg))
  let renderer = CairoRenderer::new(
    camera=Camera::new(
      pixel_width=160,
      pixel_height=90,
      frame_width=8.0,
      frame_height=4.5,
      background=@object.Rgba::black(),
    ),
  )
  let actual = renderer.render_scene(scene).data
  let golden = @cairoon.Surface::image_from_png(
    "render/testdata/manim_A_golden.png",
  )
  golden.flush()
  assert_pixel_bytes_equal(actual, golden.copy_data())
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
