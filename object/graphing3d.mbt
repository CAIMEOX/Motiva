///|
pub(all) struct ThreeDAxes {
  x_min : Double
  x_max : Double
  x_step : Double
  y_min : Double
  y_max : Double
  y_step : Double
  z_min : Double
  z_max : Double
  z_step : Double
  x_length : Double
  y_length : Double
  z_length : Double
  tips : Bool
  tick_size : Double
  style : ShapeStyle
}

///|
pub fn ThreeDAxes::new(
  x_min? : Double = -6.0,
  x_max? : Double = 6.0,
  x_step? : Double = 1.0,
  y_min? : Double = -5.0,
  y_max? : Double = 5.0,
  y_step? : Double = 1.0,
  z_min? : Double = -4.0,
  z_max? : Double = 4.0,
  z_step? : Double = 1.0,
  x_length? : Double = 10.5,
  y_length? : Double = 10.5,
  z_length? : Double = 6.5,
  tips? : Bool = true,
  tick_size? : Double = 0.1,
  style? : ShapeStyle = ShapeStyle::stroked(
    color=Rgba::white(),
    stroke_width=2.0,
  ),
) -> ThreeDAxes {
  {
    x_min,
    x_max,
    x_step,
    y_min,
    y_max,
    y_step,
    z_min,
    z_max,
    z_step,
    x_length,
    y_length,
    z_length,
    tips,
    tick_size,
    style,
  }
}

///|
pub fn ThreeDAxes::x_axis(self : ThreeDAxes) -> NumberLine {
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
pub fn ThreeDAxes::y_axis(self : ThreeDAxes) -> NumberLine {
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
pub fn ThreeDAxes::z_axis(self : ThreeDAxes) -> NumberLine {
  NumberLine::new(
    x_min=self.z_min,
    x_max=self.z_max,
    x_step=self.z_step,
    length=self.z_length,
    include_tip=self.tips,
    tick_size=self.tick_size,
    style=self.style,
  )
}

///|
pub fn ThreeDAxes::coords_to_point(
  self : ThreeDAxes,
  x : Double,
  y : Double,
  z : Double,
) -> Vec3 {
  Vec3::new(
    x=map_range(x, self.x_min, self.x_max, self.x_length),
    y=map_range(y, self.y_min, self.y_max, self.y_length),
    z=map_range(z, self.z_min, self.z_max, self.z_length),
  )
}

///|
pub fn ThreeDAxes::point_to_coords(
  self : ThreeDAxes,
  point : Vec3,
) -> (Double, Double, Double) {
  (
    unmap_range(point.x, self.x_min, self.x_max, self.x_length),
    unmap_range(point.y, self.y_min, self.y_max, self.y_length),
    unmap_range(point.z, self.z_min, self.z_max, self.z_length),
  )
}

///|
pub fn ThreeDAxes::plot_parametric_curve(
  self : ThreeDAxes,
  function : (Double) -> Vec3,
  t_min? : Double = 0.0,
  t_max? : Double = 1.0,
  step? : Double = 0.01,
  style? : ShapeStyle = ShapeStyle::stroked(
    color=Rgba::rgb(r=1.0, g=0.86, b=0.24),
    stroke_width=4.0,
  ),
) -> ParametricFunction {
  ParametricFunction::new(
    t => {
      let point = function(t)
      self.coords_to_point(point.x, point.y, point.z)
    },
    t_min~,
    t_max~,
    step~,
    style~,
  )
}

///|
pub fn ThreeDAxes::plot_surface(
  self : ThreeDAxes,
  function : (Double, Double) -> Double,
  x_min? : Double,
  x_max? : Double,
  y_min? : Double,
  y_max? : Double,
  x_resolution? : Int = 32,
  y_resolution? : Int = 32,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [
    Rgba::manim_blue_d(),
    Rgba::manim_blue_e(),
  ],
) -> Surface {
  let start_x = x_min.unwrap_or(self.x_min)
  let end_x = x_max.unwrap_or(self.x_max)
  let start_y = y_min.unwrap_or(self.y_min)
  let end_y = y_max.unwrap_or(self.y_max)
  Surface::new(
    (x, y) => self.coords_to_point(x, y, function(x, y)),
    u_min=start_x,
    u_max=end_x,
    v_min=start_y,
    v_max=end_y,
    u_resolution=x_resolution,
    v_resolution=y_resolution,
    style~,
    checkerboard_colors~,
  )
}

///|
pub fn ThreeDAxes::plot_parametric_surface(
  self : ThreeDAxes,
  function : (Double, Double) -> Vec3,
  u_min? : Double = 0.0,
  u_max? : Double = 1.0,
  v_min? : Double = 0.0,
  v_max? : Double = 1.0,
  u_resolution? : Int = 32,
  v_resolution? : Int = 32,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [
    Rgba::manim_blue_d(),
    Rgba::manim_blue_e(),
  ],
) -> Surface {
  Surface::new(
    (u, v) => {
      let point = function(u, v)
      self.coords_to_point(point.x, point.y, point.z)
    },
    u_min~,
    u_max~,
    v_min~,
    v_max~,
    u_resolution~,
    v_resolution~,
    style~,
    checkerboard_colors~,
  )
}

///|
pub impl IntoObject for ThreeDAxes with fn to_object(self) -> Object {
  let style = axis_surface_style(self.style)
  let thickness = axis_thickness(self.style)
  let children : Array[Object] = []
  children.push(
    spatial_axis(
      self.coords_to_point(self.x_min, 0.0, 0.0),
      self.coords_to_point(self.x_max, 0.0, 0.0),
      self.tips,
      thickness,
      style,
    ),
  )
  children.push(
    spatial_axis(
      self.coords_to_point(0.0, self.y_min, 0.0),
      self.coords_to_point(0.0, self.y_max, 0.0),
      self.tips,
      thickness,
      style,
    ),
  )
  children.push(
    spatial_axis(
      self.coords_to_point(0.0, 0.0, self.z_min),
      self.coords_to_point(0.0, 0.0, self.z_max),
      self.tips,
      thickness,
      style,
    ),
  )
  append_x_ticks(children, self, style, thickness)
  append_y_ticks(children, self, style, thickness)
  append_z_ticks(children, self, style, thickness)
  Object::group(children)
}

///|
fn spatial_axis(
  start : Vec3,
  end : Vec3,
  tip : Bool,
  thickness : Double,
  style : ShapeStyle,
) -> Object {
  if tip {
    into_object(
      Arrow3D::new(
        start~,
        end~,
        thickness~,
        tip_height=0.22,
        tip_radius=0.07,
        radial_resolution=6,
        style~,
      ),
    )
  } else {
    spatial_tick(start, end, thickness, style)
  }
}

///|
fn spatial_tick(
  start : Vec3,
  end : Vec3,
  thickness : Double,
  style : ShapeStyle,
) -> Object {
  into_object(
    Line3D::new(start~, end~, thickness~, radial_resolution=6, style~),
  )
}

///|
fn append_x_ticks(
  children : Array[Object],
  axes : ThreeDAxes,
  style : ShapeStyle,
  thickness : Double,
) -> Unit {
  for value in axes.x_axis().tick_values() {
    let center = axes.coords_to_point(value, 0.0, 0.0)
    let offset = Vec3::unit_y().scale(axes.tick_size / 2.0)
    children.push(
      spatial_tick(
        center.sub(offset),
        center.add(offset),
        thickness * 0.72,
        style,
      ),
    )
  }
}

///|
fn append_y_ticks(
  children : Array[Object],
  axes : ThreeDAxes,
  style : ShapeStyle,
  thickness : Double,
) -> Unit {
  for value in axes.y_axis().tick_values() {
    let center = axes.coords_to_point(0.0, value, 0.0)
    let offset = Vec3::unit_x().scale(axes.tick_size / 2.0)
    children.push(
      spatial_tick(
        center.sub(offset),
        center.add(offset),
        thickness * 0.72,
        style,
      ),
    )
  }
}

///|
fn append_z_ticks(
  children : Array[Object],
  axes : ThreeDAxes,
  style : ShapeStyle,
  thickness : Double,
) -> Unit {
  for value in axes.z_axis().tick_values() {
    let center = axes.coords_to_point(0.0, 0.0, value)
    let offset = Vec3::unit_x().scale(axes.tick_size / 2.0)
    children.push(
      spatial_tick(
        center.sub(offset),
        center.add(offset),
        thickness * 0.72,
        style,
      ),
    )
  }
}

///|
fn axis_surface_style(style : ShapeStyle) -> ShapeStyle {
  let color = match (style.stroke, style.fill) {
    (Some(stroke), _) => stroke
    (None, Some(fill)) => fill
    (None, None) => Rgba::white()
  }
  ShapeStyle::surface(
    fill=color,
    fill_opacity=style.stroke_opacity,
    stroke=color,
    stroke_opacity=style.stroke_opacity,
    stroke_width=0.2,
  )
}

///|
fn axis_thickness(style : ShapeStyle) -> Double {
  let thickness = style.stroke_width * 0.005
  if thickness < 0.004 {
    0.004
  } else {
    thickness
  }
}
