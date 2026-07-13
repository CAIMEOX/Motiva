///|
priv struct SvgStyle {
  fill : @object.Rgba?
  fill_opacity : Double
  stroke : @object.Rgba?
  stroke_opacity : Double
  stroke_width : Double
  opacity : Double
}

///|
impl Default for SvgStyle with fn default() -> SvgStyle {
  {
    fill: Some(@object.Rgba::black()),
    fill_opacity: 1.0,
    stroke: None,
    stroke_opacity: 1.0,
    stroke_width: 1.0,
    opacity: 1.0,
  }
}

///|
fn SvgStyle::to_shape_style(self : SvgStyle) -> @object.ShapeStyle {
  let fill = self.fill
  let stroke = self.stroke
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
) -> SvgStyle raise SvgError {
  let mut style = self
  style = style.apply_optional_property("fill", element.get_attribute("fill"))
  style = style.apply_optional_property(
    "fill-opacity",
    element.get_attribute("fill-opacity"),
  )
  style = style.apply_optional_property(
    "stroke",
    element.get_attribute("stroke"),
  )
  style = style.apply_optional_property(
    "stroke-opacity",
    element.get_attribute("stroke-opacity"),
  )
  style = style.apply_optional_property(
    "stroke-width",
    element.get_attribute("stroke-width"),
  )
  style = style.apply_optional_property(
    "opacity",
    element.get_attribute("opacity"),
  )
  match element.get_attribute("style") {
    None => style
    Some(inline_style) => style.apply_inline_style(inline_style)
  }
}

///|
fn SvgStyle::apply_optional_property(
  self : SvgStyle,
  name : String,
  value : String?,
) -> SvgStyle raise SvgError {
  match value {
    None => self
    Some(value) => self.apply_property(name, value)
  }
}

///|
fn SvgStyle::apply_inline_style(
  self : SvgStyle,
  inline_style : String,
) -> SvgStyle raise SvgError {
  let mut style = self
  for declaration in inline_style.split(";") {
    match declaration.split_once(":") {
      None => ()
      Some((name, value)) =>
        style = style.apply_property(
          name.trim().to_owned(),
          value.trim().to_owned(),
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
) -> SvgStyle raise SvgError {
  let key = name.trim().to_lower().to_owned()
  let raw_value = value.trim().to_owned()
  match key {
    "fill" => { ..self, fill: parse_paint(raw_value) }
    "fill-opacity" =>
      { ..self, fill_opacity: parse_number_prefix(raw_value, key) }
    "stroke" => { ..self, stroke: parse_paint(raw_value) }
    "stroke-opacity" =>
      { ..self, stroke_opacity: parse_number_prefix(raw_value, key) }
    "stroke-width" =>
      { ..self, stroke_width: parse_number_prefix(raw_value, key) }
    "opacity" =>
      { ..self, opacity: self.opacity * parse_number_prefix(raw_value, key) }
    _ => self
  }
}

///|
fn parse_paint(value : String) -> @object.Rgba? raise SvgError {
  let normalized = value.trim().to_lower().to_owned()
  match normalized {
    "none" => None
    "transparent" => Some(@object.Rgba::transparent())
    "black" => Some(@object.Rgba::black())
    "white" => Some(@object.Rgba::white())
    "red" => Some(@object.Rgba::red())
    "green" => Some(@object.Rgba::green())
    "blue" => Some(@object.Rgba::blue())
    "yellow" => Some(@object.Rgba::yellow())
    "cyan" => Some(@object.Rgba::cyan())
    "magenta" => Some(@object.Rgba::magenta())
    _ =>
      if normalized.has_prefix("#") {
        Some(parse_hex_color(normalized))
      } else {
        raise InvalidColor(value)
      }
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
