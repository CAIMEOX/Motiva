///|
pub fn Camera::shade(
  self : Camera,
  color : @object.Rgba,
  point~ : @object.Vec3,
  normal~ : @object.Vec3,
) -> @object.Rgba {
  if !self.shading_enabled {
    color
  } else {
    let unit_normal = normal.normalize_or(@object.Vec3::unit_z())
    let to_light = self.light_source
      .sub(point)
      .normalize_or(@object.Vec3::unit_z())
    let cosine = unit_normal.dot(to_light)
    let mut light = 0.5 * cosine * cosine * cosine
    if light < 0.0 {
      light = light * 0.5
    }
    @object.Rgba::new(
      r=clamp_channel(color.r + light),
      g=clamp_channel(color.g + light),
      b=clamp_channel(color.b + light),
      a=color.a,
    )
  }
}

///|
fn clamp_channel(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}
