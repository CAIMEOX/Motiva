///|
pub(all) suberror ObjectAlignmentError {
  Path(PathEvalError)
  IncompatibleNodeKinds
  MeshTopologyMismatch
  AlignmentInvariantBroken
  InvalidMotionPathPointCount(expected~ : Int, actual~ : Int)
}

///|
pub(all) enum MotionPath {
  Straight
  Arc(angle~ : Double, axis~ : Vec3)
  Custom((Array[Vec3], Array[Vec3], Double) -> Array[Vec3])
}

///|
pub fn MotionPath::straight() -> MotionPath {
  Straight
}

///|
pub fn MotionPath::arc(
  angle~ : Double,
  axis? : Vec3 = Vec3::unit_z(),
) -> MotionPath {
  Arc(angle~, axis~)
}

///|
pub fn MotionPath::custom(
  sample : (Array[Vec3], Array[Vec3], Double) -> Array[Vec3],
) -> MotionPath {
  Custom(sample)
}

///|
pub struct AlignedObjectPair {
  priv start : Object
  priv target : Object
}

///|
pub fn AlignedObjectPair::start(self : AlignedObjectPair) -> Object {
  self.start.copy()
}

///|
pub fn AlignedObjectPair::target(self : AlignedObjectPair) -> Object {
  self.target.copy()
}

///|
pub fn AlignedObjectPair::interpolate(
  self : AlignedObjectPair,
  alpha : Double,
  path? : MotionPath = MotionPath::straight(),
) -> Object raise ObjectAlignmentError {
  interpolate_aligned_object(
    self.start,
    self.target,
    clamp_alignment_alpha(alpha),
    path,
  )
}

///|
pub fn AlignedObjectPair::interpolate_family(
  self : AlignedObjectPair,
  alpha : Double,
  path? : MotionPath = MotionPath::straight(),
  family_alpha : (Int, Int) -> Double,
) -> Object raise ObjectAlignmentError {
  let family_size = renderable_family_size(self.start)
  interpolate_aligned_family_object(
    self.start,
    self.target,
    clamp_alignment_alpha(alpha),
    path,
    family_alpha,
    0,
    family_size,
  ).0
}

///|
pub fn Object::align_for_interpolation(
  self : Object,
  target : Object,
) -> AlignedObjectPair raise ObjectAlignmentError {
  let start = bake_object_transform(self, Transform::identity())
  let target = bake_object_transform(target, Transform::identity())
  let (start, target) = align_objects(start, target)
  { start, target }
}

///|
fn bake_object_transform(
  object : Object,
  parent_transform : Transform,
) -> Object raise ObjectAlignmentError {
  let world_transform = object.transform.then(parent_transform)
  let node = match object.node {
    Empty => Empty
    Path(path, style) => {
      let buffer = path.eval() catch { error => raise Path(error) }
      Path(
        buffer.map_points(point => world_transform.apply_point(point)).to_path(),
        style,
      )
    }
    Mesh(mesh, style) =>
      Mesh(
        mesh.map_vertices(point => world_transform.apply_point(point)),
        style,
      )
    Group(children) => {
      let baked : Array[Object] = []
      for child in children {
        baked.push(bake_object_transform(child, world_transform))
      }
      Group(baked)
    }
  }
  Object::new(node~, z_index=object.z_index)
}

///|
fn align_objects(
  start : Object,
  target : Object,
) -> (Object, Object) raise ObjectAlignmentError {
  let (start_node, target_node) = match (start.node, target.node) {
    (Empty, Empty) => (Empty, Empty)
    (Empty, target_node) =>
      (degenerate_node(target_node, Vec3::zero()), target_node)
    (start_node, Empty) =>
      (start_node, degenerate_node(start_node, Vec3::zero()))
    (Path(start_path, start_style), Path(target_path, target_style)) => {
      let start_buffer = start_path.eval() catch { error => raise Path(error) }
      let target_buffer = target_path.eval() catch {
        error => raise Path(error)
      }
      let (start_buffer, target_buffer) = start_buffer.normalize_pair(
        target_buffer,
      )
      let (start_style, target_style) = align_styles(start_style, target_style)
      (
        Path(start_buffer.to_path(), start_style),
        Path(target_buffer.to_path(), target_style),
      )
    }
    (Mesh(start_mesh, start_style), Mesh(target_mesh, target_style)) =>
      if start_mesh.same_topology(target_mesh) {
        let (start_style, target_style) = align_styles(
          start_style, target_style,
        )
        (Mesh(start_mesh, start_style), Mesh(target_mesh, target_style))
      } else {
        raise MeshTopologyMismatch
      }
    (Group(start_children), Group(target_children)) => {
      let (start_children, target_children) = equalize_children(
        start_children, target_children,
      )
      let aligned_start : Array[Object] = []
      let aligned_target : Array[Object] = []
      for index in 0..<start_children.length() {
        match (start_children.get(index), target_children.get(index)) {
          (Some(start_child), Some(target_child)) => {
            let (start_child, target_child) = align_objects(
              start_child, target_child,
            )
            aligned_start.push(start_child)
            aligned_target.push(target_child)
          }
          _ => ()
        }
      }
      (Group(aligned_start), Group(aligned_target))
    }
    (Group(_), _) => align_nodes_as_groups(start.node, target)
    (_, Group(_)) => {
      let (target_node, start_node) = align_nodes_as_groups(target.node, start)
      (start_node, target_node)
    }
    _ => raise IncompatibleNodeKinds
  }
  (
    Object::new(
      node=start_node,
      transform=start.transform,
      z_index=start.z_index,
    ),
    Object::new(
      node=target_node,
      transform=target.transform,
      z_index=target.z_index,
    ),
  )
}

///|
fn align_nodes_as_groups(
  group : Node,
  leaf : Object,
) -> (Node, Node) raise ObjectAlignmentError {
  guard group is Group(children) else { raise IncompatibleNodeKinds }
  let (start, target) = align_objects(
    Object::new(node=Group(children)),
    Object::group([leaf]),
  )
  (start.node, target.node)
}

///|
fn equalize_children(
  start : Array[Object],
  target : Array[Object],
) -> (Array[Object], Array[Object]) raise ObjectAlignmentError {
  if start.length() == 0 && target.length() > 0 {
    (target.map(child => degenerate_object(child, Vec3::zero())), target.copy())
  } else if target.length() == 0 && start.length() > 0 {
    (start.copy(), start.map(child => degenerate_object(child, Vec3::zero())))
  } else if start.length() < target.length() {
    (repeat_children(start, target.length()), target.copy())
  } else if target.length() < start.length() {
    (start.copy(), repeat_children(target, start.length()))
  } else {
    (start.copy(), target.copy())
  }
}

///|
fn degenerate_object(
  object : Object,
  anchor : Vec3,
) -> Object raise ObjectAlignmentError {
  Object::new(node=degenerate_node(object.node, anchor), z_index=object.z_index)
}

///|
fn degenerate_node(
  node : Node,
  anchor : Vec3,
) -> Node raise ObjectAlignmentError {
  match node {
    Empty => Empty
    Path(path, style) => {
      let buffer = path.eval() catch { error => raise Path(error) }
      Path(buffer.map_points(_ => anchor).to_path(), transparent_style(style))
    }
    Mesh(mesh, style) =>
      Mesh(mesh.map_vertices(_ => anchor), transparent_style(style))
    Group(children) =>
      Group(children.map(child => degenerate_object(child, anchor)))
  }
}

///|
fn repeat_children(
  children : Array[Object],
  target_count : Int,
) -> Array[Object] {
  let repeated : Array[Object] = []
  let seen = Array::make(children.length(), 0)
  for index in 0..<target_count {
    let source_index = index * children.length() / target_count
    guard children.get(source_index) is Some(child) else { continue }
    let next = if seen[source_index] == 0 {
      child.copy()
    } else {
      transparent_object(child)
    }
    repeated.push(next)
    seen[source_index] += 1
  }
  repeated
}

///|
fn transparent_object(object : Object) -> Object {
  object.set_fill(opacity=0.0).set_stroke(opacity=0.0)
}

///|
fn transparent_style(style : ShapeStyle) -> ShapeStyle {
  style.set_fill(opacity=0.0).set_stroke(opacity=0.0)
}

///|
fn align_styles(
  start : ShapeStyle,
  target : ShapeStyle,
) -> (ShapeStyle, ShapeStyle) {
  let (start_fill, target_fill, start_fill_opacity, target_fill_opacity) = match
    (start.fill, target.fill) {
    (None, Some(color)) => (Some(color), Some(color), 0.0, target.fill_opacity)
    (Some(color), None) => (Some(color), Some(color), start.fill_opacity, 0.0)
    (start_fill, target_fill) =>
      (start_fill, target_fill, start.fill_opacity, target.fill_opacity)
  }
  let (start_stroke, target_stroke, start_stroke_opacity, target_stroke_opacity) = match
    (start.stroke, target.stroke) {
    (None, Some(color)) =>
      (Some(color), Some(color), 0.0, target.stroke_opacity)
    (Some(color), None) => (Some(color), Some(color), start.stroke_opacity, 0.0)
    (start_stroke, target_stroke) =>
      (start_stroke, target_stroke, start.stroke_opacity, target.stroke_opacity)
  }
  (
    {
      fill: start_fill,
      fill_opacity: start_fill_opacity,
      stroke: start_stroke,
      stroke_opacity: start_stroke_opacity,
      stroke_width: start.stroke_width,
    },
    {
      fill: target_fill,
      fill_opacity: target_fill_opacity,
      stroke: target_stroke,
      stroke_opacity: target_stroke_opacity,
      stroke_width: target.stroke_width,
    },
  )
}

///|
fn interpolate_aligned_object(
  start : Object,
  target : Object,
  alpha : Double,
  path : MotionPath,
) -> Object raise ObjectAlignmentError {
  Object::new(
    node=interpolate_aligned_node(start.node, target.node, alpha, path),
    transform=Transform::identity(),
    z_index=interpolate_double(start.z_index, target.z_index, alpha),
  )
}

///|
fn interpolate_aligned_family_object(
  start : Object,
  target : Object,
  alpha : Double,
  path : MotionPath,
  family_alpha : (Int, Int) -> Double,
  family_index : Int,
  family_size : Int,
) -> (Object, Int) raise ObjectAlignmentError {
  match (start.node, target.node) {
    (Group(start_children), Group(target_children)) => {
      if start_children.length() != target_children.length() {
        raise AlignmentInvariantBroken
      }
      let children : Array[Object] = []
      let mut next_index = family_index
      for index in 0..<start_children.length() {
        match (start_children.get(index), target_children.get(index)) {
          (Some(start_child), Some(target_child)) => {
            let (child, after_child) = interpolate_aligned_family_object(
              start_child, target_child, alpha, path, family_alpha, next_index, family_size,
            )
            children.push(child)
            next_index = after_child
          }
          _ => raise AlignmentInvariantBroken
        }
      }
      (
        Object::new(
          node=Group(children),
          z_index=interpolate_double(start.z_index, target.z_index, alpha),
        ),
        next_index,
      )
    }
    (Empty, Empty) =>
      (
        Object::new(
          node=Empty,
          z_index=interpolate_double(start.z_index, target.z_index, alpha),
        ),
        family_index,
      )
    _ => {
      let local_alpha = clamp_alignment_alpha(
        family_alpha(family_index, family_size),
      )
      (
        Object::new(
          node=interpolate_aligned_node(
            start.node,
            target.node,
            local_alpha,
            path,
          ),
          z_index=interpolate_double(start.z_index, target.z_index, local_alpha),
        ),
        family_index + 1,
      )
    }
  }
}

///|
fn renderable_family_size(object : Object) -> Int {
  match object.node {
    Empty => 0
    Path(_, _) | Mesh(_, _) => 1
    Group(children) =>
      children.fold(init=0, (size, child) => {
        size + renderable_family_size(child)
      })
  }
}

///|
fn interpolate_aligned_node(
  start : Node,
  target : Node,
  alpha : Double,
  path : MotionPath,
) -> Node raise ObjectAlignmentError {
  match (start, target) {
    (Empty, Empty) => Empty
    (Path(start_path, start_style), Path(target_path, target_style)) => {
      let start_buffer = start_path.eval() catch { error => raise Path(error) }
      let target_buffer = target_path.eval() catch {
        error => raise Path(error)
      }
      Path(
        interpolate_aligned_buffer(start_buffer, target_buffer, alpha, path).to_path(),
        interpolate_aligned_style(start_style, target_style, alpha),
      )
    }
    (Mesh(start_mesh, start_style), Mesh(target_mesh, target_style)) => {
      if !start_mesh.same_topology(target_mesh) {
        raise AlignmentInvariantBroken
      }
      let vertices = path.interpolate_points(
        start_mesh.vertices,
        target_mesh.vertices,
        alpha,
      )
      Mesh(
        { vertices, faces: start_mesh.faces.copy() },
        interpolate_aligned_style(start_style, target_style, alpha),
      )
    }
    (Group(start_children), Group(target_children)) => {
      if start_children.length() != target_children.length() {
        raise AlignmentInvariantBroken
      }
      let children : Array[Object] = []
      for index in 0..<start_children.length() {
        match (start_children.get(index), target_children.get(index)) {
          (Some(start_child), Some(target_child)) =>
            children.push(
              interpolate_aligned_object(start_child, target_child, alpha, path),
            )
          _ => raise AlignmentInvariantBroken
        }
      }
      Group(children)
    }
    _ => raise AlignmentInvariantBroken
  }
}

///|
fn interpolate_aligned_buffer(
  start : PathBuffer3D,
  target : PathBuffer3D,
  alpha : Double,
  path : MotionPath,
) -> PathBuffer3D raise ObjectAlignmentError {
  if start.points.length() != target.points.length() ||
    start.subpaths.length() != target.subpaths.length() {
    raise AlignmentInvariantBroken
  }
  let points = path.interpolate_points(start.points, target.points, alpha)
  PathBuffer3D::unsafe_new(points, start.subpaths)
}

///|
fn MotionPath::interpolate_points(
  self : MotionPath,
  start : Array[Vec3],
  target : Array[Vec3],
  alpha : Double,
) -> Array[Vec3] raise ObjectAlignmentError {
  if start.length() != target.length() {
    raise AlignmentInvariantBroken
  }
  let points = match self {
    Straight =>
      start
      .iter()
      .zip(target.iter())
      .map(pair => pair.0.lerp(pair.1, alpha))
      .to_array()
    Arc(angle~, axis~) =>
      start
      .iter()
      .zip(target.iter())
      .map(pair => {
        interpolate_point_along_arc(pair.0, pair.1, alpha, angle, axis)
      })
      .to_array()
    Custom(sample) => sample(start.copy(), target.copy(), alpha)
  }
  if points.length() != start.length() {
    raise InvalidMotionPathPointCount(
      expected=start.length(),
      actual=points.length(),
    )
  }
  points
}

///|
fn interpolate_point_along_arc(
  start : Vec3,
  target : Vec3,
  alpha : Double,
  angle : Double,
  axis : Vec3,
) -> Vec3 {
  if Double::abs(angle) < 0.01 {
    start.lerp(target, alpha)
  } else {
    let unit_axis = axis.normalize_or(Vec3::unit_z())
    let displacement = target.sub(start)
    let midpoint = start.add(displacement.scale(0.5))
    let tangent = @math.tan(angle / 2.0)
    let center = if Double::abs(tangent) < 0.000000000001 {
      midpoint
    } else {
      midpoint.add(
        unit_axis.cross(displacement.scale(0.5)).scale(1.0 / tangent),
      )
    }
    center.add(
      Transform::rotate_axis(angle=alpha * angle, axis=unit_axis).apply_vec(
        start.sub(center),
      ),
    )
  }
}

///|
fn interpolate_aligned_style(
  start : ShapeStyle,
  target : ShapeStyle,
  alpha : Double,
) -> ShapeStyle raise ObjectAlignmentError {
  {
    fill: interpolate_aligned_color(start.fill, target.fill, alpha),
    fill_opacity: interpolate_double(
      start.fill_opacity,
      target.fill_opacity,
      alpha,
    ),
    stroke: interpolate_aligned_color(start.stroke, target.stroke, alpha),
    stroke_opacity: interpolate_double(
      start.stroke_opacity,
      target.stroke_opacity,
      alpha,
    ),
    stroke_width: interpolate_double(
      start.stroke_width,
      target.stroke_width,
      alpha,
    ),
  }
}

///|
fn interpolate_aligned_color(
  start : Rgba?,
  target : Rgba?,
  alpha : Double,
) -> Rgba? raise ObjectAlignmentError {
  match (start, target) {
    (None, None) => None
    (Some(start), Some(target)) =>
      Some(
        Rgba::new(
          r=interpolate_double(start.r, target.r, alpha),
          g=interpolate_double(start.g, target.g, alpha),
          b=interpolate_double(start.b, target.b, alpha),
          a=interpolate_double(start.a, target.a, alpha),
        ),
      )
    _ => raise AlignmentInvariantBroken
  }
}

///|
fn interpolate_double(
  start : Double,
  target : Double,
  alpha : Double,
) -> Double {
  start + (target - start) * alpha
}

///|
fn clamp_alignment_alpha(alpha : Double) -> Double {
  if alpha.is_nan() || alpha < 0.0 {
    0.0
  } else if alpha > 1.0 {
    1.0
  } else {
    alpha
  }
}
