///|
pub(all) struct Polyhedron {
  vertices : Array[Vec3]
  faces : Array[Array[Int]]
  style : ShapeStyle
}

///|
pub fn Polyhedron::new(
  vertices : Array[Vec3],
  faces : Array[Array[Int]],
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.5,
    stroke_width=0.0,
  ),
) -> Polyhedron raise MeshError {
  ignore(Mesh3D::new(vertices, faces.map(face => MeshFace3D::new(face))))
  { vertices: vertices.copy(), faces: copy_face_indices(faces), style }
}

///|
pub fn Polyhedron::face_count(self : Polyhedron) -> Int {
  self.faces.length()
}

///|
pub impl IntoObject for Polyhedron with fn to_object(self) -> Object {
  polyhedron_object(self.vertices, self.faces, self.style)
}

///|
pub(all) struct Tetrahedron {
  edge_length : Double
  style : ShapeStyle
}

///|
pub fn Tetrahedron::new(
  edge_length? : Double = 1.0,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.5,
    stroke_width=0.0,
  ),
) -> Tetrahedron {
  { edge_length, style }
}

///|
pub impl IntoObject for Tetrahedron with fn to_object(self) -> Object {
  let unit = self.edge_length * 2.0.sqrt() / 4.0
  polyhedron_object(
    [
      Vec3::new(x=unit, y=unit, z=unit),
      Vec3::new(x=unit, y=0.0 - unit, z=0.0 - unit),
      Vec3::new(x=0.0 - unit, y=unit, z=0.0 - unit),
      Vec3::new(x=0.0 - unit, y=0.0 - unit, z=unit),
    ],
    [[0, 1, 2], [3, 0, 2], [0, 3, 1], [3, 2, 1]],
    self.style,
  )
}

///|
pub(all) struct Octahedron {
  edge_length : Double
  style : ShapeStyle
}

///|
pub fn Octahedron::new(
  edge_length? : Double = 1.0,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.5,
    stroke_width=0.0,
  ),
) -> Octahedron {
  { edge_length, style }
}

///|
pub impl IntoObject for Octahedron with fn to_object(self) -> Object {
  let unit = self.edge_length * 2.0.sqrt() / 2.0
  polyhedron_object(
    [
      Vec3::new(x=unit, y=0.0),
      Vec3::new(x=0.0 - unit, y=0.0),
      Vec3::new(x=0.0, y=unit),
      Vec3::new(x=0.0, y=0.0 - unit),
      Vec3::new(x=0.0, y=0.0, z=unit),
      Vec3::new(x=0.0, y=0.0, z=0.0 - unit),
    ],
    [
      [2, 4, 1],
      [0, 4, 2],
      [4, 3, 0],
      [1, 3, 4],
      [3, 5, 0],
      [1, 5, 3],
      [2, 5, 1],
      [0, 5, 2],
    ],
    self.style,
  )
}

///|
pub(all) struct Icosahedron {
  edge_length : Double
  style : ShapeStyle
}

///|
pub fn Icosahedron::new(
  edge_length? : Double = 1.0,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.5,
    stroke_width=0.0,
  ),
) -> Icosahedron {
  { edge_length, style }
}

///|
pub impl IntoObject for Icosahedron with fn to_object(self) -> Object {
  let a = self.edge_length * (1.0 + 5.0.sqrt()) / 4.0
  let b = self.edge_length / 2.0
  polyhedron_object(
    [
      Vec3::new(x=0.0, y=b, z=a),
      Vec3::new(x=0.0, y=0.0 - b, z=a),
      Vec3::new(x=0.0, y=b, z=0.0 - a),
      Vec3::new(x=0.0, y=0.0 - b, z=0.0 - a),
      Vec3::new(x=b, y=a),
      Vec3::new(x=b, y=0.0 - a),
      Vec3::new(x=0.0 - b, y=a),
      Vec3::new(x=0.0 - b, y=0.0 - a),
      Vec3::new(x=a, y=0.0, z=b),
      Vec3::new(x=a, y=0.0, z=0.0 - b),
      Vec3::new(x=0.0 - a, y=0.0, z=b),
      Vec3::new(x=0.0 - a, y=0.0, z=0.0 - b),
    ],
    [
      [1, 8, 0],
      [1, 5, 7],
      [8, 5, 1],
      [7, 3, 5],
      [5, 9, 3],
      [8, 9, 5],
      [3, 2, 9],
      [9, 4, 2],
      [8, 4, 9],
      [0, 4, 8],
      [6, 4, 0],
      [6, 2, 4],
      [11, 2, 6],
      [3, 11, 2],
      [0, 6, 10],
      [10, 1, 0],
      [10, 7, 1],
      [11, 7, 3],
      [10, 11, 7],
      [10, 6, 11],
    ],
    self.style,
  )
}

///|
pub(all) struct Dodecahedron {
  edge_length : Double
  style : ShapeStyle
}

///|
pub fn Dodecahedron::new(
  edge_length? : Double = 1.0,
  style? : ShapeStyle = ShapeStyle::surface(
    fill=Rgba::manim_blue(),
    fill_opacity=0.5,
    stroke_width=0.0,
  ),
) -> Dodecahedron {
  { edge_length, style }
}

///|
pub impl IntoObject for Dodecahedron with fn to_object(self) -> Object {
  let root5 = 5.0.sqrt()
  let a = self.edge_length * (1.0 + root5) / 4.0
  let b = self.edge_length * (3.0 + root5) / 4.0
  let c = self.edge_length / 2.0
  polyhedron_object(
    [
      Vec3::new(x=a, y=a, z=a),
      Vec3::new(x=a, y=a, z=0.0 - a),
      Vec3::new(x=a, y=0.0 - a, z=a),
      Vec3::new(x=a, y=0.0 - a, z=0.0 - a),
      Vec3::new(x=0.0 - a, y=a, z=a),
      Vec3::new(x=0.0 - a, y=a, z=0.0 - a),
      Vec3::new(x=0.0 - a, y=0.0 - a, z=a),
      Vec3::new(x=0.0 - a, y=0.0 - a, z=0.0 - a),
      Vec3::new(x=0.0, y=c, z=b),
      Vec3::new(x=0.0, y=c, z=0.0 - b),
      Vec3::new(x=0.0, y=0.0 - c, z=0.0 - b),
      Vec3::new(x=0.0, y=0.0 - c, z=b),
      Vec3::new(x=c, y=b),
      Vec3::new(x=0.0 - c, y=b),
      Vec3::new(x=c, y=0.0 - b),
      Vec3::new(x=0.0 - c, y=0.0 - b),
      Vec3::new(x=b, y=0.0, z=c),
      Vec3::new(x=0.0 - b, y=0.0, z=c),
      Vec3::new(x=b, y=0.0, z=0.0 - c),
      Vec3::new(x=0.0 - b, y=0.0, z=0.0 - c),
    ],
    [
      [18, 16, 0, 12, 1],
      [3, 18, 16, 2, 14],
      [3, 10, 9, 1, 18],
      [1, 9, 5, 13, 12],
      [0, 8, 4, 13, 12],
      [2, 16, 0, 8, 11],
      [4, 17, 6, 11, 8],
      [17, 19, 5, 13, 4],
      [19, 7, 15, 6, 17],
      [6, 15, 14, 2, 11],
      [19, 5, 9, 10, 7],
      [7, 10, 3, 14, 15],
    ],
    self.style,
  )
}

///|
fn copy_face_indices(faces : Array[Array[Int]]) -> Array[Array[Int]] {
  faces.map(face => face.copy())
}
