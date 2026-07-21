///|
pub(all) struct Surface {
  function : (Double, Double) -> Vec3
  u_min : Double
  u_max : Double
  v_min : Double
  v_max : Double
  u_resolution : Int
  v_resolution : Int
  style : ShapeStyle
  checkerboard_colors : Array[Rgba]
}

///|
pub fn Surface::new(
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
  {
    function,
    u_min,
    u_max,
    v_min,
    v_max,
    u_resolution: positive_resolution(u_resolution),
    v_resolution: positive_resolution(v_resolution),
    style,
    checkerboard_colors: checkerboard_colors.copy(),
  }
}

///|
pub fn Surface::patch_count(self : Surface) -> Int {
  self.u_resolution * self.v_resolution
}

///|
pub fn Surface::patches(self : Surface) -> Array[Object] {
  let patches : Array[Object] = []
  for u_index in 0..<self.u_resolution {
    let u0 = sample_interval(self.u_min, self.u_max, u_index, self.u_resolution)
    let u1 = sample_interval(
      self.u_min,
      self.u_max,
      u_index + 1,
      self.u_resolution,
    )
    for v_index in 0..<self.v_resolution {
      let v0 = sample_interval(
        self.v_min,
        self.v_max,
        v_index,
        self.v_resolution,
      )
      let v1 = sample_interval(
        self.v_min,
        self.v_max,
        v_index + 1,
        self.v_resolution,
      )
      let style = checkerboard_style(self, u_index, v_index)
      patches.push(
        Object::mesh(
          Mesh3D::polygon([
            (self.function)(u0, v0),
            (self.function)(u1, v0),
            (self.function)(u1, v1),
            (self.function)(u0, v1),
          ]),
          style~,
        ),
      )
    }
  }
  patches
}

///|
pub impl IntoObject for Surface with fn to_object(self) -> Object {
  Object::group(self.patches())
}

///|
fn checkerboard_style(
  surface : Surface,
  u_index : Int,
  v_index : Int,
) -> ShapeStyle {
  match surface.checkerboard_colors {
    [] => surface.style
    colors => {
      let color = colors[(u_index + v_index) % colors.length()]
      surface.style.set_fill(color~, opacity=surface.style.fill_opacity)
    }
  }
}

///|
fn sample_interval(
  start : Double,
  end : Double,
  index : Int,
  resolution : Int,
) -> Double {
  start + (end - start) * index.to_double() / resolution.to_double()
}

///|
fn positive_resolution(resolution : Int) -> Int {
  if resolution < 1 {
    1
  } else {
    resolution
  }
}
