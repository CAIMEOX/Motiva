///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_bounds(
  object : @object.Object,
  min_x~ : Double,
  min_y~ : Double,
  max_x~ : Double,
  max_y~ : Double,
) -> Unit raise {
  guard object.bounds() is Some(bounds) else {
    fail("object should have bounds")
  }
  assert_close(bounds.min.x, min_x)
  assert_close(bounds.min.y, min_y)
  assert_close(bounds.max.x, max_x)
  assert_close(bounds.max.y, max_y)
}

///|
fn assert_paint_close(
  actual : @object.Rgba?,
  expected : @object.Rgba,
) -> Unit raise {
  guard actual is Some(color) else { fail("paint should be present") }
  assert_close(color.r, expected.r)
  assert_close(color.g, expected.g)
  assert_close(color.b, expected.b)
  assert_close(color.a, expected.a)
}

///|
fn parse_result(source : String) -> Result[@object.Object, SvgError] {
  try parse_string(source, center=false) catch {
    error => Err(error)
  } noraise {
    object => Ok(object)
  }
}

///|
fn path_result(data : String) -> Result[@object.Path3D, SvgError] {
  try parse_path_data(data) catch {
    error => Err(error)
  } noraise {
    path => Ok(path)
  }
}

///|
test "rect lowers to a styled path and root y flip" {
  let source =
    #|<svg><rect id="box" x="1" y="2" width="3" height="4" fill="#f00" stroke="#00ff00" stroke-width="2"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group(children) else {
    fail("svg root should lower to a group")
  }
  assert_eq(children.length(), 1)
  guard children[0].node is @object.Path(path, style) else {
    fail("rect should lower to a path")
  }
  assert_eq(path.commands.length(), 5)
  guard style.fill is Some(fill) else { fail("rect fill should be parsed") }
  assert_close(fill.r, 1.0)
  assert_close(fill.g, 0.0)
  assert_close(fill.b, 0.0)
  guard style.stroke is Some(stroke) else {
    fail("rect stroke should be parsed")
  }
  assert_close(stroke.r, 0.0)
  assert_close(stroke.g, 1.0)
  assert_close(stroke.b, 0.0)
  assert_close(style.stroke_width, 2.0)
  assert_bounds(object, min_x=1.0, min_y=-6.0, max_x=4.0, max_y=-2.0)
}

///|
test "paint parser uses object named colors" {
  assert_true(parse_paint("none") is None)
  assert_paint_close(parse_paint("transparent"), @object.Rgba::transparent())
  assert_paint_close(parse_paint("green"), @object.Rgba::green())
  assert_paint_close(parse_paint("blue"), @object.Rgba::blue())
  assert_paint_close(parse_paint("yellow"), @object.Rgba::yellow())
  assert_paint_close(parse_paint("cyan"), @object.Rgba::cyan())
  assert_paint_close(parse_paint("magenta"), @object.Rgba::magenta())
}

///|
test "path data supports line cubic quadratic shorthand and close" {
  let path = parse_path_data(
    "M 0 0 L 1 0 h 2 v 3 C 3 4 4 4 4 3 S 5 2 6 3 Q 7 4 8 3 T 10 3 z",
  )
  assert_eq(path.commands.length(), 9)
  guard path.commands[0] is @object.MoveTo(first) else {
    fail("first command should be move")
  }
  assert_close(first.x, 0.0)
  assert_close(first.y, 0.0)
  guard path.commands[path.commands.length() - 1] is @object.Close else {
    fail("last command should close")
  }
}

///|
test "path arc command lowers to cubic segments" {
  let path = parse_path_data("M 100 100 A 45 45 0 0 0 145 145")
  assert_eq(path.commands.length(), 4)
  guard path.commands[3] is @object.CubicTo(_, _, anchor) else {
    fail("arc should lower to cubic commands")
  }
  assert_close(anchor.x, 145.0)
  assert_close(anchor.y, 145.0)
}

///|
test "relative path arc command updates from current point" {
  let path = parse_path_data("M 0 0 a 10 10 0 0 1 10 10")
  guard path.commands[path.commands.length() - 1]
    is @object.CubicTo(_, _, anchor) else {
    fail("relative arc should lower to cubic commands")
  }
  assert_close(anchor.x, 10.0)
  assert_close(anchor.y, 10.0)
}

///|
test "path arc flags must be 0 or 1" {
  let result = path_result("M 0 0 A 10 10 0 2 1 10 10")
  guard result is Err(InvalidPathData(_)) else {
    fail("invalid arc flag should be a typed path error")
  }
}

///|
test "mdn rotated arc svg parses" {
  let source =
    #|<svg width="320" height="320" xmlns="http://www.w3.org/2000/svg">
    #|  <path
    #|    d="M 10 315
    #|       L 110 215
    #|       A 30 50 0 0 1 162.55 162.45
    #|       L 172.55 152.45
    #|       A 30 50 -45 0 1 215.1 109.9
    #|       L 315 10"
    #|    stroke="black"
    #|    fill="green"
    #|    stroke-width="2"
    #|    fill-opacity="0.5" />
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group(children) else {
    fail("svg root should lower to a group")
  }
  guard children[0].node is @object.Path(path, _) else {
    fail("mdn arc path should lower to a path")
  }
  assert_true(path.commands.length() > 8)
}

///|
test "circle ellipse polygon polyline and style inheritance parse" {
  let source =
    #|<svg>
    #|  <g style="stroke:white;stroke-width:3;fill:none">
    #|    <circle cx="0" cy="0" r="1"/>
    #|    <ellipse cx="3" cy="0" rx="2" ry="1"/>
    #|    <polygon points="0,0 1,0 1,1"/>
    #|    <polyline points="2,2 3,2 3,3"/>
    #|  </g>
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group(root_children) else {
    fail("svg root should lower to a group")
  }
  guard root_children[0].node is @object.Group(children) else {
    fail("g should lower to a nested group")
  }
  assert_eq(children.length(), 4)
  guard children[0].node is @object.Path(_, circle_style) else {
    fail("circle should be a path")
  }
  assert_true(circle_style.fill is None)
  guard circle_style.stroke is Some(stroke) else {
    fail("inherited stroke should exist")
  }
  assert_close(stroke.r, 1.0)
  assert_close(circle_style.stroke_width, 3.0)
  assert_bounds(object, min_x=-1.0, min_y=-3.0, max_x=5.0, max_y=1.0)
}

///|
test "transform list composes before root y flip" {
  let source =
    #|<svg><g transform="translate(2,3)"><line x1="0" y1="0" x2="1" y2="0"/></g></svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=2.0, min_y=-3.0, max_x=3.0, max_y=-3.0)
}

///|
test "missing required attributes report typed svg error" {
  let result = parse_result("<svg><rect/></svg>")
  guard result is Err(MissingAttribute(attribute="width", ..)) else {
    fail("missing rect width should be typed")
  }
}
