///|
pub(all) struct Object {
  id : String
  transform : Transform
  z_index : Double
  node : Node
}

///|
pub(all) enum Node {
  Empty
  Group(Array[Object])
  Path(Path3D, ShapeStyle)
}

///|
pub fn Object::new(
  node~ : Node,
  id? : String = "",
  transform? : Transform = Transform::identity(),
  z_index? : Double = 0.0,
) -> Object {
  { id, transform, z_index, node }
}

///|
pub fn Object::empty(id? : String = "") -> Object {
  Object::new(node=Empty, id~)
}

///|
pub fn Object::group(children : Array[Object], id? : String = "") -> Object {
  Object::new(node=Group(children), id~)
}

///|
pub fn Object::path(
  path : Path3D,
  style? : ShapeStyle = ShapeStyle::default(),
  id? : String = "",
) -> Object {
  Object::new(node=Path(path, style), id~)
}

///|
pub fn Object::with_transform(self : Object, transform : Transform) -> Object {
  { id: self.id, transform, z_index: self.z_index, node: self.node }
}

///|
pub fn Object::with_z_index(self : Object, z_index : Double) -> Object {
  let node = match self.node {
    Group(children) => Group(children.map(child => child.with_z_index(z_index)))
    _ => self.node
  }
  { id: self.id, transform: self.transform, z_index, node }
}

///|
pub fn Object::set_fill(
  self : Object,
  color? : Rgba,
  opacity? : Double,
) -> Object {
  {
    id: self.id,
    transform: self.transform,
    z_index: self.z_index,
    node: self.node.set_fill(color?, opacity?),
  }
}

///|
pub fn Object::set_stroke(
  self : Object,
  color? : Rgba,
  width? : Double,
  opacity? : Double,
) -> Object {
  {
    id: self.id,
    transform: self.transform,
    z_index: self.z_index,
    node: self.node.set_stroke(color?, width?, opacity?),
  }
}

///|
pub fn Object::set_color(self : Object, color : Rgba) -> Object {
  {
    id: self.id,
    transform: self.transform,
    z_index: self.z_index,
    node: self.node.set_color(color),
  }
}

///|
pub fn Object::bounds(self : Object) -> Aabb? {
  self.node.bounds().map(bounds => bounds.transform(self.transform))
}

///|
pub fn Object::center(self : Object) -> Vec3 {
  self.critical_point(Vec3::zero())
}

///|
pub fn Object::critical_point(self : Object, direction : Vec3) -> Vec3 {
  self.bounds().map_or(Vec3::zero(), bounds => bounds.critical_point(direction))
}

///|
pub fn Node::bounds(self : Node) -> Aabb? {
  match self {
    Empty => None
    Path(path, _) => path.bounds()
    Group(children) =>
      children.fold(init=None, (bounds : Aabb?, child) => {
        merge_bounds(bounds, child.bounds())
      })
  }
}

///|
fn merge_bounds(a : Aabb?, b : Aabb?) -> Aabb? {
  match (a, b) {
    (None, _) => b
    (Some(current), None) => Some(current)
    (Some(current), Some(next)) => Some(current.union(next))
  }
}

///|
fn Node::set_fill(self : Node, color? : Rgba, opacity? : Double) -> Node {
  match self {
    Empty => Empty
    Path(path, style) => Path(path, style.set_fill(color?, opacity?))
    Group(children) =>
      Group(children.map(child => child.set_fill(color?, opacity?)))
  }
}

///|
fn Node::set_stroke(
  self : Node,
  color? : Rgba,
  width? : Double,
  opacity? : Double,
) -> Node {
  match self {
    Empty => Empty
    Path(path, style) => Path(path, style.set_stroke(color?, width?, opacity?))
    Group(children) =>
      Group(children.map(child => child.set_stroke(color?, width?, opacity?)))
  }
}

///|
fn Node::set_color(self : Node, color : Rgba) -> Node {
  match self {
    Empty => Empty
    Path(path, style) => Path(path, style.set_color(color))
    Group(children) => Group(children.map(child => child.set_color(color)))
  }
}
