///|
fn assert_style_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_rgba_close(actual : Rgba, expected : Rgba) -> Unit raise {
  assert_style_close(actual.r, expected.r)
  assert_style_close(actual.g, expected.g)
  assert_style_close(actual.b, expected.b)
  assert_style_close(actual.a, expected.a)
}

///|
test "shape style default follows manim vmobject stroke defaults" {
  let style = ShapeStyle::default()
  guard style.stroke is Some(stroke) else {
    fail("default shape style should have a stroke color")
  }
  assert_style_close(stroke.r, 1.0)
  assert_style_close(stroke.g, 1.0)
  assert_style_close(stroke.b, 1.0)
  assert_style_close(style.stroke_opacity, 1.0)
  assert_style_close(style.stroke_width, 4.0)
  assert_true(style.fill is None)
  assert_style_close(style.fill_opacity, 0.0)
}

///|
test "shape style setters update specified paint fields" {
  let fill = Rgba::rgb(r=0.2, g=0.6, b=1.0)
  let stroke = Rgba::rgb(r=0.1, g=0.9, b=0.4)
  let styled = ShapeStyle::default()
    .set_fill(color=fill, opacity=0.25)
    .set_stroke(color=stroke, width=2.0, opacity=0.5)
  guard styled.fill is Some(actual_fill) else {
    fail("set_fill should set the fill color")
  }
  guard styled.stroke is Some(actual_stroke) else {
    fail("set_stroke should set the stroke color")
  }
  assert_rgba_close(actual_fill, fill)
  assert_style_close(styled.fill_opacity, 0.25)
  assert_rgba_close(actual_stroke, stroke)
  assert_style_close(styled.stroke_width, 2.0)
  assert_style_close(styled.stroke_opacity, 0.5)

  let color = Rgba::red()
  let recolored = styled.set_color(color)
  guard recolored.fill is Some(recolored_fill) else {
    fail("set_color should keep the fill color present")
  }
  guard recolored.stroke is Some(recolored_stroke) else {
    fail("set_color should keep the stroke color present")
  }
  assert_rgba_close(recolored_fill, color)
  assert_rgba_close(recolored_stroke, color)
  assert_style_close(recolored.fill_opacity, 0.25)
  assert_style_close(recolored.stroke_opacity, 0.5)
  assert_style_close(recolored.stroke_width, 2.0)
}

///|
test "object style setters recurse through groups" {
  let fill = Rgba::rgb(r=0.0, g=0.4, b=1.0)
  let stroke = Rgba::rgb(r=0.9, g=0.9, b=0.1)
  let group = Object::group(
      [into_object(Square::new()), into_object(Circle::new())],
      id="group",
    )
    .set_fill(color=fill, opacity=0.35)
    .set_stroke(color=stroke, width=3.0, opacity=0.8)
  assert_eq(group.id, "group")
  guard group.node is Group(children) else {
    fail("styled group should stay a group")
  }
  assert_eq(children.length(), 2)
  for child in children {
    guard child.node is Path(_, style) else {
      fail("group children should stay path objects")
    }
    guard style.fill is Some(actual_fill) else {
      fail("object set_fill should set child fill colors")
    }
    guard style.stroke is Some(actual_stroke) else {
      fail("object set_stroke should set child stroke colors")
    }
    assert_rgba_close(actual_fill, fill)
    assert_style_close(style.fill_opacity, 0.35)
    assert_rgba_close(actual_stroke, stroke)
    assert_style_close(style.stroke_width, 3.0)
    assert_style_close(style.stroke_opacity, 0.8)
  }
}

///|
test "object set_color recolors grouped path styles" {
  let color = Rgba::rgb(r=0.8, g=0.2, b=0.7)
  let group = Object::group([
    into_object(Square::new()),
    into_object(Circle::new()),
  ]).set_color(color)
  guard group.node is Group(children) else {
    fail("styled object should stay a group")
  }
  for child in children {
    guard child.node is Path(_, style) else {
      fail("group children should stay path objects")
    }
    guard style.fill is Some(fill) else {
      fail("set_color should set child fill colors")
    }
    guard style.stroke is Some(stroke) else {
      fail("set_color should set child stroke colors")
    }
    assert_rgba_close(fill, color)
    assert_rgba_close(stroke, color)
  }
}

///|
test "dot default style is filled without visible stroke" {
  let object = into_object(Dot::new())
  guard object.node is Path(_, style) else {
    fail("dot should lower to a path object")
  }
  guard style.fill is Some(fill) else {
    fail("dot default style should set fill")
  }
  assert_rgba_close(fill, Rgba::white())
  assert_style_close(style.fill_opacity, 1.0)
  assert_style_close(style.stroke_width, 0.0)
}

///|
test "dot implements default with dot-specific style" {
  let dot = Dot::default()
  assert_style_close(dot.radius, 0.08)
  assert_eq(dot.segments, 8)
  assert_style_close(dot.point.x, 0.0)
  assert_style_close(dot.point.y, 0.0)
  assert_style_close(dot.point.z, 0.0)
  guard dot.style.fill is Some(fill) else {
    fail("Dot::default should set fill")
  }
  assert_rgba_close(fill, Rgba::white())
  assert_style_close(dot.style.fill_opacity, 1.0)
  assert_style_close(dot.style.stroke_width, 0.0)
}
