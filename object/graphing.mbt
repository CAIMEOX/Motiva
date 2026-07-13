///|
pub(all) struct NumberLine {
  x_min : Double
  x_max : Double
  x_step : Double
  length : Double
  include_ticks : Bool
  tick_size : Double
  include_tip : Bool
  tip_length : Double
  tip_width : Double
  style : ShapeStyle
}

///|
pub fn NumberLine::new(
  x_min? : Double = -6.0,
  x_max? : Double = 6.0,
  x_step? : Double = 1.0,
  length? : Double,
  unit_size? : Double = 1.0,
  include_ticks? : Bool = true,
  tick_size? : Double = 0.1,
  include_tip? : Bool = false,
  tip_length? : Double = 0.25,
  tip_width? : Double = 0.25,
  style? : ShapeStyle = default_axis_style(),
) -> NumberLine {
  {
    x_min,
    x_max,
    x_step,
    length: length.map_or(Double::abs(x_max - x_min) * unit_size, value => value),
    include_ticks,
    tick_size,
    include_tip,
    tip_length,
    tip_width,
    style,
  }
}

///|
pub fn NumberLine::number_to_point(self : NumberLine, value : Double) -> Vec3 {
  Vec3::new(x=map_range(value, self.x_min, self.x_max, self.length), y=0.0)
}

///|
pub fn NumberLine::point_to_number(self : NumberLine, point : Vec3) -> Double {
  if self.length <= 0.0 {
    self.x_min
  } else {
    self.x_min + (point.x / self.length + 0.5) * (self.x_max - self.x_min)
  }
}

///|
pub fn NumberLine::tick_values(self : NumberLine) -> Array[Double] {
  let step = positive_step(self.x_step)
  let values : Array[Double] = []
  let ascending = self.x_max >= self.x_min
  let signed_step = if ascending { step } else { 0.0 - step }
  let stop = self.x_max
  let mut value = self.x_min
  while tick_in_range(value, stop, ascending) {
    values.push(value)
    value = value + signed_step
  }
  values
}

///|
pub fn NumberLine::tick(self : NumberLine, value : Double) -> Line {
  let center = self.number_to_point(value)
  let half = self.tick_size / 2.0
  Line::new(
    start=center.add(Vec3::new(x=0.0, y=0.0 - half)),
    end=center.add(Vec3::new(x=0.0, y=half)),
    style=self.style,
  )
}

///|
pub impl IntoObject for NumberLine with fn to_object(self) -> Object {
  let children : Array[Object] = []
  children.push(
    into_object(
      Line::new(
        start=self.number_to_point(self.x_min),
        end=self.number_to_point(self.x_max),
        style=self.style,
      ),
    ),
  )
  if self.include_ticks {
    for value in self.tick_values() {
      children.push(into_object(self.tick(value)))
    }
  }
  if self.include_tip {
    children.push(
      into_object(
        arrow_tip_polygon(
          tip=self.number_to_point(self.x_max),
          direction=Vec3::new(x=axis_direction(self), y=0.0),
          length=self.tip_length,
          width=self.tip_width,
          style=arrow_tip_style(self.style),
        ),
      ),
    )
  }
  Object::group(children)
}

///|
pub(all) struct Axes {
  x_min : Double
  x_max : Double
  x_step : Double
  y_min : Double
  y_max : Double
  y_step : Double
  x_length : Double
  y_length : Double
  tips : Bool
  tick_size : Double
  style : ShapeStyle
}

///|
pub fn Axes::new(
  x_min? : Double = -6.0,
  x_max? : Double = 6.0,
  x_step? : Double = 1.0,
  y_min? : Double = -3.0,
  y_max? : Double = 3.0,
  y_step? : Double = 1.0,
  x_length? : Double = 10.0,
  y_length? : Double = 6.0,
  tips? : Bool = true,
  tick_size? : Double = 0.1,
  style? : ShapeStyle = default_axis_style(),
) -> Axes {
  {
    x_min,
    x_max,
    x_step,
    y_min,
    y_max,
    y_step,
    x_length,
    y_length,
    tips,
    tick_size,
    style,
  }
}

///|
pub fn Axes::x_axis(self : Axes) -> NumberLine {
  NumberLine::new(
    x_min=self.x_min,
    x_max=self.x_max,
    x_step=self.x_step,
    length=self.x_length,
    include_tip=self.tips,
    tick_size=self.tick_size,
    style=self.style,
  )
}

///|
pub fn Axes::y_axis(self : Axes) -> NumberLine {
  NumberLine::new(
    x_min=self.y_min,
    x_max=self.y_max,
    x_step=self.y_step,
    length=self.y_length,
    include_tip=self.tips,
    tick_size=self.tick_size,
    style=self.style,
  )
}

///|
pub fn Axes::coords_to_point(self : Axes, x : Double, y : Double) -> Vec3 {
  Vec3::new(
    x=map_range(x, self.x_min, self.x_max, self.x_length),
    y=map_range(y, self.y_min, self.y_max, self.y_length),
  )
}

///|
pub fn Axes::point_to_coords(self : Axes, point : Vec3) -> (Double, Double) {
  (
    unmap_range(point.x, self.x_min, self.x_max, self.x_length),
    unmap_range(point.y, self.y_min, self.y_max, self.y_length),
  )
}

///|
pub fn Axes::plot(
  self : Axes,
  function : (Double) -> Double,
  x_min? : Double,
  x_max? : Double,
  step? : Double,
  style? : ShapeStyle = default_graph_style(),
) -> ParametricFunction {
  let start = x_min.map_or(self.x_min, value => value)
  let stop = x_max.map_or(self.x_max, value => value)
  ParametricFunction::new(
    t => self.coords_to_point(t, function(t)),
    t_min=start,
    t_max=stop,
    step=step.map_or(0.05, value => value),
    style~,
  )
}

///|
pub fn Axes::plot_parametric_curve(
  self : Axes,
  function : (Double) -> Vec3,
  t_min? : Double = 0.0,
  t_max? : Double = 1.0,
  step? : Double = 0.01,
  style? : ShapeStyle = default_graph_style(),
) -> ParametricFunction {
  ParametricFunction::new(
    t => {
      let point = function(t)
      self.coords_to_point(point.x, point.y)
    },
    t_min~,
    t_max~,
    step~,
    style~,
  )
}

///|
pub impl IntoObject for Axes with fn to_object(self) -> Object {
  Object::group([
    into_object(self.x_axis()),
    into_object(self.y_axis()).with_transform(
      Transform::rotate(angle=@math.PI / 2.0),
    ),
  ])
}

///|
pub(all) struct ParametricFunction {
  function : (Double) -> Vec3
  t_min : Double
  t_max : Double
  step : Double
  style : ShapeStyle
}

///|
pub fn ParametricFunction::new(
  function : (Double) -> Vec3,
  t_min? : Double = 0.0,
  t_max? : Double = 1.0,
  step? : Double = 0.01,
  style? : ShapeStyle = default_graph_style(),
) -> ParametricFunction {
  { function, t_min, t_max, step, style }
}

///|
pub fn ParametricFunction::path(self : ParametricFunction) -> Path3D {
  sample_parametric_path(self.function, self.t_min, self.t_max, self.step)
}

///|
pub impl IntoObject for ParametricFunction with fn to_object(self) -> Object {
  Object::path(self.path(), style=self.style)
}

///|
pub(all) struct FunctionGraph {
  function : (Double) -> Double
  x_min : Double
  x_max : Double
  step : Double
  style : ShapeStyle
}

///|
pub fn FunctionGraph::new(
  function : (Double) -> Double,
  x_min? : Double = -4.0,
  x_max? : Double = 4.0,
  step? : Double = 0.05,
  style? : ShapeStyle = default_graph_style(),
) -> FunctionGraph {
  { function, x_min, x_max, step, style }
}

///|
pub fn FunctionGraph::parametric(self : FunctionGraph) -> ParametricFunction {
  ParametricFunction::new(
    x => Vec3::new(x~, y=(self.function)(x)),
    t_min=self.x_min,
    t_max=self.x_max,
    step=self.step,
    style=self.style,
  )
}

///|
pub fn FunctionGraph::path(self : FunctionGraph) -> Path3D {
  self.parametric().path()
}

///|
pub impl IntoObject for FunctionGraph with fn to_object(self) -> Object {
  into_object(self.parametric())
}

///|
fn sample_parametric_path(
  function : (Double) -> Vec3,
  start : Double,
  stop : Double,
  step : Double,
) -> Path3D {
  let path = Path3D::empty()
  path.move_to(function(start))
  if start != stop {
    let signed_step = positive_step(step) *
      (if stop >= start { 1.0 } else { -1.0 })
    let ascending = stop >= start
    let mut t = start + signed_step
    while sample_in_range(t, stop, ascending) {
      path.line_to(function(t))
      t = t + signed_step
    }
    path.line_to(function(stop))
  }
  path
}

///|
fn map_range(
  value : Double,
  min : Double,
  max : Double,
  length : Double,
) -> Double {
  if max == min || length <= 0.0 {
    0.0
  } else {
    ((value - min) / (max - min) - 0.5) * length
  }
}

///|
fn unmap_range(
  value : Double,
  min : Double,
  max : Double,
  length : Double,
) -> Double {
  if length <= 0.0 {
    min
  } else {
    min + (value / length + 0.5) * (max - min)
  }
}

///|
fn tick_in_range(value : Double, stop : Double, ascending : Bool) -> Bool {
  if ascending {
    value <= stop + 0.000000001
  } else {
    value >= stop - 0.000000001
  }
}

///|
fn sample_in_range(value : Double, stop : Double, ascending : Bool) -> Bool {
  if ascending {
    value < stop
  } else {
    value > stop
  }
}

///|
fn positive_step(step : Double) -> Double {
  if step <= 0.0 || step.is_nan() {
    1.0
  } else {
    step
  }
}

///|
fn axis_direction(line : NumberLine) -> Double {
  if line.x_max >= line.x_min {
    1.0
  } else {
    -1.0
  }
}

///|
fn default_axis_style() -> ShapeStyle {
  ShapeStyle::stroked(color=Rgba::white(), stroke_width=2.0)
}

///|
fn default_graph_style() -> ShapeStyle {
  ShapeStyle::stroked(color=Rgba::rgb(r=1.0, g=0.86, b=0.24), stroke_width=4.0)
}
