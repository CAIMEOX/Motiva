///|
pub(all) struct Vec2 {
  x : Double
  y : Double
}

///|
pub fn Vec2::new(x~ : Double, y~ : Double) -> Vec2 {
  { x, y }
}

///|
pub fn Vec2::zero() -> Vec2 {
  { x: 0.0, y: 0.0 }
}

///|
pub fn Vec2::add(self : Vec2, other : Vec2) -> Vec2 {
  { x: self.x + other.x, y: self.y + other.y }
}

///|
pub fn Vec2::sub(self : Vec2, other : Vec2) -> Vec2 {
  { x: self.x - other.x, y: self.y - other.y }
}

///|
pub fn Vec2::scale(self : Vec2, factor : Double) -> Vec2 {
  { x: self.x * factor, y: self.y * factor }
}

///|
pub fn Vec2::min(self : Vec2, other : Vec2) -> Vec2 {
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
  }
}

///|
pub fn Vec2::max(self : Vec2, other : Vec2) -> Vec2 {
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
  }
}

///|
pub(all) struct Aabb {
  min : Vec2
  max : Vec2
}

///|
pub fn Aabb::point(point : Vec2) -> Aabb {
  { min: point, max: point }
}

///|
pub fn Aabb::new(min~ : Vec2, max~ : Vec2) -> Aabb {
  { min, max }
}

///|
pub fn Aabb::include_point(self : Aabb, point : Vec2) -> Aabb {
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
pub fn Aabb::transform(self : Aabb, transform : Transform) -> Aabb {
  let p0 = transform.apply_point(self.min)
  let p1 = transform.apply_point(Vec2::new(x=self.max.x, y=self.min.y))
  let p2 = transform.apply_point(self.max)
  let p3 = transform.apply_point(Vec2::new(x=self.min.x, y=self.max.y))
  Aabb::point(p0).include_point(p1).include_point(p2).include_point(p3)
}

///|
pub(all) struct Transform {
  m00 : Double
  m01 : Double
  m02 : Double
  m10 : Double
  m11 : Double
  m12 : Double
}

///|
pub fn Transform::identity() -> Transform {
  { m00: 1.0, m01: 0.0, m02: 0.0, m10: 0.0, m11: 1.0, m12: 0.0 }
}

///|
pub fn Transform::translate(offset : Vec2) -> Transform {
  { m00: 1.0, m01: 0.0, m02: offset.x, m10: 0.0, m11: 1.0, m12: offset.y }
}

///|
pub fn Transform::scale(sx~ : Double, sy~ : Double) -> Transform {
  { m00: sx, m01: 0.0, m02: 0.0, m10: 0.0, m11: sy, m12: 0.0 }
}

///|
pub fn Transform::rotate(angle~ : Double) -> Transform {
  let c = @math.cos(angle)
  let s = @math.sin(angle)
  { m00: c, m01: 0.0 - s, m02: 0.0, m10: s, m11: c, m12: 0.0 }
}

///|
pub fn Transform::then(self : Transform, next : Transform) -> Transform {
  {
    m00: next.m00 * self.m00 + next.m01 * self.m10,
    m01: next.m00 * self.m01 + next.m01 * self.m11,
    m02: next.m00 * self.m02 + next.m01 * self.m12 + next.m02,
    m10: next.m10 * self.m00 + next.m11 * self.m10,
    m11: next.m10 * self.m01 + next.m11 * self.m11,
    m12: next.m10 * self.m02 + next.m11 * self.m12 + next.m12,
  }
}

///|
pub fn Transform::apply_point(self : Transform, point : Vec2) -> Vec2 {
  {
    x: self.m00 * point.x + self.m01 * point.y + self.m02,
    y: self.m10 * point.x + self.m11 * point.y + self.m12,
  }
}

///|
pub fn Transform::apply_vec(self : Transform, vector : Vec2) -> Vec2 {
  {
    x: self.m00 * vector.x + self.m01 * vector.y,
    y: self.m10 * vector.x + self.m11 * vector.y,
  }
}
