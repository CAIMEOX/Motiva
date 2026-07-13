///|
priv enum SvgLengthAxis {
  Horizontal
  Vertical
  Diagonal
}

///|
priv struct SvgViewport {
  width : Double
  height : Double
}

///|
impl Default for SvgViewport with fn default() -> SvgViewport {
  { width: 300.0, height: 150.0 }
}

///|
fn parse_length(
  value : String,
  axis : SvgLengthAxis,
  viewport : SvgViewport,
  context : String,
) -> Double raise SvgError {
  let source = value.trim().to_owned()
  let scanner = TextScanner::new(source)
  let number = scanner.read_required_number(context)
  scanner.skip_wsp()
  let unit = source
    .unsafe_substring(start=scanner.index, end=source.length())
    .trim()
    .to_lower()
    .to_owned()
  let factor = match unit {
    "" | "px" => 1.0
    "in" => 96.0
    "cm" => 96.0 / 2.54
    "mm" => 96.0 / 25.4
    "q" => 96.0 / 101.6
    "pt" => 96.0 / 72.0
    "pc" => 16.0
    "em" => 16.0
    "ex" => 8.0
    "%" => percentage_basis(axis, viewport) / 100.0
    _ => raise InvalidLength(value)
  }
  number * factor
}

///|
fn percentage_basis(axis : SvgLengthAxis, viewport : SvgViewport) -> Double {
  match axis {
    Horizontal => viewport.width
    Vertical => viewport.height
    Diagonal =>
      (viewport.width * viewport.width + viewport.height * viewport.height).sqrt() /
      2.0.sqrt()
  }
}

///|
fn length_attribute_in(
  element : @xml.XMLElement,
  name : String,
  axis : SvgLengthAxis,
  viewport : SvgViewport,
  default~ : Double,
) -> Double raise SvgError {
  element
  .get_attribute(name)
  .map_or(default, value => parse_length(value, axis, viewport, name))
}

///|
fn required_length_attribute_in(
  element : @xml.XMLElement,
  name : String,
  axis : SvgLengthAxis,
  viewport : SvgViewport,
) -> Double raise SvgError {
  match element.get_attribute(name) {
    None =>
      raise MissingAttribute(element=local_name(element.name), attribute=name)
    Some(value) => parse_length(value, axis, viewport, name)
  }
}

///|
fn optional_length_attribute_in(
  element : @xml.XMLElement,
  name : String,
  axis : SvgLengthAxis,
  viewport : SvgViewport,
) -> Double? raise SvgError {
  element
  .get_attribute(name)
  .map(value => parse_length(value, axis, viewport, name))
}
