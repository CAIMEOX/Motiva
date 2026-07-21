///|
pub(all) struct Vec3 {
  x : Double
  y : Double
  z : Double
}

///|
pub fn Vec3::new(x~ : Double, y~ : Double, z? : Double = 0.0) -> Vec3 {
  { x, y, z }
}

///|
pub fn Vec3::zero() -> Vec3 {
  { x: 0.0, y: 0.0, z: 0.0 }
}

///|
pub fn Vec3::unit_x() -> Vec3 {
  { x: 1.0, y: 0.0, z: 0.0 }
}

///|
pub fn Vec3::unit_y() -> Vec3 {
  { x: 0.0, y: 1.0, z: 0.0 }
}

///|
pub fn Vec3::unit_z() -> Vec3 {
  { x: 0.0, y: 0.0, z: 1.0 }
}

///|
pub fn Vec3::add(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x + other.x, y: self.y + other.y, z: self.z + other.z }
}

///|
pub fn Vec3::sub(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x - other.x, y: self.y - other.y, z: self.z - other.z }
}

///|
pub fn Vec3::scale(self : Vec3, factor : Double) -> Vec3 {
  { x: self.x * factor, y: self.y * factor, z: self.z * factor }
}

///|
pub fn Vec3::dot(self : Vec3, other : Vec3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
pub fn Vec3::cross(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///|
pub fn Vec3::lerp(self : Vec3, other : Vec3, alpha : Double) -> Vec3 {
  self.add(other.sub(self).scale(alpha))
}

///|
pub fn Vec3::length_squared(self : Vec3) -> Double {
  self.dot(self)
}

///|
pub fn Vec3::length(self : Vec3) -> Double {
  self.length_squared().sqrt()
}

///|
pub fn Vec3::normalize_or(self : Vec3, fallback : Vec3) -> Vec3 {
  let length = self.length()
  if length <= 0.0 || length.is_nan() {
    fallback
  } else {
    self.scale(1.0 / length)
  }
}

///|
pub fn Vec3::min(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: if self.x < other.x {
      self.x
    } else {
      other.x
    },
    y: if self.y < other.y {
      self.y
    } else {
      other.y
    },
    z: if self.z < other.z {
      self.z
    } else {
      other.z
    },
  }
}

///|
pub fn Vec3::max(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: if self.x > other.x {
      self.x
    } else {
      other.x
    },
    y: if self.y > other.y {
      self.y
    } else {
      other.y
    },
    z: if self.z > other.z {
      self.z
    } else {
      other.z
    },
  }
}

///|
pub(all) struct Aabb {
  min : Vec3
  max : Vec3
}

///|
pub fn Aabb::point(point : Vec3) -> Aabb {
  { min: point, max: point }
}

///|
pub fn Aabb::new(min~ : Vec3, max~ : Vec3) -> Aabb {
  { min, max }
}

///|
pub fn Aabb::include_point(self : Aabb, point : Vec3) -> Aabb {
  { min: self.min.min(point), max: self.max.max(point) }
}

///|
pub fn Aabb::union(self : Aabb, other : Aabb) -> Aabb {
  { min: self.min.min(other.min), max: self.max.max(other.max) }
}

///|
pub fn Aabb::width(self : Aabb) -> Double {
  self.max.x - self.min.x
}

///|
pub fn Aabb::height(self : Aabb) -> Double {
  self.max.y - self.min.y
}

///|
pub fn Aabb::depth(self : Aabb) -> Double {
  self.max.z - self.min.z
}

///|
pub fn Aabb::center(self : Aabb) -> Vec3 {
  Vec3::new(
    x=(self.min.x + self.max.x) / 2.0,
    y=(self.min.y + self.max.y) / 2.0,
    z=(self.min.z + self.max.z) / 2.0,
  )
}

///|
pub fn Aabb::critical_point(self : Aabb, direction : Vec3) -> Vec3 {
  Vec3::new(
    x=choose_critical_coordinate(self.min.x, self.max.x, direction.x),
    y=choose_critical_coordinate(self.min.y, self.max.y, direction.y),
    z=choose_critical_coordinate(self.min.z, self.max.z, direction.z),
  )
}

///|
fn choose_critical_coordinate(
  min : Double,
  max : Double,
  key : Double,
) -> Double {
  if key < 0.0 {
    min
  } else if key > 0.0 {
    max
  } else {
    (min + max) / 2.0
  }
}

///|
pub fn Aabb::transform(self : Aabb, transform : Transform) -> Aabb {
  let p000 = transform.apply_point(self.min)
  let p100 = transform.apply_point(
    Vec3::new(x=self.max.x, y=self.min.y, z=self.min.z),
  )
  let p010 = transform.apply_point(
    Vec3::new(x=self.min.x, y=self.max.y, z=self.min.z),
  )
  let p110 = transform.apply_point(
    Vec3::new(x=self.max.x, y=self.max.y, z=self.min.z),
  )
  let p001 = transform.apply_point(
    Vec3::new(x=self.min.x, y=self.min.y, z=self.max.z),
  )
  let p101 = transform.apply_point(
    Vec3::new(x=self.max.x, y=self.min.y, z=self.max.z),
  )
  let p011 = transform.apply_point(
    Vec3::new(x=self.min.x, y=self.max.y, z=self.max.z),
  )
  let p111 = transform.apply_point(self.max)
  Aabb::point(p000)
  .include_point(p100)
  .include_point(p010)
  .include_point(p110)
  .include_point(p001)
  .include_point(p101)
  .include_point(p011)
  .include_point(p111)
}

///|
pub(all) struct Transform {
  m00 : Double
  m01 : Double
  m02 : Double
  m03 : Double
  m10 : Double
  m11 : Double
  m12 : Double
  m13 : Double
  m20 : Double
  m21 : Double
  m22 : Double
  m23 : Double
}

///|
pub fn Transform::identity() -> Transform {
  {
    m00: 1.0,
    m01: 0.0,
    m02: 0.0,
    m03: 0.0,
    m10: 0.0,
    m11: 1.0,
    m12: 0.0,
    m13: 0.0,
    m20: 0.0,
    m21: 0.0,
    m22: 1.0,
    m23: 0.0,
  }
}

///|
pub fn Transform::translate(offset : Vec3) -> Transform {
  {
    m00: 1.0,
    m01: 0.0,
    m02: 0.0,
    m03: offset.x,
    m10: 0.0,
    m11: 1.0,
    m12: 0.0,
    m13: offset.y,
    m20: 0.0,
    m21: 0.0,
    m22: 1.0,
    m23: offset.z,
  }
}

///|
pub fn Transform::scale(
  sx~ : Double,
  sy~ : Double,
  sz? : Double = 1.0,
) -> Transform {
  {
    m00: sx,
    m01: 0.0,
    m02: 0.0,
    m03: 0.0,
    m10: 0.0,
    m11: sy,
    m12: 0.0,
    m13: 0.0,
    m20: 0.0,
    m21: 0.0,
    m22: sz,
    m23: 0.0,
  }
}

///|
pub fn Transform::rotate_x(angle~ : Double) -> Transform {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  {
    m00: 1.0,
    m01: 0.0,
    m02: 0.0,
    m03: 0.0,
    m10: 0.0,
    m11: c,
    m12: 0.0 - s,
    m13: 0.0,
    m20: 0.0,
    m21: s,
    m22: c,
    m23: 0.0,
  }
}

///|
pub fn Transform::rotate_y(angle~ : Double) -> Transform {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  {
    m00: c,
    m01: 0.0,
    m02: s,
    m03: 0.0,
    m10: 0.0,
    m11: 1.0,
    m12: 0.0,
    m13: 0.0,
    m20: 0.0 - s,
    m21: 0.0,
    m22: c,
    m23: 0.0,
  }
}

///|
pub fn Transform::rotate_z(angle~ : Double) -> Transform {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  {
    m00: c,
    m01: 0.0 - s,
    m02: 0.0,
    m03: 0.0,
    m10: s,
    m11: c,
    m12: 0.0,
    m13: 0.0,
    m20: 0.0,
    m21: 0.0,
    m22: 1.0,
    m23: 0.0,
  }
}

///|
pub fn Transform::rotate(angle~ : Double) -> Transform {
  Transform::rotate_z(angle~)
}

///|
pub fn Transform::rotate_axis(angle~ : Double, axis~ : Vec3) -> Transform {
  let unit = axis.normalize_or(Vec3::unit_z())
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  let t = 1.0 - c
  {
    m00: c + unit.x * unit.x * t,
    m01: unit.x * unit.y * t - unit.z * s,
    m02: unit.x * unit.z * t + unit.y * s,
    m03: 0.0,
    m10: unit.y * unit.x * t + unit.z * s,
    m11: c + unit.y * unit.y * t,
    m12: unit.y * unit.z * t - unit.x * s,
    m13: 0.0,
    m20: unit.z * unit.x * t - unit.y * s,
    m21: unit.z * unit.y * t + unit.x * s,
    m22: c + unit.z * unit.z * t,
    m23: 0.0,
  }
}

///|
pub fn Transform::align_z_to(direction : Vec3) -> Transform {
  let target = direction.normalize_or(Vec3::unit_z())
  let cosine = if target.z < -1.0 {
    -1.0
  } else if target.z > 1.0 {
    1.0
  } else {
    target.z
  }
  if cosine > 0.999999999999 {
    Transform::identity()
  } else if cosine < -0.999999999999 {
    Transform::rotate_x(angle=@math.PI)
  } else {
    Transform::rotate_axis(
      angle=@math.acos(cosine),
      axis=Vec3::unit_z().cross(target),
    )
  }
}

///|
pub fn Transform::rotate_about(
  angle~ : Double,
  axis~ : Vec3,
  point~ : Vec3,
) -> Transform {
  Transform::translate(point.scale(-1.0))
  .then(Transform::rotate_axis(angle~, axis~))
  .then(Transform::translate(point))
}

///|
pub fn Transform::then(self : Transform, next : Transform) -> Transform {
  {
    m00: next.m00 * self.m00 + next.m01 * self.m10 + next.m02 * self.m20,
    m01: next.m00 * self.m01 + next.m01 * self.m11 + next.m02 * self.m21,
    m02: next.m00 * self.m02 + next.m01 * self.m12 + next.m02 * self.m22,
    m03: next.m00 * self.m03 +
    next.m01 * self.m13 +
    next.m02 * self.m23 +
    next.m03,
    m10: next.m10 * self.m00 + next.m11 * self.m10 + next.m12 * self.m20,
    m11: next.m10 * self.m01 + next.m11 * self.m11 + next.m12 * self.m21,
    m12: next.m10 * self.m02 + next.m11 * self.m12 + next.m12 * self.m22,
    m13: next.m10 * self.m03 +
    next.m11 * self.m13 +
    next.m12 * self.m23 +
    next.m13,
    m20: next.m20 * self.m00 + next.m21 * self.m10 + next.m22 * self.m20,
    m21: next.m20 * self.m01 + next.m21 * self.m11 + next.m22 * self.m21,
    m22: next.m20 * self.m02 + next.m21 * self.m12 + next.m22 * self.m22,
    m23: next.m20 * self.m03 +
    next.m21 * self.m13 +
    next.m22 * self.m23 +
    next.m23,
  }
}

///|
pub fn Transform::apply_point(self : Transform, point : Vec3) -> Vec3 {
  {
    x: self.m00 * point.x + self.m01 * point.y + self.m02 * point.z + self.m03,
    y: self.m10 * point.x + self.m11 * point.y + self.m12 * point.z + self.m13,
    z: self.m20 * point.x + self.m21 * point.y + self.m22 * point.z + self.m23,
  }
}

///|
pub fn Transform::apply_vec(self : Transform, vector : Vec3) -> Vec3 {
  {
    x: self.m00 * vector.x + self.m01 * vector.y + self.m02 * vector.z,
    y: self.m10 * vector.x + self.m11 * vector.y + self.m12 * vector.z,
    z: self.m20 * vector.x + self.m21 * vector.y + self.m22 * vector.z,
  }
}
