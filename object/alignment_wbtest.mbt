///|
fn aligned_path_style(object : Object) -> ShapeStyle raise {
  match object.node {
    Path(_, style) => style
    _ => fail("expected an aligned path")
  }
}

///|
test "object alignment repeats transparent children to equalize families" {
  let source_style = ShapeStyle::new(
    fill=Rgba::red(),
    fill_opacity=1.0,
    stroke=Rgba::white(),
    stroke_width=3.0,
  )
  let target_style = ShapeStyle::new(
    fill=Rgba::manim_blue(),
    fill_opacity=1.0,
    stroke=Rgba::white(),
    stroke_width=3.0,
  )
  let source = Object::group([
    into_object(Square::new(side_length=1.0, style=source_style)),
  ])
  let target = Object::group([
    into_object(Circle::new(radius=0.4, style=target_style)),
    into_object(Circle::new(radius=0.4, style=target_style)),
    into_object(Circle::new(radius=0.4, style=target_style)),
  ]).arrange(direction=Vec3::unit_x(), buff=0.35)
  let aligned = source.align_for_interpolation(target)
  guard (aligned.start().node, aligned.target().node)
    is (Group(start_children), Group(target_children)) else {
    fail("aligned objects should remain groups")
  }
  assert_eq(start_children.length(), 3)
  assert_eq(target_children.length(), 3)
  assert_eq(aligned_path_style(start_children[0]).fill_opacity, 1.0)
  assert_eq(aligned_path_style(start_children[1]).fill_opacity, 0.0)
  assert_eq(aligned_path_style(start_children[2]).fill_opacity, 0.0)
}

///|
test "object alignment grows an empty family from transparent point objects" {
  let target = Object::group([
    into_object(
      Circle::new(radius=0.5, style=ShapeStyle::filled(color=Rgba::red())),
    ),
    into_object(
      Square::new(
        side_length=1.0,
        style=ShapeStyle::filled(color=Rgba::manim_blue()),
      ),
    ),
  ])
  let aligned = Object::group([]).align_for_interpolation(target)
  guard (aligned.start().node, aligned.target().node)
    is (Group(start_children), Group(target_children)) else {
    fail("empty and populated families should align as groups")
  }
  assert_eq(start_children.length(), 2)
  assert_eq(target_children.length(), 2)
  for child in start_children {
    let style = aligned_path_style(child)
    assert_eq(style.fill_opacity, 0.0)
    assert_eq(style.stroke_opacity, 0.0)
    guard child.bounds() is Some(bounds) else {
      fail("degenerate child should retain point bounds")
    }
    assert_eq(bounds.width(), 0.0)
    assert_eq(bounds.height(), 0.0)
  }
}

///|
test "empty objects align to transparent point geometry" {
  let target = into_object(
    Square::new(
      side_length=2.0,
      style=ShapeStyle::filled(color=Rgba::manim_blue()),
    ),
  )
  let aligned = Object::empty().align_for_interpolation(target)
  guard (aligned.start().node, aligned.target().node)
    is (Path(_, start_style), Path(_, target_style)) else {
    fail("empty and drawable objects should share path topology")
  }
  assert_eq(start_style.fill_opacity, 0.0)
  assert_eq(target_style.fill_opacity, 1.0)
  guard aligned.start().bounds() is Some(bounds) else {
    fail("point geometry should retain degenerate bounds")
  }
  assert_eq(bounds.width(), 0.0)
  assert_eq(bounds.height(), 0.0)
  let reverse = target.align_for_interpolation(Object::empty())
  guard reverse.target().node is Path(_, reverse_style) else {
    fail("drawable objects should shrink through the same path topology")
  }
  assert_eq(reverse_style.fill_opacity, 0.0)
}

///|
test "object alignment makes a missing fill transparent before interpolation" {
  let source = into_object(
    Square::new(
      side_length=2.0,
      style=ShapeStyle::new(stroke=Rgba::white(), stroke_width=3.0),
    ),
  )
  let target = into_object(
    Square::new(
      side_length=2.0,
      style=ShapeStyle::new(
        fill=Rgba::red(),
        fill_opacity=1.0,
        stroke=Rgba::white(),
        stroke_width=3.0,
      ),
    ),
  )
  let aligned = source.align_for_interpolation(target)
  let start_style = aligned_path_style(aligned.start())
  let target_style = aligned_path_style(aligned.target())
  guard (start_style.fill, target_style.fill)
    is (Some(start_fill), Some(target_fill)) else {
    fail("aligned styles should use a shared fill color")
  }
  assert_true(start_fill == Rgba::red())
  assert_true(target_fill == Rgba::red())
  assert_eq(start_style.fill_opacity, 0.0)
  assert_eq(target_style.fill_opacity, 1.0)
}

///|
test "aligned object interpolation can move points along a circular arc" {
  let source = into_object(Square::new(side_length=1.0)).with_transform(
    Transform::translate(Vec3::new(x=-2.0, y=0.0)),
  )
  let target = into_object(Square::new(side_length=1.0)).with_transform(
    Transform::translate(Vec3::new(x=2.0, y=0.0)),
  )
  let sampled = source
    .align_for_interpolation(target)
    .interpolate(0.5, path=MotionPath::arc(angle=@math.PI / 2.0))
  let center = sampled.center()
  assert_true(Double::abs(center.x) < 0.000001)
  assert_true(Double::abs(center.y + 0.8284271247461903) < 0.000001)
}

///|
test "custom motion paths can transform an aligned point buffer" {
  let source = into_object(Square::new(side_length=1.0))
  let target = into_object(Square::new(side_length=1.0)).with_transform(
    Transform::translate(Vec3::new(x=2.0, y=0.0)),
  )
  let sampled = source
    .align_for_interpolation(target)
    .interpolate(
      0.5,
      path=MotionPath::custom((start, _target, alpha) => {
        start.map(point => point.add(Vec3::new(x=0.0, y=2.0 * alpha)))
      }),
    )
  let center = sampled.center()
  assert_true(Double::abs(center.x) < 0.000001)
  assert_true(Double::abs(center.y - 1.0) < 0.000001)
}

///|
test "custom motion paths reject a changed point count with a typed error" {
  let source = into_object(Square::new(side_length=1.0))
  let target = into_object(Circle::new(radius=1.0))
  let result = try
    source
    .align_for_interpolation(target)
    .interpolate(0.5, path=MotionPath::custom((_start, _target, _alpha) => []))
  catch {
    error => Err(error)
  } noraise {
    object => Ok(object)
  }
  guard result is Err(InvalidMotionPathPointCount(expected~, actual~)) else {
    fail("custom point-count changes should return ObjectAlignmentError")
  }
  assert_true(expected > 0)
  assert_eq(actual, 0)
}
