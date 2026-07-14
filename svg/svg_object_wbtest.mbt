///|
fn assert_family_path(
  actual : @object.FamilyPath,
  expected : Array[Int],
) -> Unit raise {
  assert_eq(actual.indices(), expected)
}

///|
fn assert_svg_object_color(
  actual : @object.Rgba,
  expected : @object.Rgba,
) -> Unit raise {
  assert_close(actual.r, expected.r)
  assert_close(actual.g, expected.g)
  assert_close(actual.b, expected.b)
  assert_close(actual.a, expected.a)
}

///|
fn assert_svg_object_style(
  actual : @object.ShapeStyle,
  expected : @object.ShapeStyle,
) -> Unit raise {
  match (actual.fill, expected.fill) {
    (None, None) => ()
    (Some(actual), Some(expected)) => assert_svg_object_color(actual, expected)
    _ => fail("fill paints should match")
  }
  match (actual.stroke, expected.stroke) {
    (None, None) => ()
    (Some(actual), Some(expected)) => assert_svg_object_color(actual, expected)
    _ => fail("stroke paints should match")
  }
  assert_close(actual.fill_opacity, expected.fill_opacity)
  assert_close(actual.stroke_opacity, expected.stroke_opacity)
  assert_close(actual.stroke_width, expected.stroke_width)
}

///|
test "SvgObject indexes nested SVG ids by stable family paths" {
  let source =
    #|<svg id="root">
    #|  <g id="layer">
    #|    <rect id="box" x="0" y="0" width="2" height="1"/>
    #|  </g>
    #|</svg>
  let svg = SvgObject::parse_string(source, center=false)
  guard svg.group_paths("root") is [root] else {
    fail("root id should identify the imported object")
  }
  guard svg.group_paths("layer") is [layer] else {
    fail("group id should identify the nested group")
  }
  guard svg.group_paths("box") is [box] else {
    fail("shape id should identify the nested path")
  }
  assert_family_path(root, [])
  assert_family_path(layer, [0])
  assert_family_path(box, [0, 0])
  assert_eq(svg.group_paths("missing").length(), 0)
}

///|
test "SvgObject retains every instantiated path for ids referenced by use" {
  let source =
    #|<svg>
    #|  <defs>
    #|    <g id="glyph"><path id="outline" d="M0 0 L1 0"/></g>
    #|  </defs>
    #|  <use id="first" href="#glyph" x="1"/>
    #|  <use id="second" href="#glyph" x="3"/>
    #|</svg>
  let svg = SvgObject::parse_string(source, center=false)
  guard svg.group_paths("glyph") is [first_glyph, second_glyph] else {
    fail("the referenced group should identify both rendered instances")
  }
  guard svg.group_paths("outline") is [first_outline, second_outline] else {
    fail("the referenced shape should identify both rendered instances")
  }
  guard svg.group_paths("first") is [first_use] else {
    fail("the first use should retain its own id")
  }
  guard svg.group_paths("second") is [second_use] else {
    fail("the second use should retain its own id")
  }
  assert_family_path(first_glyph, [0])
  assert_family_path(second_glyph, [1])
  assert_family_path(first_outline, [0, 0])
  assert_family_path(second_outline, [1, 0])
  assert_family_path(first_use, [0])
  assert_family_path(second_use, [1])
}

///|
test "SvgObject indexes each rendered symbol instance" {
  let source =
    #|<svg>
    #|  <defs>
    #|    <symbol id="tile" viewBox="0 0 1 1">
    #|      <rect id="tile-shape" width="1" height="1"/>
    #|    </symbol>
    #|  </defs>
    #|  <use href="#tile" x="1" width="2" height="2"/>
    #|  <use href="#tile" x="4" width="3" height="3"/>
    #|</svg>
  let svg = SvgObject::parse_string(source, center=false)
  guard svg.group_paths("tile") is [first_tile, second_tile] else {
    fail("symbol id should identify both rendered instances")
  }
  guard svg.group_paths("tile-shape") is [first_shape, second_shape] else {
    fail("symbol descendants should identify both rendered instances")
  }
  assert_family_path(first_tile, [0])
  assert_family_path(second_tile, [1])
  assert_family_path(first_shape, [0, 0])
  assert_family_path(second_shape, [1, 0])
}

///|
test "SvgObject copy preserves an independent id index" {
  let source =
    #|<svg><g id="part"><circle cx="0" cy="0" r="1"/></g></svg>
  let original = SvgObject::parse_string(source, center=false)
  let copied = original.copy()
  guard copied.group_paths("part") is [copied_path] else {
    fail("copied SVG should retain group metadata")
  }
  assert_family_path(copied_path, [0])
  let returned = copied.group_paths("part")
  returned.clear()
  assert_eq(copied.group_paths("part").length(), 1)
}

///|
test "unsupported rendered SVG elements are skipped and reported" {
  let source =
    #|<svg>
    #|  <image href="photo.png" width="10" height="10"/>
    #|  <foreignObject width="10" height="10"/>
    #|  <rect x="1" y="2" width="3" height="4"/>
    #|</svg>
  let svg = SvgObject::parse_string(source, center=false)
  match svg.diagnostics() {
    [SkippedElement("image"), SkippedElement("foreignObject")] => ()
    _ => fail("unsupported elements should be reported in document order")
  }
  guard svg.object().node is @object.Group([child]) else {
    fail("supported siblings should still be imported")
  }
  assert_true(child.node is @object.Path(_, _))
}

///|
test "SVG default style is inherited and authored style takes precedence" {
  let defaults = @object.ShapeStyle::new(
    fill=@object.Rgba::red(),
    fill_opacity=0.75,
    stroke=@object.Rgba::blue(),
    stroke_width=3.0,
  )
  let source =
    #|<svg><rect width="1" height="1" fill="yellow"/></svg>
  let svg = SvgObject::parse_string(
    source,
    center=false,
    default_style=defaults,
  )
  guard svg.object().node is @object.Group([child]) else {
    fail("rect should lower to one styled path")
  }
  guard child.node is @object.Path(_, style) else {
    fail("rect should lower to one styled path")
  }
  guard (style.fill, style.stroke) is (Some(fill), Some(stroke)) else {
    fail("default and authored paints should both be present")
  }
  assert_svg_object_color(fill, @object.Rgba::yellow())
  assert_svg_object_color(stroke, @object.Rgba::blue())
  assert_close(style.fill_opacity, 0.75)
  assert_close(style.stroke_width, 3.0)
}

///|
test "SVG override style replaces every imported path style" {
  let style_override = @object.ShapeStyle::new(
    fill=@object.Rgba::cyan(),
    fill_opacity=0.5,
    stroke=@object.Rgba::magenta(),
    stroke_opacity=0.25,
    stroke_width=7.0,
  )
  let source =
    #|<svg><g><circle r="1" fill="red"/><rect width="1" height="1" stroke="blue"/></g></svg>
  let svg = SvgObject::parse_string(
    source,
    center=false,
    override_style=style_override,
  )
  guard svg.object().node is @object.Group([group]) else {
    fail("SVG group hierarchy should be retained")
  }
  guard group.node is @object.Group(children) else {
    fail("SVG group hierarchy should be retained")
  }
  for child in children {
    guard child.node is @object.Path(_, style) else {
      fail("both imported shapes should be paths")
    }
    assert_svg_object_style(style, style_override)
  }
}
