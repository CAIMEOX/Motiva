///|
priv enum SvgPaint {
  NoPaint
  Solid(@object.Rgba)
  CurrentColor
}

///|
priv struct SvgStyle {
  color : @object.Rgba
  fill : SvgPaint
  fill_opacity : Double
  stroke : SvgPaint
  stroke_opacity : Double
  stroke_width : Double
  opacity : Double
  displayed : Bool
  visible : Bool
}

///|
impl Default for SvgStyle with fn default() -> SvgStyle {
  {
    color: @object.Rgba::black(),
    fill: Solid(@object.Rgba::black()),
    fill_opacity: 1.0,
    stroke: NoPaint,
    stroke_opacity: 1.0,
    stroke_width: 1.0,
    opacity: 1.0,
    displayed: true,
    visible: true,
  }
}

///|
fn SvgStyle::to_shape_style(self : SvgStyle) -> @object.ShapeStyle {
  let fill = self.fill.resolve(self.color)
  let stroke = self.stroke.resolve(self.color)
  @object.ShapeStyle::new(
    fill?,
    fill_opacity=self.fill_opacity * self.opacity,
    stroke?,
    stroke_opacity=self.stroke_opacity * self.opacity,
    stroke_width=self.stroke_width,
  )
}

///|
fn SvgStyle::apply_element(
  self : SvgStyle,
  element : @xml.XMLElement,
  viewport : SvgViewport,
) -> SvgStyle raise SvgError {
  let ancestor_displayed = self.displayed
  let ancestor_opacity = self.opacity
  let inherited_color = self.color
  let mut style = { ..self, displayed: true, opacity: 1.0 }
  style = style.apply_optional_property(
    "color",
    element.get_attribute("color"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "display",
    element.get_attribute("display"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "visibility",
    element.get_attribute("visibility"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "fill",
    element.get_attribute("fill"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "fill-opacity",
    element.get_attribute("fill-opacity"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "stroke",
    element.get_attribute("stroke"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "stroke-opacity",
    element.get_attribute("stroke-opacity"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "stroke-width",
    element.get_attribute("stroke-width"),
    viewport,
    inherited_color,
  )
  style = style.apply_optional_property(
    "opacity",
    element.get_attribute("opacity"),
    viewport,
    inherited_color,
  )
  style = match element.get_attribute("style") {
    None => style
    Some(inline_style) =>
      style.apply_inline_style(inline_style, viewport, inherited_color)
  }
  {
    ..style,
    displayed: ancestor_displayed && style.displayed,
    opacity: ancestor_opacity * style.opacity,
  }
}

///|
fn SvgStyle::apply_optional_property(
  self : SvgStyle,
  name : String,
  value : String?,
  viewport : SvgViewport,
  inherited_color : @object.Rgba,
) -> SvgStyle raise SvgError {
  match value {
    None => self
    Some(value) => self.apply_property(name, value, viewport, inherited_color)
  }
}

///|
fn SvgStyle::apply_inline_style(
  self : SvgStyle,
  inline_style : String,
  viewport : SvgViewport,
  inherited_color : @object.Rgba,
) -> SvgStyle raise SvgError {
  let mut style = self
  for declaration in inline_style.split(";") {
    match declaration.split_once(":") {
      None => ()
      Some((name, value)) =>
        style = style.apply_property(
          name.trim().to_owned(),
          value.trim().to_owned(),
          viewport,
          inherited_color,
        )
    }
  }
  style
}

///|
fn SvgStyle::apply_property(
  self : SvgStyle,
  name : String,
  value : String,
  viewport : SvgViewport,
  inherited_color : @object.Rgba,
) -> SvgStyle raise SvgError {
  let key = name.trim().to_lower().to_owned()
  let raw_value = value.trim().to_owned()
  let keyword = raw_value.to_lower()
  match key {
    "color" => { ..self, color: parse_color(raw_value, inherited_color) }
    "fill" => { ..self, fill: parse_svg_paint(raw_value) }
    "fill-opacity" =>
      { ..self, fill_opacity: parse_number_prefix(raw_value, key) }
    "stroke" => { ..self, stroke: parse_svg_paint(raw_value) }
    "stroke-opacity" =>
      { ..self, stroke_opacity: parse_number_prefix(raw_value, key) }
    "stroke-width" =>
      { ..self, stroke_width: parse_length(raw_value, Diagonal, viewport, key) }
    "opacity" => { ..self, opacity: parse_number_prefix(raw_value, key) }
    "display" => { ..self, displayed: keyword != "none" }
    "visibility" =>
      match keyword {
        "visible" => { ..self, visible: true }
        "hidden" | "collapse" => { ..self, visible: false }
        _ => self
      }
    _ => self
  }
}

///|
fn parse_svg_paint(value : String) -> SvgPaint raise SvgError {
  let normalized = value.trim().to_lower().to_owned()
  match normalized {
    "none" => NoPaint
    "transparent" => Solid(@object.Rgba::transparent())
    "currentcolor" => CurrentColor
    _ =>
      if normalized.has_prefix("#") {
        Solid(parse_hex_color(normalized))
      } else if normalized.has_prefix("rgb(") || normalized.has_prefix("rgba(") {
        Solid(parse_rgb_color(normalized))
      } else {
        match css_named_color(normalized) {
          Some(color) => Solid(color)
          None => raise InvalidColor(value)
        }
      }
  }
}

///|
fn SvgPaint::resolve(
  self : SvgPaint,
  current_color : @object.Rgba,
) -> @object.Rgba? {
  match self {
    NoPaint => None
    Solid(color) => Some(color)
    CurrentColor => Some(current_color)
  }
}

///|
fn parse_color(
  value : String,
  inherited : @object.Rgba,
) -> @object.Rgba raise SvgError {
  match parse_svg_paint(value) {
    Solid(color) => color
    CurrentColor => inherited
    NoPaint => raise InvalidColor(value)
  }
}

///|
fn parse_rgb_color(value : String) -> @object.Rgba raise SvgError {
  let prefix_length = if value.has_prefix("rgba(") { 5 } else { 4 }
  if !value.has_suffix(")") {
    raise InvalidColor(value)
  }
  let body = value.unsafe_substring(start=prefix_length, end=value.length() - 1)
  let scanner = TextScanner::new(body)
  let components : Array[Double] = []
  while !scanner.is_done() {
    skip_color_separators(scanner)
    if scanner.is_done() {
      break
    }
    let number = scanner.read_required_number(value)
    let percent = match scanner.peek() {
      Some('%') => {
        scanner.advance() |> ignore
        true
      }
      _ => false
    }
    let channel = components.length() < 3
    let scale = if percent { 100.0 } else if channel { 255.0 } else { 1.0 }
    components.push(clamp_color(number / scale))
  }
  match components {
    [r, g, b] => @object.Rgba::rgb(r~, g~, b~)
    [r, g, b, a] => @object.Rgba::new(r~, g~, b~, a~)
    _ => raise InvalidColor(value)
  }
}

///|
fn skip_color_separators(scanner : TextScanner) -> Unit {
  while !scanner.is_done() {
    match scanner.peek() {
      Some(char) if char.is_ascii_whitespace() || char == ',' || char == '/' =>
        scanner.advance() |> ignore
      _ => break
    }
  }
}

///|
fn clamp_color(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn parse_hex_color(value : String) -> @object.Rgba raise SvgError {
  match value.length() {
    4 =>
      @object.Rgba::rgb(
        r=parse_short_hex_component(value, 1),
        g=parse_short_hex_component(value, 2),
        b=parse_short_hex_component(value, 3),
      )
    5 =>
      @object.Rgba::new(
        r=parse_short_hex_component(value, 1),
        g=parse_short_hex_component(value, 2),
        b=parse_short_hex_component(value, 3),
        a=parse_short_hex_component(value, 4),
      )
    7 =>
      @object.Rgba::rgb(
        r=parse_hex_component(value, 1),
        g=parse_hex_component(value, 3),
        b=parse_hex_component(value, 5),
      )
    9 =>
      @object.Rgba::new(
        r=parse_hex_component(value, 1),
        g=parse_hex_component(value, 3),
        b=parse_hex_component(value, 5),
        a=parse_hex_component(value, 7),
      )
    _ => raise InvalidColor(value)
  }
}

///|
fn parse_short_hex_component(
  value : String,
  index : Int,
) -> Double raise SvgError {
  match value.get_char(index).bind(hex_digit) {
    Some(digit) => Double::from_int(digit * 17) / 255.0
    None => raise InvalidColor(value)
  }
}

///|
fn parse_hex_component(value : String, index : Int) -> Double raise SvgError {
  match
    (
      value.get_char(index).bind(hex_digit),
      value.get_char(index + 1).bind(hex_digit),
    ) {
    (Some(high), Some(low)) => Double::from_int(high * 16 + low) / 255.0
    _ => raise InvalidColor(value)
  }
}

///|
fn hex_digit(char : Char) -> Int? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}
