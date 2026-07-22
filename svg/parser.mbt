///|
pub fn SvgObject::parse_string(
  source : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
  default_style? : @object.ShapeStyle,
  override_style? : @object.ShapeStyle,
) -> SvgObject raise SvgError {
  let document = match @xml.xml_from_string(source) {
    Some(document) => document
    None => raise InvalidXml
  }
  let definitions : Map[String, @xml.XMLElement] = Map([])
  collect_definitions(document.root, definitions)
  let groups : Map[String, Array[@object.FamilyPath]] = Map([])
  let diagnostics : Array[SvgDiagnostic] = []
  let object = evaluate_element(
    document.root,
    SvgContext::root(definitions, default_style, groups, diagnostics),
    referenced=false,
  ).unwrap_or(@object.Object::empty())
  let object = normalize_svg_object(object, center~, height?, width?)
  {
    object: override_style.map_or(object, style => {
      apply_override_style(object, style)
    }),
    groups,
    diagnostics,
  }
}

///|
pub fn parse_string(
  source : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
  default_style? : @object.ShapeStyle,
  override_style? : @object.ShapeStyle,
) -> @object.Object raise SvgError {
  SvgObject::parse_string(
    source,
    center~,
    height?,
    width?,
    default_style?,
    override_style?,
  ).object()
}

///|
priv struct ResolvedViewport {
  user : SvgViewport
  transform : @object.Transform
  empty : Bool
}

///|
fn evaluate_element(
  element : @xml.XMLElement,
  context : SvgContext,
  referenced~ : Bool,
) -> @object.Object? raise SvgError {
  let name = local_name(element.name)
  if name == "svg" {
    return evaluate_svg_element(element, context)
  }
  let style = context.style.apply_element(element, context.viewport)
  if !style.displayed {
    return None
  }
  let local_transform = parse_transform_attribute(element)
  let context = context.enter(style, local_transform)
  if !style.visible && is_shape_element(name) {
    return None
  }
  let base = match name {
    "g" => Some(evaluate_group(element, context))
    "symbol" if referenced => Some(evaluate_group(element, context))
    "symbol" => None
    "use" => evaluate_use(element, context)
    "path" => Some(lower_path(element, style).with_transform(context.transform))
    "line" =>
      Some(
        lower_line(element, style, context.viewport).with_transform(
          context.transform,
        ),
      )
    "rect" =>
      Some(
        lower_rect(element, style, context.viewport).with_transform(
          context.transform,
        ),
      )
    "circle" =>
      Some(
        lower_circle(element, style, context.viewport).with_transform(
          context.transform,
        ),
      )
    "ellipse" =>
      Some(
        lower_ellipse(element, style, context.viewport).with_transform(
          context.transform,
        ),
      )
    "polygon" =>
      Some(
        lower_poly(element, style, closed=true).with_transform(
          context.transform,
        ),
      )
    "polyline" =>
      Some(
        lower_poly(element, style, closed=false).with_transform(
          context.transform,
        ),
      )
    _ if is_non_rendered_element(name) => None
    _ => {
      context.report_skipped(name)
      None
    }
  }
  match base {
    Some(object) => {
      context.record_id(element)
      Some(object)
    }
    None => None
  }
}

///|
fn evaluate_svg_element(
  element : @xml.XMLElement,
  context : SvgContext,
) -> @object.Object? raise SvgError {
  let viewport = resolve_svg_viewport(element, context.viewport)
  let style = context.style.apply_element(element, viewport.user)
  if !style.displayed {
    return None
  }
  let context = context.enter(style, parse_transform_attribute(element))
  if viewport.empty {
    context.record_id(element)
    Some(@object.Object::empty())
  } else {
    let object = evaluate_group(
      element,
      context.enter_viewport(viewport.user, viewport.transform),
    )
    context.record_id(element)
    Some(object)
  }
}

///|
fn resolve_svg_viewport(
  element : @xml.XMLElement,
  parent : SvgViewport,
) -> ResolvedViewport raise SvgError {
  let view_box = parse_view_box(element)
  let width = length_attribute_in(
    element,
    "width",
    Horizontal,
    parent,
    default=parent.width,
  )
  let height = length_attribute_in(
    element,
    "height",
    Vertical,
    parent,
    default=parent.height,
  )
  if width < 0.0 || height < 0.0 {
    raise InvalidLength("svg viewport")
  }
  let physical = { width, height }
  let user = view_box.map_or(physical, box => {
    width: box.width,
    height: box.height,
  })
  let empty = width == 0.0 || height == 0.0
  let transform = if empty {
    @object.Transform::identity()
  } else {
    let x = length_attribute_in(element, "x", Horizontal, parent, default=0.0)
    let y = length_attribute_in(element, "y", Vertical, parent, default=0.0)
    viewport_transform(physical, view_box, parse_aspect_ratio(element), x, y)
  }
  { user, transform, empty }
}

///|
fn evaluate_group(
  element : @xml.XMLElement,
  context : SvgContext,
) -> @object.Object raise SvgError {
  let children : Array[@object.Object] = []
  let mut rendered_index = 0
  for child in element.children {
    match child {
      Element(child_element) =>
        match
          evaluate_element(
            child_element,
            context.at_child(rendered_index),
            referenced=false,
          ) {
          Some(object) => {
            children.push(object)
            rendered_index = rendered_index + 1
          }
          None => ()
        }
      _ => ()
    }
  }
  @object.Object::group(children)
}

///|
fn evaluate_use(
  element : @xml.XMLElement,
  context : SvgContext,
) -> @object.Object? raise SvgError {
  let href = match
    (element.get_attribute("href"), element.get_attribute("xlink:href")) {
    (Some(value), _) => value
    (None, Some(value)) => value
    (None, None) => raise MissingReference("")
  }
  let id = reference_id(href)
  let target = match context.definitions.get(id) {
    Some(target) => target
    None => raise MissingReference(id)
  }
  let positioned = context.translate(
    length_attribute_in(element, "x", Horizontal, context.viewport, default=0.0),
    length_attribute_in(element, "y", Vertical, context.viewport, default=0.0),
  )
  let referenced_context = positioned.follow(id)
  if local_name(target.name) == "symbol" {
    evaluate_symbol(target, element, referenced_context)
  } else {
    evaluate_element(target, referenced_context, referenced=true)
  }
}

///|
fn evaluate_symbol(
  symbol : @xml.XMLElement,
  use_element : @xml.XMLElement,
  context : SvgContext,
) -> @object.Object? raise SvgError {
  let view_box = parse_view_box(symbol)
  let parent = context.viewport
  let width = instance_length(
    use_element,
    symbol,
    "width",
    Horizontal,
    parent,
    view_box.map_or(parent.width, box => box.width),
  )
  let height = instance_length(
    use_element,
    symbol,
    "height",
    Vertical,
    parent,
    view_box.map_or(parent.height, box => box.height),
  )
  if width < 0.0 || height < 0.0 {
    raise InvalidLength("symbol viewport")
  }
  let viewport = { width, height }
  let user_viewport = view_box.map_or(viewport, box => {
    width: box.width,
    height: box.height,
  })
  let style = context.style.apply_element(symbol, user_viewport)
  if !style.displayed {
    return None
  }
  let context = context.enter(style, parse_transform_attribute(symbol))
  if width == 0.0 || height == 0.0 {
    None
  } else {
    let transform = viewport_transform(
      viewport,
      view_box,
      parse_aspect_ratio(symbol),
      0.0,
      0.0,
    )
    let object = evaluate_group(
      symbol,
      context.enter_viewport(user_viewport, transform),
    )
    context.record_id(symbol)
    Some(object)
  }
}

///|
fn instance_length(
  instance : @xml.XMLElement,
  definition : @xml.XMLElement,
  name : String,
  axis : SvgLengthAxis,
  viewport : SvgViewport,
  default : Double,
) -> Double raise SvgError {
  match (instance.get_attribute(name), definition.get_attribute(name)) {
    (Some(value), _) | (None, Some(value)) =>
      parse_length(value, axis, viewport, name)
    (None, None) => default
  }
}

///|
fn reference_id(href : String) -> String raise SvgError {
  if href.has_prefix("#") && href.length() > 1 {
    href.unsafe_substring(start=1, end=href.length())
  } else {
    raise MissingReference(href)
  }
}

///|
fn collect_definitions(
  element : @xml.XMLElement,
  definitions : Map[String, @xml.XMLElement],
) -> Unit {
  match element.get_attribute("id") {
    Some(id) if id != "" => definitions[id] = element
    _ => ()
  }
  for child in element.children {
    match child {
      Element(child_element) => collect_definitions(child_element, definitions)
      _ => ()
    }
  }
}

///|
fn lower_path(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let data = required_attribute(element, "d")
  @object.Object::path(parse_path_data(data), style=style.to_shape_style())
}

///|
fn lower_line(
  element : @xml.XMLElement,
  style : SvgStyle,
  viewport : SvgViewport,
) -> @object.Object raise SvgError {
  let x1 = length_attribute_in(element, "x1", Horizontal, viewport, default=0.0)
  let y1 = length_attribute_in(element, "y1", Vertical, viewport, default=0.0)
  let x2 = length_attribute_in(element, "x2", Horizontal, viewport, default=0.0)
  let y2 = length_attribute_in(element, "y2", Vertical, viewport, default=0.0)
  let path = @object.Path3D::empty()
  path.move_to(@object.Vec3::new(x=x1, y=y1))
  path.line_to(@object.Vec3::new(x=x2, y=y2))
  @object.Object::path(path, style=style.to_shape_style())
}

///|
fn lower_rect(
  element : @xml.XMLElement,
  style : SvgStyle,
  viewport : SvgViewport,
) -> @object.Object raise SvgError {
  let x = length_attribute_in(element, "x", Horizontal, viewport, default=0.0)
  let y = length_attribute_in(element, "y", Vertical, viewport, default=0.0)
  let width = required_length_attribute_in(
    element,
    "width",
    Horizontal,
    viewport,
  )
  let height = required_length_attribute_in(
    element,
    "height",
    Vertical,
    viewport,
  )
  if width < 0.0 || height < 0.0 {
    raise InvalidLength("rect")
  }
  let radius_x = optional_length_attribute_in(
    element,
    "rx",
    Horizontal,
    viewport,
  )
  let radius_y = optional_length_attribute_in(element, "ry", Vertical, viewport)
  let (rx, ry) = match (radius_x, radius_y) {
    (None, None) => (0.0, 0.0)
    (Some(rx), None) => (rx, rx)
    (None, Some(ry)) => (ry, ry)
    (Some(rx), Some(ry)) => (rx, ry)
  }
  if rx < 0.0 || ry < 0.0 {
    raise InvalidLength("rect radius")
  }
  let path = rect_path(
    x,
    y,
    width,
    height,
    Double::min(rx, width / 2.0),
    Double::min(ry, height / 2.0),
  )
  @object.Object::path(path, style=style.to_shape_style())
}

///|
fn rect_path(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
) -> @object.Path3D {
  let path = @object.Path3D::empty()
  if rx == 0.0 || ry == 0.0 {
    path.move_to(@object.Vec3::new(x~, y~))
    path.line_to(@object.Vec3::new(x=x + width, y~))
    path.line_to(@object.Vec3::new(x=x + width, y=y + height))
    path.line_to(@object.Vec3::new(x~, y=y + height))
    path.close()
  } else {
    let kappa = 0.5522847498307936
    path.move_to(@object.Vec3::new(x=x + rx, y~))
    path.line_to(@object.Vec3::new(x=x + width - rx, y~))
    path.cubic_to(
      @object.Vec3::new(x=x + width - rx + kappa * rx, y~),
      @object.Vec3::new(x=x + width, y=y + ry - kappa * ry),
      @object.Vec3::new(x=x + width, y=y + ry),
    )
    path.line_to(@object.Vec3::new(x=x + width, y=y + height - ry))
    path.cubic_to(
      @object.Vec3::new(x=x + width, y=y + height - ry + kappa * ry),
      @object.Vec3::new(x=x + width - rx + kappa * rx, y=y + height),
      @object.Vec3::new(x=x + width - rx, y=y + height),
    )
    path.line_to(@object.Vec3::new(x=x + rx, y=y + height))
    path.cubic_to(
      @object.Vec3::new(x=x + rx - kappa * rx, y=y + height),
      @object.Vec3::new(x~, y=y + height - ry + kappa * ry),
      @object.Vec3::new(x~, y=y + height - ry),
    )
    path.line_to(@object.Vec3::new(x~, y=y + ry))
    path.cubic_to(
      @object.Vec3::new(x~, y=y + ry - kappa * ry),
      @object.Vec3::new(x=x + rx - kappa * rx, y~),
      @object.Vec3::new(x=x + rx, y~),
    )
    path.close()
  }
  path
}

///|
fn lower_circle(
  element : @xml.XMLElement,
  style : SvgStyle,
  viewport : SvgViewport,
) -> @object.Object raise SvgError {
  let cx = length_attribute_in(element, "cx", Horizontal, viewport, default=0.0)
  let cy = length_attribute_in(element, "cy", Vertical, viewport, default=0.0)
  let radius = required_length_attribute_in(element, "r", Diagonal, viewport)
  @object.Object::path(
    ellipse_path(cx, cy, radius, radius),
    style=style.to_shape_style(),
  )
}

///|
fn lower_ellipse(
  element : @xml.XMLElement,
  style : SvgStyle,
  viewport : SvgViewport,
) -> @object.Object raise SvgError {
  let cx = length_attribute_in(element, "cx", Horizontal, viewport, default=0.0)
  let cy = length_attribute_in(element, "cy", Vertical, viewport, default=0.0)
  let rx = required_length_attribute_in(element, "rx", Horizontal, viewport)
  let ry = required_length_attribute_in(element, "ry", Vertical, viewport)
  @object.Object::path(
    ellipse_path(cx, cy, rx, ry),
    style=style.to_shape_style(),
  )
}

///|
fn lower_poly(
  element : @xml.XMLElement,
  style : SvgStyle,
  closed~ : Bool,
) -> @object.Object raise SvgError {
  let points = parse_points(required_attribute(element, "points"))
  let path = poly_path(points, closed~)
  @object.Object::path(path, style=style.to_shape_style())
}

///|
fn ellipse_path(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> @object.Path3D {
  let kappa = 0.5522847498307936
  let path = @object.Path3D::empty()
  path.move_to(@object.Vec3::new(x=cx + rx, y=cy))
  path.cubic_to(
    @object.Vec3::new(x=cx + rx, y=cy + kappa * ry),
    @object.Vec3::new(x=cx + kappa * rx, y=cy + ry),
    @object.Vec3::new(x=cx, y=cy + ry),
  )
  path.cubic_to(
    @object.Vec3::new(x=cx - kappa * rx, y=cy + ry),
    @object.Vec3::new(x=cx - rx, y=cy + kappa * ry),
    @object.Vec3::new(x=cx - rx, y=cy),
  )
  path.cubic_to(
    @object.Vec3::new(x=cx - rx, y=cy - kappa * ry),
    @object.Vec3::new(x=cx - kappa * rx, y=cy - ry),
    @object.Vec3::new(x=cx, y=cy - ry),
  )
  path.cubic_to(
    @object.Vec3::new(x=cx + kappa * rx, y=cy - ry),
    @object.Vec3::new(x=cx + rx, y=cy - kappa * ry),
    @object.Vec3::new(x=cx + rx, y=cy),
  )
  path.close()
  path
}

///|
fn poly_path(points : Array[@object.Vec3], closed~ : Bool) -> @object.Path3D {
  let path = @object.Path3D::empty()
  match points.get(0) {
    None => path
    Some(first) => {
      path.move_to(first)
      for index in 1..<points.length() {
        path.line_to(points[index])
      }
      if closed && points.length() > 1 {
        path.close()
      }
      path
    }
  }
}

///|
fn parse_points(data : String) -> Array[@object.Vec3] raise SvgError {
  let scanner = TextScanner::new(data)
  let points : Array[@object.Vec3] = []
  while !scanner.is_done() {
    scanner.skip_comma_wsp()
    if scanner.is_done() {
      break
    }
    let x = scanner.read_required_number("points")
    let y = scanner.read_required_number("points")
    points.push(@object.Vec3::new(x~, y~))
  }
  points
}

///|
fn parse_transform_attribute(
  element : @xml.XMLElement,
) -> @object.Transform raise SvgError {
  match element.get_attribute("transform") {
    None => @object.Transform::identity()
    Some(transform) => parse_transform_list(transform)
  }
}

///|
fn parse_transform_list(value : String) -> @object.Transform raise SvgError {
  let scanner = TextScanner::new(value)
  let mut transform = @object.Transform::identity()
  while !scanner.is_done() {
    scanner.skip_comma_wsp()
    if scanner.is_done() {
      break
    }
    let name = match scanner.read_ident() {
      Some(name) => name.to_lower()
      None => raise InvalidTransform(value)
    }
    scanner.expect_char('(', value)
    let args = read_transform_args(scanner, value)
    transform = transform_command(name, args, value).then(transform)
  }
  transform
}

///|
fn read_transform_args(
  scanner : TextScanner,
  context : String,
) -> Array[Double] raise SvgError {
  let args : Array[Double] = []
  while !scanner.is_done() {
    scanner.skip_comma_wsp()
    match scanner.peek() {
      Some(')') => {
        scanner.advance() |> ignore
        return args
      }
      None => raise InvalidTransform(context)
      _ => args.push(scanner.read_required_number(context))
    }
  }
  raise InvalidTransform(context)
}

///|
fn transform_command(
  name : String,
  args : Array[Double],
  context : String,
) -> @object.Transform raise SvgError {
  match name {
    "matrix" =>
      if args.length() == 6 {
        svg_matrix(args[0], args[1], args[2], args[3], args[4], args[5])
      } else {
        raise InvalidTransform(context)
      }
    "translate" =>
      if args.length() == 1 || args.length() == 2 {
        @object.Transform::translate(
          @object.Vec3::new(x=args[0], y=args.get(1).unwrap_or(0.0)),
        )
      } else {
        raise InvalidTransform(context)
      }
    "scale" =>
      if args.length() == 1 || args.length() == 2 {
        @object.Transform::scale(sx=args[0], sy=args.get(1).unwrap_or(args[0]))
      } else {
        raise InvalidTransform(context)
      }
    "rotate" =>
      if args.length() == 1 {
        @object.Transform::rotate(angle=degrees_to_radians(args[0]))
      } else if args.length() == 3 {
        @object.Transform::rotate_about(
          angle=degrees_to_radians(args[0]),
          axis=@object.Vec3::unit_z(),
          point=@object.Vec3::new(x=args[1], y=args[2]),
        )
      } else {
        raise InvalidTransform(context)
      }
    "skewx" =>
      if args.length() == 1 {
        svg_matrix(
          1.0,
          0.0,
          @math.tan(degrees_to_radians(args[0])),
          1.0,
          0.0,
          0.0,
        )
      } else {
        raise InvalidTransform(context)
      }
    "skewy" =>
      if args.length() == 1 {
        svg_matrix(
          1.0,
          @math.tan(degrees_to_radians(args[0])),
          0.0,
          1.0,
          0.0,
          0.0,
        )
      } else {
        raise InvalidTransform(context)
      }
    _ => raise InvalidTransform(context)
  }
}

///|
fn svg_matrix(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> @object.Transform {
  {
    m00: a,
    m01: c,
    m02: 0.0,
    m03: e,
    m10: b,
    m11: d,
    m12: 0.0,
    m13: f,
    m20: 0.0,
    m21: 0.0,
    m22: 1.0,
    m23: 0.0,
  }
}

///|
fn degrees_to_radians(degrees : Double) -> Double {
  degrees * @math.PI / 180.0
}

///|
fn normalize_svg_object(
  object : @object.Object,
  center~ : Bool,
  height? : Double,
  width? : Double,
) -> @object.Object {
  let mut result = object.with_transform(
    object.transform.then(@object.Transform::scale(sx=1.0, sy=-1.0)),
  )
  if center {
    result = result.move_to(@object.Vec3::zero())
  }
  match fit_scale(result.bounds(), width, height) {
    None => result
    Some(scale) => {
      let center = result.center()
      let about_center = @object.Transform::translate(center.scale(-1.0))
        .then(@object.Transform::scale(sx=scale, sy=scale))
        .then(@object.Transform::translate(center))
      result.with_transform(result.transform.then(about_center))
    }
  }
}

///|
fn fit_scale(
  bounds : @object.Aabb?,
  width : Double?,
  height : Double?,
) -> Double? {
  match bounds {
    None => None
    Some(bounds) => {
      let factors : Array[Double] = []
      match width {
        Some(width) if bounds.width() > 0.0 =>
          factors.push(width / bounds.width())
        _ => ()
      }
      match height {
        Some(height) if bounds.height() > 0.0 =>
          factors.push(height / bounds.height())
        _ => ()
      }
      factors.fold(init=None, (current : Double?, factor) => {
        match current {
          None => Some(factor)
          Some(current) => Some(Double::min(current, factor))
        }
      })
    }
  }
}

///|
fn required_attribute(
  element : @xml.XMLElement,
  name : String,
) -> String raise SvgError {
  match element.get_attribute(name) {
    Some(value) => value
    None => raise MissingAttribute(element=element.name, attribute=name)
  }
}

///|
fn local_name(name : String) -> String {
  match name.rev_split_once(":") {
    Some((_, tail)) => tail.to_owned()
    None => name
  }
}

///|
fn is_non_rendered_element(name : String) -> Bool {
  name == "defs" ||
  name == "title" ||
  name == "desc" ||
  name == "metadata" ||
  name == "style"
}

///|
fn is_shape_element(name : String) -> Bool {
  name == "path" ||
  name == "line" ||
  name == "rect" ||
  name == "circle" ||
  name == "ellipse" ||
  name == "polygon" ||
  name == "polyline"
}
