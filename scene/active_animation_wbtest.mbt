///|
fn patch_put_object(patch : FramePatch, id : ObjectId) -> @object.Object? {
  let mut result : @object.Object? = None
  for op in patch.ops {
    match (result, op) {
      (Some(_), _) => ()
      (None, Put(current, object)) => if current == id { result = Some(object) }
      _ => ()
    }
  }
  result
}

///|
fn path_style(object : @object.Object) -> @object.ShapeStyle raise {
  match object.node {
    Path(_, style) => style
    _ => fail("expected path object")
  }
}

///|
test "active animation compile captures object op target without mutating scene" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let animation = square
    .animate(run_time=2.0)
    .shift(@object.Vec3::new(x=4.0, y=0.0))
    .to_animation()
  let active = ActiveAnimation::compile(scene, animation)
  assert_close(active.run_time(), 2.0)
  guard active.affected_ids().get(0) is Some(id) else {
    fail("active animation should report affected id")
  }
  assert_true(id == square)
  guard scene.get(square) is Some(start) else {
    fail("source object should still exist")
  }
  assert_close(start.transform.m03, 0.0)
  let patch = active.sample(0.5)
  guard patch_put_object(patch, square) is Some(sampled) else {
    fail("sample should put interpolated object")
  }
  assert_close(sampled.transform.m03, 2.0)
}

///|
test "active animation finish patch for fade out hides object" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  let active = ActiveAnimation::compile(scene, Animation::fade_out(square))
  assert_true(active.lifecycle.remover)
  scene.apply_frame_patch(active.finish_patch())
  assert_true(!scene.is_visible(square))
  guard scene.state(square) is Some(Removed) else {
    fail("fade out finish patch should remove visible object")
  }
}

///|
test "fade in starts transparent and shifted before restoring source object" {
  let scene = Scene::new()
  let style = @object.ShapeStyle::new(
    fill=@object.Rgba::red(),
    fill_opacity=1.0,
    stroke=@object.Rgba::white(),
    stroke_opacity=1.0,
    stroke_width=4.0,
  )
  let object = @object.into_object(@object.Square::new(side_length=2.0, style~)).with_transform(
    @object.Transform::translate(@object.Vec3::new(x=2.0, y=1.0)),
  )
  let square = scene.object(object)
  let active = ActiveAnimation::compile(
    scene,
    Animation::fade_in(
      square,
      shift=@object.Vec3::new(x=0.0, y=-2.0),
      scale=0.5,
      run_time=2.0,
    ),
  )
  assert_true(active.lifecycle.introducer)
  guard patch_put_object(active.begin_patch(), square) is Some(begin) else {
    fail("fade in begin should put a starting object")
  }
  let begin_style = path_style(begin)
  assert_close(begin_style.fill_opacity, 0.0)
  assert_close(begin_style.stroke_opacity, 0.0)
  let begin_center = begin.center()
  assert_close(begin_center.x, 2.0)
  assert_close(begin_center.y, 3.0)
  guard begin.bounds() is Some(begin_bounds) else {
    fail("fade in begin should have bounds")
  }
  assert_close(begin_bounds.width(), 1.0)
  assert_close(begin_bounds.height(), 1.0)
  guard patch_put_object(active.sample(0.5), square) is Some(mid) else {
    fail("fade in sample should put an interpolated object")
  }
  let mid_style = path_style(mid)
  assert_close(mid_style.fill_opacity, 0.5)
  assert_close(mid_style.stroke_opacity, 0.5)
  guard patch_put_object(active.finish_patch(), square) is Some(finish) else {
    fail("fade in finish should put the source object")
  }
  let finish_style = path_style(finish)
  assert_close(finish_style.fill_opacity, 1.0)
  assert_close(finish_style.stroke_opacity, 1.0)
  let finish_center = finish.center()
  assert_close(finish_center.x, 2.0)
  assert_close(finish_center.y, 1.0)
}

///|
test "fade out interpolates to transparent shifted target then hides object" {
  let scene = Scene::new()
  let style = @object.ShapeStyle::new(
    fill=@object.Rgba::red(),
    fill_opacity=0.8,
    stroke=@object.Rgba::white(),
    stroke_opacity=0.6,
    stroke_width=4.0,
  )
  let square = scene.add(@object.Square::new(side_length=2.0, style~))
  let active = ActiveAnimation::compile(
    scene,
    Animation::fade_out(
      square,
      shift=@object.Vec3::new(x=2.0, y=0.0),
      scale=1.5,
      run_time=2.0,
    ),
  )
  assert_true(active.lifecycle.remover)
  guard patch_put_object(active.sample(0.5), square) is Some(mid) else {
    fail("fade out sample should put an interpolated object")
  }
  let mid_style = path_style(mid)
  assert_close(mid_style.fill_opacity, 0.4)
  assert_close(mid_style.stroke_opacity, 0.3)
  guard patch_put_object(active.finish_patch(), square) is Some(finish) else {
    fail("fade out finish should put the transparent target before hiding")
  }
  let finish_style = path_style(finish)
  assert_close(finish_style.fill_opacity, 0.0)
  assert_close(finish_style.stroke_opacity, 0.0)
  let finish_center = finish.center()
  assert_close(finish_center.x, 2.0)
  assert_close(finish_center.y, 0.0)
  guard finish.bounds() is Some(finish_bounds) else {
    fail("fade out finish should have bounds")
  }
  assert_close(finish_bounds.width(), 3.0)
  assert_close(finish_bounds.height(), 3.0)
  scene.apply_frame_patch(active.finish_patch())
  assert_true(!scene.is_visible(square))
}

///|
test "active transform finish preserves visible draw order" {
  let scene = Scene::new()
  let square = scene.add(@object.Square::new())
  ignore(scene.add(@object.Circle::new()))
  let active = ActiveAnimation::compile(
    scene,
    Animation::transform(square, @object.Circle::new(radius=2.0)),
  )
  scene.apply_frame_patch(active.finish_patch())
  assert_order(scene.visible_objects(), [0, 1])
}

///|
test "active transform begin makes allocated source visible" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let active = ActiveAnimation::compile(
    scene,
    Animation::transform(square, @object.Circle::new(radius=2.0)),
  )
  scene.apply_frame_patch(active.begin_patch())
  assert_true(scene.is_visible(square))
  assert_order(scene.visible_objects(), [0])
}

///|
test "active transform morphs incompatible path commands through point buffer" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new(side_length=4.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::transform(square, @object.Circle::new(radius=2.0, segments=8)),
  )
  guard patch_put_object(active.sample(0.5), square) is Some(sampled) else {
    fail("sample should put morphed object")
  }
  guard sampled.node is Path(path, _) else {
    fail("morphed object should remain a path")
  }
  assert_eq(path.commands.length(), 10)
  let buffer = path.eval()
  assert_eq(buffer.curve_count(), 8)
}

///|
test "active rotate samples circular motion instead of matrix lerp" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new(side_length=2.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::rotate(square, angle=@math.PI, run_time=2.0),
  )
  guard active.affected_ids().get(0) is Some(id) else {
    fail("rotate animation should report affected id")
  }
  assert_true(id == square)
  guard patch_put_object(active.sample(0.5), square) is Some(sampled) else {
    fail("rotate sample should put a sampled object")
  }
  let point = sampled.transform.apply_point(@object.Vec3::new(x=1.0, y=0.0))
  assert_close(point.x, 0.0)
  assert_close(point.y, 1.0)
}

///|
test "active rotate can resolve about edge from object bounds" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new(side_length=2.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::rotate(
      square,
      angle=@math.PI / 2.0,
      about_edge=@object.Vec3::new(x=1.0, y=0.0),
    ),
  )
  guard patch_put_object(active.sample(1.0), square) is Some(sampled) else {
    fail("rotate sample should put a sampled object")
  }
  let pivot = sampled.transform.apply_point(@object.Vec3::new(x=1.0, y=0.0))
  assert_close(pivot.x, 1.0)
  assert_close(pivot.y, 0.0)
  let left = sampled.transform.apply_point(@object.Vec3::new(x=-1.0, y=0.0))
  assert_close(left.x, 1.0)
  assert_close(left.y, -2.0)
}

///|
test "active scale samples around object center" {
  let scene = Scene::new()
  let object = @object.into_object(@object.Square::new(side_length=2.0)).with_transform(
    @object.Transform::translate(@object.Vec3::new(x=3.0, y=2.0)),
  )
  let square = scene.object(object)
  let active = ActiveAnimation::compile(
    scene,
    Animation::scale(square, sx=2.0, sy=2.0, run_time=2.0),
  )
  guard active.kind is ActiveScale(id, ..) else {
    fail("scale animation should compile to ActiveScale")
  }
  assert_true(id == square)
  guard patch_put_object(active.sample_at_time(1.0), square) is Some(sampled) else {
    fail("scale sample should put a sampled object")
  }
  let center = sampled.center()
  assert_close(center.x, 3.0)
  assert_close(center.y, 2.0)
  guard sampled.bounds() is Some(bounds) else {
    fail("scale sample should have bounds")
  }
  assert_close(bounds.width(), 3.0)
  assert_close(bounds.height(), 3.0)
}

///|
test "object op scale keeps object center by default" {
  let scene = Scene::new()
  let object = @object.into_object(@object.Square::new(side_length=2.0)).with_transform(
    @object.Transform::translate(@object.Vec3::new(x=-4.0, y=1.0)),
  )
  let square = scene.object(object)
  let animation = square
    .animate(run_time=1.0)
    .scale(sx=0.5, sy=1.5)
    .to_animation()
  guard animation.kind is ApplyOps(id, _) else {
    fail("builder scale should stay a generic object operation animation")
  }
  assert_true(id == square)
  let active = ActiveAnimation::compile(scene, animation)
  guard patch_put_object(active.sample(1.0), square) is Some(sampled) else {
    fail("builder scale should put a sampled object")
  }
  let center = sampled.center()
  assert_close(center.x, -4.0)
  assert_close(center.y, 1.0)
  guard sampled.bounds() is Some(bounds) else {
    fail("builder scale sample should have bounds")
  }
  assert_close(bounds.width(), 1.0)
  assert_close(bounds.height(), 3.0)
}

///|
test "object op style mutations interpolate through animation builder" {
  let scene = Scene::new()
  let start_style = @object.ShapeStyle::new(
    fill=@object.Rgba::rgb(r=1.0, g=0.0, b=0.0),
    fill_opacity=0.2,
    stroke=@object.Rgba::rgb(r=0.0, g=0.0, b=1.0),
    stroke_opacity=0.4,
    stroke_width=2.0,
  )
  let square = scene.object(
    @object.Square::new(side_length=2.0, style=start_style),
  )
  let active = ActiveAnimation::compile(
    scene,
    square
    .animate(run_time=2.0)
    .set_fill(color=@object.Rgba::rgb(r=0.0, g=1.0, b=0.0), opacity=0.8)
    .set_stroke(
      color=@object.Rgba::rgb(r=1.0, g=1.0, b=1.0),
      width=6.0,
      opacity=1.0,
    )
    .to_animation(),
  )
  guard patch_put_object(active.sample(0.5), square) is Some(sampled) else {
    fail("style builder sample should put an interpolated object")
  }
  let style = path_style(sampled)
  guard style.fill is Some(fill) else { fail("sampled style should keep fill") }
  assert_close(fill.r, 0.5)
  assert_close(fill.g, 0.5)
  assert_close(fill.b, 0.0)
  assert_close(style.fill_opacity, 0.5)
  guard style.stroke is Some(stroke) else {
    fail("sampled style should keep stroke")
  }
  assert_close(stroke.r, 0.5)
  assert_close(stroke.g, 0.5)
  assert_close(stroke.b, 1.0)
  assert_close(style.stroke_opacity, 0.7)
  assert_close(style.stroke_width, 4.0)
}

///|
test "object op move to set color and set opacity compose as builder mutations" {
  let scene = Scene::new()
  let start_style = @object.ShapeStyle::new(
    fill=@object.Rgba::red(),
    fill_opacity=0.6,
    stroke=@object.Rgba::white(),
    stroke_opacity=0.8,
    stroke_width=3.0,
  )
  let object = @object.into_object(
    @object.Circle::new(radius=1.0, style=start_style),
  ).with_transform(
    @object.Transform::translate(@object.Vec3::new(x=-2.0, y=1.0)),
  )
  let circle = scene.object(object)
  let active = ActiveAnimation::compile(
    scene,
    circle
    .animate(run_time=1.0)
    .move_to(@object.Vec3::new(x=3.0, y=-1.0))
    .set_color(@object.Rgba::rgb(r=0.0, g=0.5, b=1.0))
    .set_opacity(0.25)
    .to_animation(),
  )
  guard patch_put_object(active.sample(1.0), circle) is Some(sampled) else {
    fail("builder mutation sample should put final object")
  }
  let center = sampled.center()
  assert_close(center.x, 3.0)
  assert_close(center.y, -1.0)
  let style = path_style(sampled)
  guard style.fill is Some(fill) else { fail("final style should keep fill") }
  assert_close(fill.r, 0.0)
  assert_close(fill.g, 0.5)
  assert_close(fill.b, 1.0)
  guard style.stroke is Some(stroke) else {
    fail("final style should keep stroke")
  }
  assert_close(stroke.r, 0.0)
  assert_close(stroke.g, 0.5)
  assert_close(stroke.b, 1.0)
  assert_close(style.fill_opacity, 0.25)
  assert_close(style.stroke_opacity, 0.25)
}

///|
test "create samples a path prefix over time" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new(side_length=4.0))
  let active = ActiveAnimation::compile(
    scene,
    Animation::create(square, run_time=2.0),
  )
  guard patch_put_object(active.begin_patch(), square) is Some(begin) else {
    fail("create begin patch should put a starting object")
  }
  guard begin.node is Path(begin_path, _) else {
    fail("create begin object should remain a path")
  }
  assert_eq(begin_path.eval().curve_count(), 0)
  guard patch_put_object(active.sample(0.5), square) is Some(mid) else {
    fail("create sample should put a partial object")
  }
  guard mid.node is Path(mid_path, _) else {
    fail("create sample object should remain a path")
  }
  let mid_buffer = mid_path.eval()
  assert_eq(mid_buffer.curve_count(), 2)
  guard mid_buffer.subpaths().get(0) is Some(mid_span) else {
    fail("mid create sample should keep one subpath")
  }
  assert_true(!mid_span.closed)
  guard patch_put_object(active.finish_patch(), square) is Some(finish) else {
    fail("create finish patch should put the final object")
  }
  guard finish.node is Path(finish_path, _) else {
    fail("create finish object should remain a path")
  }
  let finish_buffer = finish_path.eval()
  assert_eq(finish_buffer.curve_count(), 4)
  guard finish_buffer.subpaths().get(0) is Some(finish_span) else {
    fail("finish create sample should keep one subpath")
  }
  assert_true(finish_span.closed)
}

///|
test "draw border then fill draws outline before restoring fill" {
  let scene = Scene::new()
  let style = @object.ShapeStyle::new(
    fill=@object.Rgba::red(),
    fill_opacity=1.0,
    stroke_width=0.0,
  )
  let circle = scene.object(@object.Circle::new(radius=2.0, segments=8, style~))
  let active = ActiveAnimation::compile(
    scene,
    Animation::draw_border_then_fill(circle, run_time=2.0),
  )
  assert_true(active.lifecycle.introducer)
  guard patch_put_object(active.sample(0.25), circle) is Some(border) else {
    fail("first half should put a partially drawn outline object")
  }
  guard border.node is Path(border_path, border_style) else {
    fail("outline sample should remain a path")
  }
  assert_eq(border_path.eval().curve_count(), 4)
  assert_close(border_style.fill_opacity, 0.0)
  guard border_style.stroke is Some(stroke) else {
    fail("outline should fall back to fill color when no stroke is set")
  }
  assert_close(stroke.r, 1.0)
  assert_close(border_style.stroke_width, 4.0)
  guard patch_put_object(active.sample(0.75), circle) is Some(filling) else {
    fail("second half should put a full path with interpolated fill")
  }
  guard filling.node is Path(filling_path, filling_style) else {
    fail("filling sample should remain a path")
  }
  assert_eq(filling_path.eval().curve_count(), 8)
  assert_close(filling_style.fill_opacity, 0.5)
  guard patch_put_object(active.finish_patch(), circle) is Some(finish) else {
    fail("finish patch should restore the final object")
  }
  guard finish.node is Path(_, finish_style) else {
    fail("finish object should remain a path")
  }
  assert_close(finish_style.fill_opacity, 1.0)
  assert_true(finish_style.stroke is None)
}

///|
test "wait active animation has no affected ids and empty patches" {
  let scene = Scene::new()
  let active = ActiveAnimation::compile(scene, Animation::wait(1.0))
  assert_eq(active.affected_ids().length(), 0)
  assert_eq(active.begin_patch().ops.length(), 0)
  assert_eq(active.sample(0.5).ops.length(), 0)
  assert_eq(active.finish_patch().ops.length(), 0)
}

///|
test "sample_at_time clamps elapsed time to local alpha" {
  let scene = Scene::new()
  let square = scene.object(@object.Square::new())
  let active = ActiveAnimation::compile(
    scene,
    square
    .animate(run_time=2.0)
    .shift(@object.Vec3::new(x=4.0, y=0.0))
    .to_animation(),
  )
  guard patch_put_object(active.sample_at_time(8.0), square) is Some(sampled) else {
    fail("sample_at_time should put object")
  }
  assert_close(sampled.transform.m03, 4.0)
}
