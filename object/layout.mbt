///|
pub fn Object::move_to(
  self : Object,
  point : Vec3,
  aligned_edge? : Vec3 = Vec3::zero(),
) -> Object {
  self.translate(point.sub(self.critical_point(aligned_edge)))
}

///|
pub fn Object::next_to(
  self : Object,
  other : Object,
  direction? : Vec3 = Vec3::new(x=1.0, y=0.0),
  buff? : Double = 0.25,
  aligned_edge? : Vec3 = Vec3::zero(),
) -> Object {
  let target_point = other.critical_point(aligned_edge.add(direction))
  let point_to_align = self.critical_point(aligned_edge.sub(direction))
  self.translate(target_point.sub(point_to_align).add(direction.scale(buff)))
}

///|
pub fn Object::align_to(
  self : Object,
  other : Object,
  direction~ : Vec3,
) -> Object {
  let target = other.critical_point(direction)
  let current = self.critical_point(direction)
  self.translate(
    Vec3::new(
      x=if direction.x == 0.0 { 0.0 } else { target.x - current.x },
      y=if direction.y == 0.0 { 0.0 } else { target.y - current.y },
      z=if direction.z == 0.0 { 0.0 } else { target.z - current.z },
    ),
  )
}

///|
pub fn Object::arrange(
  self : Object,
  direction? : Vec3 = Vec3::new(x=1.0, y=0.0),
  buff? : Double = 0.25,
  center? : Bool = true,
  aligned_edge? : Vec3 = Vec3::zero(),
) -> Object {
  match self.node {
    Group([]) => self
    Group(children) => {
      let world_children = children.map(child => {
        child.with_transform(child.transform.then(self.transform))
      })
      let arranged : Array[Object] = []
      for child in world_children {
        let positioned = arranged
          .last()
          .map_or(child, previous => {
            child.next_to(previous, direction~, buff~, aligned_edge~)
          })
        arranged.push(positioned)
      }
      let group = Object::new(
        node=Group(arranged),
        id=self.id,
        transform=Transform::identity(),
        z_index=self.z_index,
      )
      if center {
        group.move_to(Vec3::zero())
      } else {
        group
      }
    }
    _ => self
  }
}

///|
fn Object::translate(self : Object, offset : Vec3) -> Object {
  self.with_transform(self.transform.then(Transform::translate(offset)))
}
