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
fn resolved_paint(value : String) -> @object.Rgba? raise SvgError {
  parse_svg_paint(value).resolve(@object.Rgba::black())
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
test "SvgObject participates in IntoObject conversion" {
  let source =
    #|<svg><rect x="0" y="0" width="2" height="1"/></svg>
  let svg = SvgObject::parse_string(source, center=false)
  let object = @object.into_object(svg)
  assert_bounds(object, min_x=0.0, min_y=-1.0, max_x=2.0, max_y=0.0)
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
  assert_true(resolved_paint("none") is None)
  assert_paint_close(resolved_paint("transparent"), @object.Rgba::transparent())
  assert_paint_close(resolved_paint("green"), @object.Rgba::green())
  assert_paint_close(resolved_paint("blue"), @object.Rgba::blue())
  assert_paint_close(resolved_paint("yellow"), @object.Rgba::yellow())
  assert_paint_close(resolved_paint("cyan"), @object.Rgba::cyan())
  assert_paint_close(resolved_paint("magenta"), @object.Rgba::magenta())
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
test "transform list preserves SVG left-to-right matrix order" {
  let source =
    #|<svg><line x1="1" y1="1" x2="2" y2="1" transform="translate(10 20) scale(2)"/></svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=12.0, min_y=-22.0, max_x=14.0, max_y=-22.0)
}

///|
test "use instantiates a symbol with inherited style and position" {
  let source =
    #|<svg>
    #|  <defs>
    #|    <symbol id="dot"><circle cx="0" cy="0" r="1"/></symbol>
    #|  </defs>
    #|  <g fill="red"><use href="#dot" x="3" y="4"/></g>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=2.0, min_y=-5.0, max_x=4.0, max_y=-3.0)
  guard object.node is @object.Group([group]) &&
    group.node is @object.Group([instance]) &&
    instance.node is @object.Group([circle]) &&
    circle.node is @object.Path(_, style) else {
    fail("use should instantiate the referenced symbol hierarchy")
  }
  guard style.fill is Some(fill) else {
    fail("use instance should inherit fill from its parent")
  }
  assert_close(fill.r, 1.0)
  assert_close(fill.g, 0.0)
  assert_close(fill.b, 0.0)
}

///|
test "use accepts xlink href and applies transform after x and y" {
  let source =
    #|<svg xmlns:xlink="http://www.w3.org/1999/xlink">
    #|  <defs><path id="tile" d="M0 0 L1 0 L1 1 L0 1 Z"/></defs>
    #|  <use xlink:href="#tile" x="2" y="1" transform="scale(2)" fill="blue"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=4.0, min_y=-4.0, max_x=6.0, max_y=-2.0)
  guard object.node is @object.Group([path_object]) &&
    path_object.node is @object.Path(_, style) else {
    fail("use should instantiate a path")
  }
  guard style.fill is Some(fill) else { fail("use fill should be inherited") }
  assert_close(fill.r, 0.0)
  assert_close(fill.g, 0.0)
  assert_close(fill.b, 1.0)
}

///|
test "cyclic use references report a typed error" {
  let source =
    #|<svg>
    #|  <defs>
    #|    <g id="a"><use href="#b"/></g>
    #|    <g id="b"><use href="#a"/></g>
    #|  </defs>
    #|  <use href="#a"/>
    #|</svg>
  guard parse_result(source) is Err(CyclicReference("a")) else {
    fail("cyclic references should raise CyclicReference")
  }
}

///|
test "viewBox maps user coordinates into an aligned viewport" {
  let source =
    #|<svg width="200" height="200" viewBox="10 20 100 50">
    #|  <rect x="10" y="20" width="100" height="50"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=0.0, min_y=-150.0, max_x=200.0, max_y=-50.0)
}

///|
test "viewBox without dimensions uses the standalone SVG viewport" {
  let source =
    #|<svg viewBox="0 0 100 100">
    #|  <rect x="0" y="0" width="100" height="100"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=75.0, min_y=-150.0, max_x=225.0, max_y=0.0)
}

///|
test "zero-sized svg viewport does not render its descendants" {
  let source =
    #|<svg width="0" height="100" viewBox="0 0 10 10">
    #|  <rect x="0" y="0" width="10" height="10"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_true(object.bounds() is None)
}

///|
test "preserveAspectRatio none stretches each viewport axis independently" {
  let source =
    #|<svg width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="none">
    #|  <rect x="0" y="0" width="100" height="100"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=0.0, min_y=-100.0, max_x=200.0, max_y=0.0)
}

///|
test "preserveAspectRatio slice honors viewport alignment" {
  let source =
    #|<svg width="100" height="200" viewBox="0 0 100 100" preserveAspectRatio="xMaxYMid slice">
    #|  <rect x="0" y="0" width="100" height="100"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=-100.0, min_y=-200.0, max_x=100.0, max_y=0.0)
}

///|
test "nested svg establishes its own positioned viewport" {
  let source =
    #|<svg width="200" height="100">
    #|  <svg x="20" y="10" width="40" height="20" viewBox="0 0 10 10" preserveAspectRatio="none">
    #|    <rect x="0" y="0" width="10" height="10"/>
    #|  </svg>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=20.0, min_y=-30.0, max_x=60.0, max_y=-10.0)
}

///|
test "symbol viewBox is instantiated by use width and height" {
  let source =
    #|<svg width="100" height="100">
    #|  <defs>
    #|    <symbol id="tile" viewBox="0 0 10 10">
    #|      <rect x="0" y="0" width="10" height="10"/>
    #|    </symbol>
    #|  </defs>
    #|  <use href="#tile" x="20" y="5" width="40" height="20"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=30.0, min_y=-25.0, max_x=50.0, max_y=-5.0)
}

///|
test "percentage lengths resolve against the active viewport" {
  let source =
    #|<svg width="200" height="100">
    #|  <rect x="10%" y="20%" width="50%" height="50%"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=20.0, min_y=-70.0, max_x=120.0, max_y=-20.0)
}

///|
test "viewBox percentages resolve in descendant user space" {
  let source =
    #|<svg width="200" height="100" viewBox="0 0 100 100" preserveAspectRatio="none">
    #|  <rect width="50%" height="100%"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=0.0, min_y=-100.0, max_x=100.0, max_y=0.0)
}

///|
test "physical length units convert using CSS pixel ratios" {
  let source =
    #|<svg><rect x="1cm" y="0" width="1cm" height="10mm"/></svg>
  let object = parse_string(source, center=false)
  let cm = 96.0 / 2.54
  assert_bounds(object, min_x=cm, min_y=0.0 - cm, max_x=2.0 * cm, max_y=0.0)
}

///|
test "stroke width uses the SVG length interpreter" {
  let source =
    #|<svg><line x1="0" y1="0" x2="1" y2="0" stroke="black" stroke-width="1cm"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([line]) &&
    line.node is @object.Path(_, style) else {
    fail("line should lower to a styled path")
  }
  assert_close(style.stroke_width, 96.0 / 2.54)
  let invalid =
    #|<svg><line stroke="black" stroke-width="1garbage"/></svg>
  guard parse_result(invalid) is Err(InvalidLength("1garbage")) else {
    fail("malformed stroke width should raise InvalidLength")
  }
}

///|
test "svg stroke percentages use the element user viewport" {
  let source =
    #|<svg width="200" height="100" viewBox="0 0 100 100" stroke="black" stroke-width="10%">
    #|  <line x1="0" y1="0" x2="1" y2="0"/>
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([line]) &&
    line.node is @object.Path(_, style) else {
    fail("line should lower to a styled path")
  }
  assert_close(style.stroke_width, 10.0)
}

///|
test "symbol stroke percentages use the symbol user viewport" {
  let source =
    #|<svg width="200" height="100">
    #|  <defs><symbol id="mark" viewBox="0 0 10 20" stroke="black" stroke-width="10%">
    #|    <line x1="0" y1="0" x2="1" y2="0"/>
    #|  </symbol></defs>
    #|  <use href="#mark" width="100" height="100"/>
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([instance]) &&
    instance.node is @object.Group([line]) &&
    line.node is @object.Path(_, style) else {
    fail("symbol line should lower to a styled path")
  }
  assert_close(style.stroke_width, 2.5.sqrt())
}

///|
test "currentColor and rgb percentages resolve in computed style" {
  let source =
    #|<svg color="rebeccapurple">
    #|  <rect x="0" y="0" width="1" height="1" fill="currentColor" stroke="rgb(100%,50%,0%)"/>
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) else {
    fail("rect should lower to a styled path")
  }
  guard style.fill is Some(fill) else { fail("fill should be present") }
  guard style.stroke is Some(stroke) else { fail("stroke should be present") }
  assert_close(fill.r, 102.0 / 255.0)
  assert_close(fill.g, 51.0 / 255.0)
  assert_close(fill.b, 153.0 / 255.0)
  assert_close(stroke.r, 1.0)
  assert_close(stroke.g, 0.5)
  assert_close(stroke.b, 0.0)
}

///|
test "currentColor resolves after inline color wins the cascade" {
  let source =
    #|<svg><rect width="1" height="1" fill="currentColor" style="color:red"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) &&
    style.fill is Some(fill) else {
    fail("currentColor fill should be present")
  }
  assert_close(fill.r, 1.0)
  assert_close(fill.g, 0.0)
  assert_close(fill.b, 0.0)
}

///|
test "currentColor on color resolves to the inherited color" {
  let source =
    #|<svg color="blue">
    #|  <rect width="1" height="1" color="red" style="color:currentColor" fill="currentColor"/>
    #|</svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) &&
    style.fill is Some(fill) else {
    fail("currentColor fill should be present")
  }
  assert_close(fill.r, 0.0)
  assert_close(fill.g, 0.0)
  assert_close(fill.b, 1.0)
}

///|
test "rgba paint preserves its alpha channel" {
  let source =
    #|<svg><rect x="0" y="0" width="1" height="1" fill="rgba(0,128,255,0.5)"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) &&
    style.fill is Some(fill) else {
    fail("rgba fill should be present")
  }
  assert_close(fill.r, 0.0)
  assert_close(fill.g, 128.0 / 255.0)
  assert_close(fill.b, 1.0)
  assert_close(fill.a, 0.5)
}

///|
test "short hexadecimal paint preserves its alpha channel" {
  let source =
    #|<svg><rect width="1" height="1" fill="#0f08"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) &&
    style.fill is Some(fill) else {
    fail("short hexadecimal fill should be present")
  }
  assert_close(fill.r, 0.0)
  assert_close(fill.g, 1.0)
  assert_close(fill.b, 0.0)
  assert_close(fill.a, 136.0 / 255.0)
}

///|
test "rounded rect lowers its corners to cubic curves" {
  let source =
    #|<svg><rect x="0" y="0" width="10" height="4" rx="2" ry="1"/></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([rect]) &&
    rect.node is @object.Path(path, _) else {
    fail("rounded rect should lower to a path")
  }
  assert_eq(path.commands.length(), 10)
  assert_true(path.commands.any(command => command is @object.CubicTo(_, _, _)))
}

///|
test "display and visibility suppress only the affected render tree" {
  let source =
    #|<svg>
    #|  <rect x="0" y="0" width="1" height="1" display="none"/>
    #|  <rect x="10" y="0" width="1" height="1" visibility="hidden"/>
    #|  <g visibility="hidden">
    #|    <rect x="20" y="0" width="1" height="1" visibility="visible"/>
    #|  </g>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=20.0, min_y=-1.0, max_x=21.0, max_y=0.0)
}

///|
test "inline display overrides presentation and earlier declarations" {
  let source =
    #|<svg>
    #|  <rect x="0" width="1" height="1" display="none" style="display:block"/>
    #|  <rect x="2" width="1" height="1" style="display:none;display:block"/>
    #|</svg>
  let object = parse_string(source, center=false)
  assert_bounds(object, min_x=0.0, min_y=-1.0, max_x=3.0, max_y=0.0)
}

///|
test "inline opacity overrides presentation before ancestor composition" {
  let source =
    #|<svg><g opacity="0.5">
    #|  <rect width="1" height="1" opacity="0.25" style="opacity:1"/>
    #|</g></svg>
  let object = parse_string(source, center=false)
  guard object.node is @object.Group([group]) &&
    group.node is @object.Group([rect]) &&
    rect.node is @object.Path(_, style) else {
    fail("rect should lower to a styled path")
  }
  assert_close(style.fill_opacity, 0.5)
}

///|
test "missing required attributes report typed svg error" {
  let result = parse_result("<svg><rect/></svg>")
  guard result is Err(MissingAttribute(attribute="width", ..)) else {
    fail("missing rect width should be typed")
  }
}
