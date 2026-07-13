///|
fn interpolate_object(
  start : @object.Object,
  target : @object.Object,
  alpha : Double,
) -> @object.Object {
  let t = clamp_alpha(alpha)
  @object.Object::new(
    node=interpolate_node(start.node, target.node, t),
    transform=interpolate_transform(start.transform, target.transform, t),
    z_index=lerp_double(start.z_index, target.z_index, t),
  )
}

///|
fn interpolate_node(
  start : @object.Node,
  target : @object.Node,
  alpha : Double,
) -> @object.Node {
  match (start, target) {
    (Empty, Empty) => Empty
    (Path(start_path, start_style), Path(target_path, target_style)) =>
      Path(
        interpolate_path(start_path, target_path, alpha),
        interpolate_shape_style(start_style, target_style, alpha),
      )
    (Group(start_children), Group(target_children)) =>
      Group(interpolate_children(start_children, target_children, alpha))
    _ => choose_endpoint(start, target, alpha)
  }
}

///|
fn interpolate_children(
  start : Array[@object.Object],
  target : Array[@object.Object],
  alpha : Double,
) -> Array[@object.Object] {
  if start.length() != target.length() {
    choose_endpoint(start, target, alpha)
  } else {
    start
    .iter()
    .zip(target.iter())
    .map(pair => interpolate_object(pair.0, pair.1, alpha))
    .to_array()
  }
}

///|
fn interpolate_path(
  start : @object.Path3D,
  target : @object.Path3D,
  alpha : Double,
) -> @object.Path3D {
  try {
    let (sb, tb) = (start.eval(), target.eval())
    sb.lerp(tb, alpha).to_path()
  } catch {
    _ => choose_endpoint(start, target, alpha)
  }
}

///|
fn interpolate_shape_style(
  start : @object.ShapeStyle,
  target : @object.ShapeStyle,
  alpha : Double,
) -> @object.ShapeStyle {
  {
    fill: interpolate_optional_rgba(start.fill, target.fill, alpha),
    fill_opacity: lerp_double(start.fill_opacity, target.fill_opacity, alpha),
    stroke: interpolate_optional_rgba(start.stroke, target.stroke, alpha),
    stroke_opacity: lerp_double(
      start.stroke_opacity,
      target.stroke_opacity,
      alpha,
    ),
    stroke_width: lerp_double(start.stroke_width, target.stroke_width, alpha),
  }
}

///|
fn interpolate_optional_rgba(
  start : @object.Rgba?,
  target : @object.Rgba?,
  alpha : Double,
) -> @object.Rgba? {
  match (start, target) {
    (Some(a), Some(b)) => Some(interpolate_rgba(a, b, alpha))
    _ => choose_endpoint(start, target, alpha)
  }
}

///|
fn interpolate_rgba(
  start : @object.Rgba,
  target : @object.Rgba,
  alpha : Double,
) -> @object.Rgba {
  @object.Rgba::new(
    r=lerp_double(start.r, target.r, alpha),
    g=lerp_double(start.g, target.g, alpha),
    b=lerp_double(start.b, target.b, alpha),
    a=lerp_double(start.a, target.a, alpha),
  )
}

///|
fn interpolate_transform(
  start : @object.Transform,
  target : @object.Transform,
  alpha : Double,
) -> @object.Transform {
  {
    m00: lerp_double(start.m00, target.m00, alpha),
    m01: lerp_double(start.m01, target.m01, alpha),
    m02: lerp_double(start.m02, target.m02, alpha),
    m03: lerp_double(start.m03, target.m03, alpha),
    m10: lerp_double(start.m10, target.m10, alpha),
    m11: lerp_double(start.m11, target.m11, alpha),
    m12: lerp_double(start.m12, target.m12, alpha),
    m13: lerp_double(start.m13, target.m13, alpha),
    m20: lerp_double(start.m20, target.m20, alpha),
    m21: lerp_double(start.m21, target.m21, alpha),
    m22: lerp_double(start.m22, target.m22, alpha),
    m23: lerp_double(start.m23, target.m23, alpha),
  }
}

///|
fn lerp_double(start : Double, target : Double, alpha : Double) -> Double {
  start + (target - start) * alpha
}

///|
fn clamp_alpha(alpha : Double) -> Double {
  if alpha.is_nan() || alpha < 0.0 {
    0.0
  } else if alpha > 1.0 {
    1.0
  } else {
    alpha
  }
}

///|
fn[T] choose_endpoint(start : T, target : T, alpha : Double) -> T {
  if alpha >= 1.0 {
    target
  } else {
    start
  }
}
