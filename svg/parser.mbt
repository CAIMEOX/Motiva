///|
pub fn SvgObject::parse_string(
  source : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
) -> SvgObject raise SvgError {
  let document = match @xml.xml_from_string(source) {
    Some(document) => document
    None => raise InvalidXml
  }
  let object = lower_element(document.root, SvgStyle::default())
  { object: normalize_svg_object(object, center~, height?, width?) }
}

///|
pub fn parse_string(
  source : String,
  center? : Bool = true,
  height? : Double,
  width? : Double,
) -> @object.Object raise SvgError {
  SvgObject::parse_string(source, center~, height?, width?).object()
}

///|
fn lower_element(
  element : @xml.XMLElement,
  inherited_style : SvgStyle,
) -> @object.Object raise SvgError {
  let name = local_name(element.name)
  let style = inherited_style.apply_element(element)
  let base = if name == "svg" || name == "g" {
    lower_group(element, style)
  } else if name == "path" {
    lower_path(element, style)
  } else if name == "line" {
    lower_line(element, style)
  } else if name == "rect" {
    lower_rect(element, style)
  } else if name == "circle" {
    lower_circle(element, style)
  } else if name == "ellipse" {
    lower_ellipse(element, style)
  } else if name == "polygon" {
    lower_poly(element, style, closed=true)
  } else if name == "polyline" {
    lower_poly(element, style, closed=false)
  } else if is_non_rendered_element(name) {
    @object.Object::empty(id=element_id(element))
  } else {
    raise UnsupportedElement(name)
  }
  let transform = parse_transform_attribute(element)
  base.with_transform(base.transform.then(transform))
}

///|
fn lower_group(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let children : Array[@object.Object] = []
  for child in element.children {
    match child {
      Element(child_element) =>
        children.push(lower_element(child_element, style))
      _ => ()
    }
  }
  @object.Object::group(children, id=element_id(element))
}

///|
fn lower_path(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let data = required_attribute(element, "d")
  @object.Object::path(
    parse_path_data(data),
    style=style.to_shape_style(),
    id=element_id(element),
  )
}

///|
fn lower_line(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let x1 = length_attribute(element, "x1", default=0.0)
  let y1 = length_attribute(element, "y1", default=0.0)
  let x2 = length_attribute(element, "x2", default=0.0)
  let y2 = length_attribute(element, "y2", default=0.0)
  let path = @object.Path3D::empty()
  path.move_to(@object.Vec3::new(x=x1, y=y1))
  path.line_to(@object.Vec3::new(x=x2, y=y2))
  @object.Object::path(
    path,
    style=style.to_shape_style(),
    id=element_id(element),
  )
}

///|
fn lower_rect(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let x = length_attribute(element, "x", default=0.0)
  let y = length_attribute(element, "y", default=0.0)
  let width = required_length_attribute(element, "width")
  let height = required_length_attribute(element, "height")
  let path = @object.Path3D::empty()
  path.move_to(@object.Vec3::new(x~, y~))
  path.line_to(@object.Vec3::new(x=x + width, y~))
  path.line_to(@object.Vec3::new(x=x + width, y=y + height))
  path.line_to(@object.Vec3::new(x~, y=y + height))
  path.close()
  @object.Object::path(
    path,
    style=style.to_shape_style(),
    id=element_id(element),
  )
}

///|
fn lower_circle(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let cx = length_attribute(element, "cx", default=0.0)
  let cy = length_attribute(element, "cy", default=0.0)
  let radius = required_length_attribute(element, "r")
  @object.Object::path(
    ellipse_path(cx, cy, radius, radius),
    style=style.to_shape_style(),
    id=element_id(element),
  )
}

///|
fn lower_ellipse(
  element : @xml.XMLElement,
  style : SvgStyle,
) -> @object.Object raise SvgError {
  let cx = length_attribute(element, "cx", default=0.0)
  let cy = length_attribute(element, "cy", default=0.0)
  let rx = required_length_attribute(element, "rx")
  let ry = required_length_attribute(element, "ry")
  @object.Object::path(
    ellipse_path(cx, cy, rx, ry),
    style=style.to_shape_style(),
    id=element_id(element),
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
  @object.Object::path(
    path,
    style=style.to_shape_style(),
    id=element_id(element),
  )
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
    transform = transform.then(transform_command(name, args, value))
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
fn required_length_attribute(
  element : @xml.XMLElement,
  name : String,
) -> Double raise SvgError {
  parse_number_prefix(required_attribute(element, name), name)
}

///|
fn length_attribute(
  element : @xml.XMLElement,
  name : String,
  default~ : Double,
) -> Double raise SvgError {
  match element.get_attribute(name) {
    None => default
    Some(value) => parse_number_prefix(value, name)
  }
}

///|
fn element_id(element : @xml.XMLElement) -> String {
  element.get_attribute("id").unwrap_or("")
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
