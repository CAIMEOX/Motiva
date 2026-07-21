///|
pub(all) suberror MeshError {
  FaceHasTooFewVertices(face_index~ : Int, vertex_count~ : Int)
  VertexIndexOutOfBounds(
    face_index~ : Int,
    vertex_index~ : Int,
    vertex_count~ : Int
  )
}

///|
pub(all) struct MeshFace3D {
  indices : Array[Int]
}

///|
pub fn MeshFace3D::new(indices : Array[Int]) -> MeshFace3D {
  { indices: indices.copy() }
}

///|
pub(all) struct Mesh3D {
  vertices : Array[Vec3]
  faces : Array[MeshFace3D]
}

///|
pub fn Mesh3D::new(
  vertices : Array[Vec3],
  faces : Array[MeshFace3D],
) -> Mesh3D raise MeshError {
  validate_mesh(vertices, faces)
  { vertices: vertices.copy(), faces: copy_mesh_faces(faces) }
}

///|
pub fn Mesh3D::polygon(vertices : Array[Vec3]) -> Mesh3D {
  let indices : Array[Int] = []
  for index in 0..<vertices.length() {
    indices.push(index)
  }
  let faces = if vertices.length() < 3 {
    []
  } else {
    [MeshFace3D::new(indices)]
  }
  { vertices: vertices.copy(), faces }
}

///|
pub fn Mesh3D::vertex_count(self : Mesh3D) -> Int {
  self.vertices.length()
}

///|
pub fn Mesh3D::face_count(self : Mesh3D) -> Int {
  self.faces.length()
}

///|
pub fn Mesh3D::is_empty(self : Mesh3D) -> Bool {
  self.vertices.length() == 0 || self.faces.length() == 0
}

///|
pub fn Mesh3D::face_vertices(self : Mesh3D, face_index : Int) -> Array[Vec3]? {
  self.faces
  .get(face_index)
  .map(face => face.indices.filter_map(index => self.vertices.get(index)))
}

///|
pub fn Mesh3D::bounds(self : Mesh3D) -> Aabb? {
  self.vertices.fold(init=None, (bounds : Aabb?, point) => {
    match bounds {
      None => Some(Aabb::point(point))
      Some(current) => Some(current.include_point(point))
    }
  })
}

///|
pub fn Mesh3D::map_vertices(
  self : Mesh3D,
  transform : (Vec3) -> Vec3,
) -> Mesh3D {
  { vertices: self.vertices.map(transform), faces: copy_mesh_faces(self.faces) }
}

///|
pub fn Mesh3D::same_topology(self : Mesh3D, other : Mesh3D) -> Bool {
  self.vertices.length() == other.vertices.length() &&
  self.faces.length() == other.faces.length() &&
  self.faces
  .iter()
  .zip(other.faces.iter())
  .all(pair => pair.0.indices == pair.1.indices)
}

///|
pub fn Mesh3D::lerp(self : Mesh3D, other : Mesh3D, alpha : Double) -> Mesh3D? {
  if !self.same_topology(other) {
    None
  } else {
    let vertices = self.vertices
      .iter()
      .zip(other.vertices.iter())
      .map(pair => pair.0.lerp(pair.1, alpha))
      .to_array()
    Some({ vertices, faces: copy_mesh_faces(self.faces) })
  }
}

///|
pub fn Mesh3D::prefix(self : Mesh3D, alpha : Double) -> Mesh3D {
  if alpha >= 1.0 || self.faces.length() != 1 {
    self
  } else {
    match self.faces[0].indices {
      [] => self
      indices => {
        let t = if alpha.is_nan() || alpha < 0.0 { 0.0 } else { alpha }
        let scaled = t * indices.length().to_double()
        let reached = scaled.floor().to_int()
        let edge = if reached >= indices.length() {
          indices.length() - 1
        } else {
          reached
        }
        let residue = scaled - edge.to_double()
        let edge_start = self.vertices[indices[edge]]
        let edge_end = self.vertices[indices[(edge + 1) % indices.length()]]
        let current = edge_start.lerp(edge_end, residue)
        let vertices = self.vertices.copy()
        for offset in 0..<indices.length() {
          if offset > edge {
            vertices[indices[offset]] = current
          }
        }
        { vertices, faces: copy_mesh_faces(self.faces) }
      }
    }
  }
}

///|
fn validate_mesh(
  vertices : Array[Vec3],
  faces : Array[MeshFace3D],
) -> Unit raise MeshError {
  for face_index in 0..<faces.length() {
    let face = faces[face_index]
    if face.indices.length() < 3 {
      raise FaceHasTooFewVertices(
        face_index~,
        vertex_count=face.indices.length(),
      )
    }
    for vertex_index in face.indices {
      if vertex_index < 0 || vertex_index >= vertices.length() {
        raise VertexIndexOutOfBounds(
          face_index~,
          vertex_index~,
          vertex_count=vertices.length(),
        )
      }
    }
  }
}

///|
fn copy_mesh_faces(faces : Array[MeshFace3D]) -> Array[MeshFace3D] {
  faces.map(face => MeshFace3D::new(face.indices))
}
