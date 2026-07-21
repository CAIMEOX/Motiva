///|
pub(all) struct Rgba {
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Hash)

///|
pub fn Rgba::new(r~ : Double, g~ : Double, b~ : Double, a~ : Double) -> Rgba {
  { r, g, b, a }
}

///|
pub fn Rgba::rgb(r~ : Double, g~ : Double, b~ : Double) -> Rgba {
  { r, g, b, a: 1.0 }
}

///|
pub fn Rgba::transparent() -> Rgba {
  Rgba::new(r=0.0, g=0.0, b=0.0, a=0.0)
}

///|
pub fn Rgba::white() -> Rgba {
  Rgba::rgb(r=1.0, g=1.0, b=1.0)
}

///|
pub fn Rgba::black() -> Rgba {
  Rgba::rgb(r=0.0, g=0.0, b=0.0)
}

///|
pub fn Rgba::red() -> Rgba {
  Rgba::rgb(r=1.0, g=0.0, b=0.0)
}

///|
/// SVG/CSS green, `#008000`.
pub fn Rgba::green() -> Rgba {
  Rgba::rgb(r=0.0, g=0.5019607843137255, b=0.0)
}

///|
/// Bright RGB green, named `lime` in SVG/CSS.
pub fn Rgba::lime() -> Rgba {
  Rgba::rgb(r=0.0, g=1.0, b=0.0)
}

///|
pub fn Rgba::blue() -> Rgba {
  Rgba::rgb(r=0.0, g=0.0, b=1.0)
}

///|
pub fn Rgba::manim_blue() -> Rgba {
  Rgba::rgb(r=88.0 / 255.0, g=196.0 / 255.0, b=221.0 / 255.0)
}

///|
pub fn Rgba::manim_blue_d() -> Rgba {
  Rgba::rgb(r=41.0 / 255.0, g=171.0 / 255.0, b=202.0 / 255.0)
}

///|
pub fn Rgba::manim_blue_e() -> Rgba {
  Rgba::rgb(r=35.0 / 255.0, g=107.0 / 255.0, b=142.0 / 255.0)
}

///|
pub fn Rgba::light_gray() -> Rgba {
  Rgba::rgb(r=187.0 / 255.0, g=187.0 / 255.0, b=187.0 / 255.0)
}

///|
pub fn Rgba::yellow() -> Rgba {
  Rgba::rgb(r=1.0, g=1.0, b=0.0)
}

///|
pub fn Rgba::cyan() -> Rgba {
  Rgba::rgb(r=0.0, g=1.0, b=1.0)
}

///|
pub fn Rgba::magenta() -> Rgba {
  Rgba::rgb(r=1.0, g=0.0, b=1.0)
}

///|
pub(all) struct ShapeStyle {
  fill : Rgba?
  fill_opacity : Double
  stroke : Rgba?
  stroke_opacity : Double
  stroke_width : Double
} derive(Eq, Hash)

///|
pub fn ShapeStyle::new(
  fill? : Rgba,
  fill_opacity? : Double = 0.0,
  stroke? : Rgba,
  stroke_opacity? : Double = 1.0,
  stroke_width? : Double = 4.0,
) -> ShapeStyle {
  { fill, fill_opacity, stroke, stroke_opacity, stroke_width }
}

///|
pub fn ShapeStyle::stroked(
  color~ : Rgba,
  stroke_width? : Double = 4.0,
) -> ShapeStyle {
  ShapeStyle::new(stroke=color, stroke_width~)
}

///|
pub fn ShapeStyle::filled(color~ : Rgba) -> ShapeStyle {
  ShapeStyle::new(fill=color, fill_opacity=1.0, stroke=color)
}

///|
pub fn ShapeStyle::surface(
  fill? : Rgba = Rgba::manim_blue_d(),
  fill_opacity? : Double = 1.0,
  stroke? : Rgba = Rgba::light_gray(),
  stroke_opacity? : Double = 1.0,
  stroke_width? : Double = 0.5,
) -> ShapeStyle {
  ShapeStyle::new(fill~, fill_opacity~, stroke~, stroke_opacity~, stroke_width~)
}

///|
pub fn ShapeStyle::set_fill(
  self : ShapeStyle,
  color? : Rgba,
  opacity? : Double,
) -> ShapeStyle {
  {
    fill: resolve_rgba(self.fill, color),
    fill_opacity: opacity.map_or(self.fill_opacity, value => value),
    stroke: self.stroke,
    stroke_opacity: self.stroke_opacity,
    stroke_width: self.stroke_width,
  }
}

///|
pub fn ShapeStyle::set_stroke(
  self : ShapeStyle,
  color? : Rgba,
  width? : Double,
  opacity? : Double,
) -> ShapeStyle {
  {
    fill: self.fill,
    fill_opacity: self.fill_opacity,
    stroke: resolve_rgba(self.stroke, color),
    stroke_opacity: opacity.map_or(self.stroke_opacity, value => value),
    stroke_width: width.map_or(self.stroke_width, value => value),
  }
}

///|
pub fn ShapeStyle::set_color(self : ShapeStyle, color : Rgba) -> ShapeStyle {
  {
    fill: Some(color),
    fill_opacity: self.fill_opacity,
    stroke: Some(color),
    stroke_opacity: self.stroke_opacity,
    stroke_width: self.stroke_width,
  }
}

///|
pub impl Default for ShapeStyle with fn default() -> ShapeStyle {
  ShapeStyle::stroked(color=Rgba::white())
}

///|
fn resolve_rgba(current : Rgba?, next : Rgba?) -> Rgba? {
  match (current, next) {
    (_, Some(color)) => Some(color)
    (color, None) => color
  }
}
