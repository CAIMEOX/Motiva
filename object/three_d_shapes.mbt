///|
pub(all) struct Sphere {
  center : Vec3
  radius : Double
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
pub fn Sphere::new(
  center? : Vec3 = Vec3::zero(),
  radius? : Double = 1.0,
  u_min? : Double = 0.0,
  u_max? : Double = 2.0 * @math.PI,
  v_min? : Double = 0.0,
  v_max? : Double = @math.PI,
  u_resolution? : Int = 24,
  v_resolution? : Int = 12,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [
    Rgba::manim_blue_d(),
    Rgba::manim_blue_e(),
  ],
) -> Sphere {
  {
    center,
    radius,
    u_min,
    u_max,
    v_min,
    v_max,
    u_resolution,
    v_resolution,
    style,
    checkerboard_colors: checkerboard_colors.copy(),
  }
}

///|
pub fn Sphere::surface(self : Sphere) -> Surface {
  let radius = self.radius
  Surface::new(
    (u, v) => {
      Vec3::new(
        x=radius * @math.cos(u) * @math.sin(v),
        y=radius * @math.sin(u) * @math.sin(v),
        z=0.0 - radius * @math.cos(v),
      )
    },
    u_min=self.u_min,
    u_max=self.u_max,
    v_min=self.v_min,
    v_max=self.v_max,
    u_resolution=self.u_resolution,
    v_resolution=self.v_resolution,
    style=self.style,
    checkerboard_colors=self.checkerboard_colors,
  )
}

///|
pub impl IntoObject for Sphere with fn to_object(self) -> Object {
  into_object(self.surface()).with_transform(Transform::translate(self.center))
}

///|
pub(all) struct Dot3D {
  point : Vec3
  radius : Double
  u_resolution : Int
  v_resolution : Int
  style : ShapeStyle
}

///|
pub fn Dot3D::new(
  point? : Vec3 = Vec3::zero(),
  radius? : Double = 0.08,
  u_resolution? : Int = 8,
  v_resolution? : Int = 8,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::white(),
    stroke=Rgba::white(),
  ),
) -> Dot3D {
  { point, radius, u_resolution, v_resolution, style }
}

///|
pub impl IntoObject for Dot3D with fn to_object(self) -> Object {
  into_object(
    Sphere::new(
      center=self.point,
      radius=self.radius,
      u_resolution=self.u_resolution,
      v_resolution=self.v_resolution,
      style=self.style,
      checkerboard_colors=[],
    ),
  )
}

///|
pub(all) struct Cube {
  side_length : Double
  style : ShapeStyle
}

///|
pub fn Cube::new(
  side_length? : Double = 2.0,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.75,
    stroke_width=0.0,
  ),
) -> Cube {
  { side_length, style }
}

///|
pub impl IntoObject for Cube with fn to_object(self) -> Object {
  cuboid_object(
    Vec3::new(x=self.side_length, y=self.side_length, z=self.side_length),
    self.style,
  )
}

///|
pub(all) struct Prism {
  dimensions : Vec3
  style : ShapeStyle
}

///|
pub fn Prism::new(
  dimensions? : Vec3 = Vec3::new(x=3.0, y=2.0, z=1.0),
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.75,
    stroke_width=0.0,
  ),
) -> Prism {
  { dimensions, style }
}

///|
pub impl IntoObject for Prism with fn to_object(self) -> Object {
  cuboid_object(self.dimensions, self.style)
}

///|
pub(all) struct Cylinder {
  radius : Double
  height : Double
  direction : Vec3
  v_min : Double
  v_max : Double
  show_ends : Bool
  u_resolution : Int
  v_resolution : Int
  style : ShapeStyle
  checkerboard_colors : Array[Rgba]
}

///|
pub fn Cylinder::new(
  radius? : Double = 1.0,
  height? : Double = 2.0,
  direction? : Vec3 = Vec3::unit_z(),
  v_min? : Double = 0.0,
  v_max? : Double = 2.0 * @math.PI,
  show_ends? : Bool = true,
  u_resolution? : Int = 24,
  v_resolution? : Int = 24,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [
    Rgba::manim_blue_d(),
    Rgba::manim_blue_e(),
  ],
) -> Cylinder {
  {
    radius,
    height,
    direction,
    v_min,
    v_max,
    show_ends,
    u_resolution,
    v_resolution,
    style,
    checkerboard_colors: checkerboard_colors.copy(),
  }
}

///|
pub fn Cylinder::surface(self : Cylinder) -> Surface {
  let radius = self.radius
  Surface::new(
    (height, angle) => {
      Vec3::new(
        x=radius * @math.cos(angle),
        y=radius * @math.sin(angle),
        z=height,
      )
    },
    u_min=0.0 - self.height / 2.0,
    u_max=self.height / 2.0,
    v_min=self.v_min,
    v_max=self.v_max,
    u_resolution=self.u_resolution,
    v_resolution=self.v_resolution,
    style=self.style,
    checkerboard_colors=self.checkerboard_colors,
  )
}

///|
pub impl IntoObject for Cylinder with fn to_object(self) -> Object {
  let children = [into_object(self.surface())]
  if self.show_ends {
    children.push(
      disk_object(
        self.radius,
        self.height / 2.0,
        self.v_resolution,
        true,
        self.style,
      ),
    )
    children.push(
      disk_object(
        self.radius,
        0.0 - self.height / 2.0,
        self.v_resolution,
        false,
        self.style,
      ),
    )
  }
  Object::group(children).with_transform(Transform::align_z_to(self.direction))
}

///|
pub(all) struct Cone {
  base_radius : Double
  height : Double
  direction : Vec3
  show_base : Bool
  v_min : Double
  v_max : Double
  u_resolution : Int
  v_resolution : Int
  style : ShapeStyle
  checkerboard_colors : Array[Rgba]
}

///|
pub fn Cone::new(
  base_radius? : Double = 1.0,
  height? : Double = 1.0,
  direction? : Vec3 = Vec3::unit_z(),
  show_base? : Bool = false,
  v_min? : Double = 0.0,
  v_max? : Double = 2.0 * @math.PI,
  u_resolution? : Int = 32,
  v_resolution? : Int = 32,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [],
) -> Cone {
  {
    base_radius,
    height,
    direction,
    show_base,
    v_min,
    v_max,
    u_resolution,
    v_resolution,
    style,
    checkerboard_colors: checkerboard_colors.copy(),
  }
}

///|
pub fn Cone::surface(self : Cone) -> Surface {
  let base_radius = self.base_radius
  let height = self.height
  Surface::new(
    (ratio, angle) => {
      Vec3::new(
        x=base_radius * ratio * @math.cos(angle),
        y=base_radius * ratio * @math.sin(angle),
        z=0.0 - height * ratio,
      )
    },
    u_min=0.0,
    u_max=1.0,
    v_min=self.v_min,
    v_max=self.v_max,
    u_resolution=self.u_resolution,
    v_resolution=self.v_resolution,
    style=self.style,
    checkerboard_colors=self.checkerboard_colors,
  )
}

///|
pub impl IntoObject for Cone with fn to_object(self) -> Object {
  let children = [into_object(self.surface())]
  if self.show_base {
    children.push(
      disk_object(
        self.base_radius,
        0.0 - self.height,
        self.v_resolution,
        false,
        self.style,
      ),
    )
  }
  Object::group(children).with_transform(Transform::align_z_to(self.direction))
}

///|
pub(all) struct Torus {
  major_radius : Double
  minor_radius : Double
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
pub fn Torus::new(
  major_radius? : Double = 3.0,
  minor_radius? : Double = 1.0,
  u_min? : Double = 0.0,
  u_max? : Double = 2.0 * @math.PI,
  v_min? : Double = 0.0,
  v_max? : Double = 2.0 * @math.PI,
  u_resolution? : Int = 24,
  v_resolution? : Int = 24,
  style? : ShapeStyle = ShapeStyle::surface(),
  checkerboard_colors? : Array[Rgba] = [
    Rgba::manim_blue_d(),
    Rgba::manim_blue_e(),
  ],
) -> Torus {
  {
    major_radius,
    minor_radius,
    u_min,
    u_max,
    v_min,
    v_max,
    u_resolution,
    v_resolution,
    style,
    checkerboard_colors: checkerboard_colors.copy(),
  }
}

///|
pub fn Torus::surface(self : Torus) -> Surface {
  let major_radius = self.major_radius
  let minor_radius = self.minor_radius
  Surface::new(
    (u, v) => {
      let radial = major_radius - minor_radius * @math.cos(v)
      Vec3::new(
        x=radial * @math.cos(u),
        y=radial * @math.sin(u),
        z=0.0 - minor_radius * @math.sin(v),
      )
    },
    u_min=self.u_min,
    u_max=self.u_max,
    v_min=self.v_min,
    v_max=self.v_max,
    u_resolution=self.u_resolution,
    v_resolution=self.v_resolution,
    style=self.style,
    checkerboard_colors=self.checkerboard_colors,
  )
}

///|
pub impl IntoObject for Torus with fn to_object(self) -> Object {
  into_object(self.surface())
}

///|
pub(all) struct Line3D {
  start : Vec3
  end : Vec3
  thickness : Double
  radial_resolution : Int
  style : ShapeStyle
}

///|
pub fn Line3D::new(
  start? : Vec3 = Vec3::new(x=-1.0, y=0.0),
  end? : Vec3 = Vec3::new(x=1.0, y=0.0),
  thickness? : Double = 0.02,
  radial_resolution? : Int = 24,
  style? : ShapeStyle = ShapeStyle::surface(),
) -> Line3D {
  { start, end, thickness, radial_resolution, style }
}

///|
pub fn Line3D::direction(self : Line3D) -> Vec3 {
  self.end.sub(self.start).normalize_or(Vec3::unit_z())
}

///|
pub fn Line3D::length(self : Line3D) -> Double {
  self.end.sub(self.start).length()
}

///|
pub impl IntoObject for Line3D with fn to_object(self) -> Object {
  let center = self.start.lerp(self.end, 0.5)
  let cylinder = into_object(
    Cylinder::new(
      radius=self.thickness,
      height=self.length(),
      direction=self.direction(),
      u_resolution=2,
      v_resolution=self.radial_resolution,
      style=self.style,
      checkerboard_colors=[],
    ),
  )
  cylinder.with_transform(cylinder.transform.then(Transform::translate(center)))
}

///|
pub(all) struct Arrow3D {
  start : Vec3
  end : Vec3
  thickness : Double
  tip_height : Double
  tip_radius : Double
  radial_resolution : Int
  style : ShapeStyle
}

///|
pub fn Arrow3D::new(
  start? : Vec3 = Vec3::new(x=-1.0, y=0.0),
  end? : Vec3 = Vec3::new(x=1.0, y=0.0),
  thickness? : Double = 0.02,
  tip_height? : Double = 0.3,
  tip_radius? : Double = 0.08,
  radial_resolution? : Int = 24,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::white(),
    stroke=Rgba::white(),
  ),
) -> Arrow3D {
  { start, end, thickness, tip_height, tip_radius, radial_resolution, style }
}

///|
pub impl IntoObject for Arrow3D with fn to_object(self) -> Object {
  let vector = self.end.sub(self.start)
  let length = vector.length()
  let direction = vector.normalize_or(Vec3::unit_z())
  let tip_height = if self.tip_height < length {
    self.tip_height
  } else {
    length
  }
  let shaft_end = self.end.sub(direction.scale(tip_height))
  let shaft = into_object(
    Line3D::new(
      start=self.start,
      end=shaft_end,
      thickness=self.thickness,
      radial_resolution=self.radial_resolution,
      style=self.style,
    ),
  )
  let tip = into_object(
    Cone::new(
      base_radius=self.tip_radius,
      height=tip_height,
      direction~,
      show_base=false,
      u_resolution=2,
      v_resolution=self.radial_resolution,
      style=self.style,
      checkerboard_colors=[],
    ),
  ).with_transform(
    Transform::align_z_to(direction).then(Transform::translate(self.end)),
  )
  Object::group([shaft, tip])
}

///|
fn cuboid_object(dimensions : Vec3, style : ShapeStyle) -> Object {
  let x = Double::abs(dimensions.x) / 2.0
  let y = Double::abs(dimensions.y) / 2.0
  let z = Double::abs(dimensions.z) / 2.0
  polyhedron_object(
    [
      Vec3::new(x=0.0 - x, y=0.0 - y, z=0.0 - z),
      Vec3::new(x~, y=0.0 - y, z=0.0 - z),
      Vec3::new(x~, y~, z=0.0 - z),
      Vec3::new(x=0.0 - x, y~, z=0.0 - z),
      Vec3::new(x=0.0 - x, y=0.0 - y, z~),
      Vec3::new(x~, y=0.0 - y, z~),
      Vec3::new(x~, y~, z~),
      Vec3::new(x=0.0 - x, y~, z~),
    ],
    [
      [0, 3, 2, 1],
      [4, 5, 6, 7],
      [0, 1, 5, 4],
      [1, 2, 6, 5],
      [2, 3, 7, 6],
      [3, 0, 4, 7],
    ],
    style,
  )
}

///|
fn polyhedron_object(
  vertices : Array[Vec3],
  faces : Array[Array[Int]],
  style : ShapeStyle,
) -> Object {
  Object::group(
    faces.filter_map(face => {
      let points = face.filter_map(index => vertices.get(index))
      if points.length() < 3 {
        None
      } else {
        Some(Object::mesh(Mesh3D::polygon(points), style~))
      }
    }),
  )
}

///|
fn disk_object(
  radius : Double,
  z : Double,
  resolution : Int,
  faces_up : Bool,
  style : ShapeStyle,
) -> Object {
  let count = positive_resolution(resolution)
  let points : Array[Vec3] = []
  for index in 0..<count {
    let angle_index = if faces_up { index } else { count - index - 1 }
    let angle = 2.0 * @math.PI * angle_index.to_double() / count.to_double()
    points.push(
      Vec3::new(x=radius * @math.cos(angle), y=radius * @math.sin(angle), z~),
    )
  }
  Object::mesh(Mesh3D::polygon(points), style~)
}
