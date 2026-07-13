///|
pub(all) struct DashedLine {
  start : Vec3
  end : Vec3
  dash_length : Double
  dashed_ratio : Double
  style : ShapeStyle
}

///|
pub fn DashedLine::new(
  start? : Vec3 = Vec3::new(x=-1.0, y=0.0),
  end? : Vec3 = Vec3::new(x=1.0, y=0.0),
  dash_length? : Double = 0.2,
  dashed_ratio? : Double = 0.5,
  style? : ShapeStyle = ShapeStyle::default(),
) -> DashedLine {
  { start, end, dash_length, dashed_ratio, style }
}

///|
pub fn DashedLine::dashes(self : DashedLine) -> Array[Line] {
  let direction = self.end.sub(self.start)
  let length = direction.length()
  if length <= 0.0 || length.is_nan() {
    []
  } else {
    let unit = direction.scale(1.0 / length)
    let count = dashed_line_count(length, self.dash_length, self.dashed_ratio)
    let ratio = clamp_ratio(self.dashed_ratio)
    let dashes : Array[Line] = []
    for index in 0..<count {
      let start_alpha = index.to_double() / count.to_double()
      let end_alpha = (index.to_double() + ratio) / count.to_double()
      dashes.push(
        Line::new(
          start=self.start.add(unit.scale(length * start_alpha)),
          end=self.start.add(unit.scale(length * end_alpha)),
          style=self.style,
        ),
      )
    }
    dashes
  }
}

///|
pub impl IntoObject for DashedLine with fn to_object(self) -> Object {
  Object::group(self.dashes().map(dash => into_object(dash)))
}

///|
pub(all) struct Arrow {
  start : Vec3
  end : Vec3
  buff : Double
  tip_length : Double
  tip_width : Double
  max_tip_length_to_length_ratio : Double
  style : ShapeStyle
}

///|
pub fn Arrow::new(
  start? : Vec3 = Vec3::new(x=-1.0, y=0.0),
  end? : Vec3 = Vec3::new(x=1.0, y=0.0),
  buff? : Double = 0.25,
  tip_length? : Double = 0.35,
  tip_width? : Double = 0.35,
  max_tip_length_to_length_ratio? : Double = 0.25,
  style? : ShapeStyle = default_arrow_style(),
) -> Arrow {
  {
    start,
    end,
    buff,
    tip_length,
    tip_width,
    max_tip_length_to_length_ratio,
    style,
  }
}

///|
pub fn Arrow::shaft(self : Arrow) -> Line {
  let metrics = self.metrics()
  Line::new(start=metrics.shaft_start, end=metrics.shaft_end, style=self.style)
}

///|
pub fn Arrow::tip(self : Arrow) -> Polygon {
  let metrics = self.metrics()
  arrow_tip_polygon(
    tip=metrics.tip,
    direction=metrics.direction,
    length=metrics.tip_length,
    width=self.tip_width,
    style=arrow_tip_style(self.style),
  )
}

///|
pub impl IntoObject for Arrow with fn to_object(self) -> Object {
  let metrics = self.metrics()
  if metrics.available_length <= 0.0 {
    Object::empty()
  } else {
    Object::group([
      into_object(
        Line::new(
          start=metrics.shaft_start,
          end=metrics.shaft_end,
          style=self.style,
        ),
      ),
      into_object(
        arrow_tip_polygon(
          tip=metrics.tip,
          direction=metrics.direction,
          length=metrics.tip_length,
          width=self.tip_width,
          style=arrow_tip_style(self.style),
        ),
      ),
    ])
  }
}

///|
priv struct ArrowMetrics {
  direction : Vec3
  tip : Vec3
  shaft_start : Vec3
  shaft_end : Vec3
  tip_length : Double
  available_length : Double
}

///|
fn Arrow::metrics(self : Arrow) -> ArrowMetrics {
  let vector = self.end.sub(self.start)
  let length = vector.length()
  let direction = vector.normalize_or(Vec3::new(x=1.0, y=0.0))
  let safe_buff = clamp_non_negative(self.buff)
  let trimmed = Double::min(safe_buff, length / 2.0)
  let shaft_start = self.start.add(direction.scale(trimmed))
  let tip = self.end.sub(direction.scale(trimmed))
  let available_length = tip.sub(shaft_start).length()
  let tip_length = Double::min(
    clamp_non_negative(self.tip_length),
    available_length * clamp_ratio(self.max_tip_length_to_length_ratio),
  )
  {
    direction,
    tip,
    shaft_start,
    shaft_end: tip.sub(direction.scale(tip_length)),
    tip_length,
    available_length,
  }
}

///|
fn arrow_tip_polygon(
  tip~ : Vec3,
  direction~ : Vec3,
  length~ : Double,
  width~ : Double,
  style~ : ShapeStyle,
) -> Polygon {
  let normal = Vec3::new(x=0.0 - direction.y, y=direction.x).normalize_or(
    Vec3::new(x=0.0, y=1.0),
  )
  let base = tip.sub(direction.scale(length))
  let half_width = clamp_non_negative(width) / 2.0
  Polygon::new(
    [
      tip,
      base.add(normal.scale(half_width)),
      base.sub(normal.scale(half_width)),
    ],
    style~,
  )
}

///|
fn dashed_line_count(
  length : Double,
  dash_length : Double,
  dashed_ratio : Double,
) -> Int {
  let safe_dash_length = if dash_length <= 0.0 || dash_length.is_nan() {
    0.2
  } else {
    dash_length
  }
  max_int(
    2,
    (length / safe_dash_length * clamp_ratio(dashed_ratio)).ceil().to_int(),
  )
}

///|
fn default_arrow_style() -> ShapeStyle {
  ShapeStyle::stroked(color=Rgba::white(), stroke_width=6.0)
}

///|
fn arrow_tip_style(style : ShapeStyle) -> ShapeStyle {
  match style.stroke {
    None => ShapeStyle::new(stroke_width=0.0)
    Some(color) =>
      ShapeStyle::new(
        fill=color,
        fill_opacity=style.stroke_opacity,
        stroke=color,
        stroke_opacity=style.stroke_opacity,
        stroke_width=0.0,
      )
  }
}

///|
fn clamp_ratio(value : Double) -> Double {
  if value < 0.0 || value.is_nan() {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn clamp_non_negative(value : Double) -> Double {
  if value < 0.0 || value.is_nan() {
    0.0
  } else {
    value
  }
}
