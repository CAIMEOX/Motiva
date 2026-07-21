///|
priv struct FlatPathPrimitive {
  path : @object.Path3D
  style : @object.ShapeStyle
  transform : @object.Transform
  camera_space : @camera.CameraSpace
  layer : RenderLayer
  z_index : Double
}

///|
priv struct SurfaceFacePrimitive {
  projected : Array[@object.Vec3]
  world : Array[@object.Vec3]
  normal : @object.Vec3
  style : @object.ShapeStyle
  layer : RenderLayer
  z_index : Double
  depth : Double
  shaded : Bool
}

///|
priv enum CairoPrimitive {
  FlatPath(FlatPathPrimitive)
  SurfaceFace(SurfaceFacePrimitive)
}

///|
priv struct ClipVertex {
  world : @object.Vec3
  camera : @object.Vec3
}

///|
fn draw_render_items(
  ctx : @cairoon.Context,
  snapshot : FrameSnapshot,
  cairo_line_width_multiple : Double,
) -> Unit raise RenderError {
  let primitives : Array[CairoPrimitive] = []
  for item in snapshot.items {
    collect_primitives(
      primitives,
      snapshot.camera,
      item.object,
      item.object.transform,
      item.camera_space,
      item.layer,
      item.object.z_index,
    )
  }
  for primitive in primitives {
    match primitive {
      FlatPath(path) =>
        draw_path(
          ctx,
          snapshot.camera,
          path.path,
          path.style,
          path.transform,
          path.camera_space,
          cairo_line_width_multiple,
        )
      SurfaceFace(face) =>
        draw_surface_face(ctx, snapshot.camera, face, cairo_line_width_multiple)
    }
  }
}

///|
fn collect_primitives(
  primitives : Array[CairoPrimitive],
  camera : @camera.Camera,
  object : @object.Object,
  transform : @object.Transform,
  camera_space : @camera.CameraSpace,
  layer : RenderLayer,
  z_index : Double,
) -> Unit {
  match object.node {
    Empty => ()
    Group(children) =>
      for child in children {
        collect_primitives(
          primitives,
          camera,
          child,
          child.transform.then(transform),
          camera_space,
          layer,
          child.z_index,
        )
      }
    Path(path, style) =>
      insert_primitive(
        primitives,
        FlatPath({ path, style, transform, camera_space, layer, z_index }),
      )
    Mesh(mesh, style) =>
      for face_index in 0..<mesh.face_count() {
        match mesh.face_vertices(face_index) {
          Some(vertices) =>
            match
              lower_surface_face(
                camera,
                vertices.map(point => transform.apply_point(point)),
                style,
                camera_space,
                layer,
                z_index,
              ) {
              Some(face) => insert_primitive(primitives, SurfaceFace(face))
              None => ()
            }
          None => ()
        }
      }
  }
}

///|
fn lower_surface_face(
  camera : @camera.Camera,
  world : Array[@object.Vec3],
  style : @object.ShapeStyle,
  camera_space : @camera.CameraSpace,
  layer : RenderLayer,
  z_index : Double,
) -> SurfaceFacePrimitive? {
  if world.length() < 3 {
    None
  } else {
    let normal = polygon_normal(world)
    match camera_space {
      World => {
        let camera_vertices = world.map(point => {
          world: point,
          camera: camera.world_to_camera(point),
        })
        let visible = if camera.projection == Perspective {
          clip_at_focal_plane(camera_vertices, camera.focal_distance)
        } else {
          camera_vertices
        }
        if visible.length() < 3 {
          None
        } else {
          Some({
            projected: visible.map(vertex => {
              camera.project_camera_point(vertex.camera)
            }),
            world: visible.map(vertex => vertex.world),
            normal,
            style,
            layer,
            z_index,
            depth: mean_depth(visible),
            shaded: true,
          })
        }
      }
      _ => {
        let center = polygon_center(world)
        Some({
          projected: world.map(point => {
            camera.transform_point(point, camera_space)
          }),
          world,
          normal,
          style,
          layer,
          z_index,
          depth: camera.depth_at(center, space=camera_space),
          shaded: false,
        })
      }
    }
  }
}

///|
fn insert_primitive(
  primitives : Array[CairoPrimitive],
  primitive : CairoPrimitive,
) -> Unit {
  match primitives.search_by(current => primitive_before(primitive, current)) {
    Some(index) => primitives.insert(index, primitive)
    None => primitives.push(primitive)
  }
}

///|
fn primitive_before(a : CairoPrimitive, b : CairoPrimitive) -> Bool {
  let a_layer = primitive_layer(a)
  let b_layer = primitive_layer(b)
  if a_layer != b_layer {
    a_layer < b_layer
  } else {
    let a_z = primitive_z_index(a)
    let b_z = primitive_z_index(b)
    if a_z != b_z {
      a_z < b_z
    } else {
      match (a, b) {
        (SurfaceFace(left), SurfaceFace(right)) => left.depth < right.depth
        (SurfaceFace(_), FlatPath(_)) => true
        _ => false
      }
    }
  }
}

///|
fn primitive_layer(primitive : CairoPrimitive) -> Int {
  let layer = match primitive {
    FlatPath(path) => path.layer
    SurfaceFace(face) => face.layer
  }
  match layer {
    Main => 0
    Foreground => 1
  }
}

///|
fn primitive_z_index(primitive : CairoPrimitive) -> Double {
  match primitive {
    FlatPath(path) => path.z_index
    SurfaceFace(face) => face.z_index
  }
}

///|
fn clip_at_focal_plane(
  vertices : Array[ClipVertex],
  focal_distance : Double,
) -> Array[ClipVertex] {
  match vertices.last() {
    None => []
    Some(last) => {
      let plane = focal_distance - focal_plane_epsilon(focal_distance)
      let output : Array[ClipVertex] = []
      let mut previous = last
      let mut previous_inside = previous.camera.z <= plane
      for current in vertices {
        let current_inside = current.camera.z <= plane
        match (previous_inside, current_inside) {
          (true, true) => output.push(current)
          (true, false) =>
            output.push(intersect_focal_plane(previous, current, plane))
          (false, true) => {
            output.push(intersect_focal_plane(previous, current, plane))
            output.push(current)
          }
          (false, false) => ()
        }
        previous = current
        previous_inside = current_inside
      }
      output
    }
  }
}

///|
fn intersect_focal_plane(
  start : ClipVertex,
  end : ClipVertex,
  plane : Double,
) -> ClipVertex {
  let delta = end.camera.z - start.camera.z
  let alpha = if Double::abs(delta) < 0.000000000001 {
    0.0
  } else {
    (plane - start.camera.z) / delta
  }
  {
    world: start.world.lerp(end.world, alpha),
    camera: start.camera.lerp(end.camera, alpha),
  }
}

///|
fn focal_plane_epsilon(focal_distance : Double) -> Double {
  let relative = Double::abs(focal_distance) * 0.000001
  if relative < 0.000001 {
    0.000001
  } else {
    relative
  }
}

///|
fn mean_depth(vertices : Array[ClipVertex]) -> Double {
  vertices.fold(init=0.0, (sum, vertex) => sum + vertex.camera.z) /
  vertices.length().to_double()
}

///|
fn polygon_center(points : Array[@object.Vec3]) -> @object.Vec3 {
  points
  .fold(init=@object.Vec3::zero(), (sum, point) => sum.add(point))
  .scale(1.0 / points.length().to_double())
}

///|
fn polygon_normal(points : Array[@object.Vec3]) -> @object.Vec3 {
  let origin = points[0]
  let mut normal = @object.Vec3::unit_z()
  for index in 1..<(points.length() - 1) {
    let candidate = points[index]
      .sub(origin)
      .cross(points[index + 1].sub(origin))
    if candidate.length_squared() > 0.000000000000000001 {
      normal = candidate.normalize_or(@object.Vec3::unit_z())
      break
    }
  }
  normal
}

///|
fn draw_surface_face(
  ctx : @cairoon.Context,
  camera : @camera.Camera,
  face : SurfaceFacePrimitive,
  cairo_line_width_multiple : Double,
) -> Unit raise RenderError {
  match face.projected {
    [] => ()
    [first, .. rest] => {
      try_cairo(() => ctx.new_path())
      move_to(ctx, first)
      for point in rest {
        line_to(ctx, point)
      }
      try_cairo(() => ctx.close_path())
      apply_surface_style(ctx, camera, face, cairo_line_width_multiple)
      try_cairo(() => ctx.new_path())
    }
  }
}

///|
fn apply_surface_style(
  ctx : @cairoon.Context,
  camera : @camera.Camera,
  face : SurfaceFacePrimitive,
  cairo_line_width_multiple : Double,
) -> Unit raise RenderError {
  match face.style.fill {
    Some(color) =>
      if face.style.fill_opacity > 0.0 && color.a > 0.0 {
        set_surface_source(ctx, camera, face, color, face.style.fill_opacity)
        try_cairo(() => ctx.fill_preserve())
      }
    None => ()
  }
  match face.style.stroke {
    Some(color) =>
      if face.style.stroke_width > 0.0 &&
        face.style.stroke_opacity > 0.0 &&
        color.a > 0.0 {
        set_surface_source(ctx, camera, face, color, face.style.stroke_opacity)
        try_cairo(() => {
          ctx.set_line_width(
            face.style.stroke_width * cairo_line_width_multiple,
          )
        })
        try_cairo(() => ctx.stroke_preserve())
      }
    None => ()
  }
}

///|
fn set_surface_source(
  ctx : @cairoon.Context,
  camera : @camera.Camera,
  face : SurfaceFacePrimitive,
  color : @object.Rgba,
  opacity : Double,
) -> Unit raise RenderError {
  if !face.shaded {
    set_source_rgba(ctx, color, opacity)
  } else {
    let end_index = face.projected.length() / 2
    let start_color = camera.shade(
      color,
      point=face.world[0],
      normal=face.normal,
    )
    let end_color = camera.shade(
      color,
      point=face.world[end_index],
      normal=face.normal,
    )
    let start = face.projected[0]
    let end = face.projected[end_index]
    if start.sub(end).length_squared() < 0.000000000000000001 {
      set_source_rgba(ctx, start_color, opacity)
    } else {
      try_cairo(() => {
        let pattern = @cairoon.Pattern::linear(start.x, start.y, end.x, end.y)
        pattern.add_color_stop_rgba(
          0.0,
          clamp01(start_color.r),
          clamp01(start_color.g),
          clamp01(start_color.b),
          clamp01(start_color.a * opacity),
        )
        pattern.add_color_stop_rgba(
          1.0,
          clamp01(end_color.r),
          clamp01(end_color.g),
          clamp01(end_color.b),
          clamp01(end_color.a * opacity),
        )
        ctx.set_source(pattern)
      })
    }
  }
}
