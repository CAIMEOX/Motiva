///|
priv struct SvgArcSpec {
  start : @object.Vec3
  end : @object.Vec3
  rx : Double
  ry : Double
  rotation : Double
  large_arc : Bool
  sweep : Bool
}

///|
fn append_svg_arc(
  path : @object.Path3D,
  start~ : @object.Vec3,
  rx~ : Double,
  ry~ : Double,
  rotation~ : Double,
  large_arc~ : Bool,
  sweep~ : Bool,
  end~ : @object.Vec3,
) -> Unit {
  let spec : SvgArcSpec = {
    start,
    end,
    rx: Double::abs(rx),
    ry: Double::abs(ry),
    rotation: degrees_to_radians(rotation),
    large_arc,
    sweep,
  }
  spec.append_to_path(path)
}

///|
fn SvgArcSpec::append_to_path(self : SvgArcSpec, path : @object.Path3D) -> Unit {
  if same_point(self.start, self.end) {
    ()
  } else if self.rx == 0.0 || self.ry == 0.0 {
    path.line_to(self.end)
  } else {
    let center = self.center_parameterization()
    center.append_to_path(path, start=self.start, end=self.end)
  }
}

///|
priv struct SvgArcCenter {
  center : @object.Vec3
  rx : Double
  ry : Double
  cos_rotation : Double
  sin_rotation : Double
  start_angle : Double
  sweep_angle : Double
}

///|
fn SvgArcSpec::center_parameterization(self : SvgArcSpec) -> SvgArcCenter {
  let cos_rotation = @math.cos(self.rotation)
  let sin_rotation = @math.sin(self.rotation)
  let half_delta = self.start.sub(self.end).scale(0.5)
  let x1p = cos_rotation * half_delta.x + sin_rotation * half_delta.y
  let y1p = 0.0 - sin_rotation * half_delta.x + cos_rotation * half_delta.y
  let (rx, ry) = correct_radii(self.rx, self.ry, x1p, y1p)
  let rx2 = rx * rx
  let ry2 = ry * ry
  let x1p2 = x1p * x1p
  let y1p2 = y1p * y1p
  let denominator = rx2 * y1p2 + ry2 * x1p2
  let center_factor = if denominator == 0.0 {
    0.0
  } else {
    let raw = (rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2) / denominator
    let factor = Double::max(0.0, raw).sqrt()
    if self.large_arc == self.sweep {
      0.0 - factor
    } else {
      factor
    }
  }
  let cxp = center_factor * rx * y1p / ry
  let cyp = 0.0 - center_factor * ry * x1p / rx
  let midpoint = self.start.add(self.end).scale(0.5)
  let center = @object.Vec3::new(
    x=cos_rotation * cxp - sin_rotation * cyp + midpoint.x,
    y=sin_rotation * cxp + cos_rotation * cyp + midpoint.y,
  )
  let ux = (x1p - cxp) / rx
  let uy = (y1p - cyp) / ry
  let vx = (0.0 - x1p - cxp) / rx
  let vy = (0.0 - y1p - cyp) / ry
  let start_angle = @math.atan2(uy, ux)
  let sweep_angle = resolve_sweep_angle(
    @math.atan2(ux * vy - uy * vx, ux * vx + uy * vy),
    sweep=self.sweep,
  )
  { center, rx, ry, cos_rotation, sin_rotation, start_angle, sweep_angle }
}

///|
fn correct_radii(
  rx : Double,
  ry : Double,
  x1p : Double,
  y1p : Double,
) -> (Double, Double) {
  let radius_check = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
  if radius_check > 1.0 {
    let factor = radius_check.sqrt()
    (rx * factor, ry * factor)
  } else {
    (rx, ry)
  }
}

///|
fn resolve_sweep_angle(delta : Double, sweep~ : Bool) -> Double {
  if sweep && delta < 0.0 {
    delta + tau()
  } else if !sweep && delta > 0.0 {
    delta - tau()
  } else {
    delta
  }
}

///|
fn SvgArcCenter::append_to_path(
  self : SvgArcCenter,
  path : @object.Path3D,
  start~ : @object.Vec3,
  end~ : @object.Vec3,
) -> Unit {
  if self.sweep_angle == 0.0 {
    return
  }
  let segment_count = arc_segment_count(self.sweep_angle)
  let angle_step = self.sweep_angle / Double::from_int(segment_count)
  let mut current_angle = self.start_angle
  let mut curve_start = start
  for index in 0..<segment_count {
    let next_angle = current_angle + angle_step
    let curve_end = if index == segment_count - 1 {
      end
    } else {
      self.point_at(next_angle)
    }
    let alpha = arc_cubic_alpha(angle_step)
    let start_derivative = self.derivative_at(current_angle)
    let end_derivative = self.derivative_at(next_angle)
    path.cubic_to(
      curve_start.add(start_derivative.scale(alpha)),
      curve_end.sub(end_derivative.scale(alpha)),
      curve_end,
    )
    curve_start = curve_end
    current_angle = next_angle
  }
}

///|
fn arc_segment_count(sweep_angle : Double) -> Int {
  let sweep_limit = tau() * 0.1
  let count = (Double::abs(sweep_angle) / sweep_limit).ceil().to_int()
  if count < 1 {
    1
  } else {
    count
  }
}

///|
fn arc_cubic_alpha(angle_step : Double) -> Double {
  @math.sin(angle_step) *
  (
    (4.0 + 3.0 * @math.tan(angle_step / 2.0) * @math.tan(angle_step / 2.0)).sqrt() -
    1.0
  ) /
  3.0
}

///|
fn SvgArcCenter::point_at(self : SvgArcCenter, angle : Double) -> @object.Vec3 {
  let cos_angle = @math.cos(angle)
  let sin_angle = @math.sin(angle)
  @object.Vec3::new(
    x=self.center.x +
      self.rx * cos_angle * self.cos_rotation -
      self.ry * sin_angle * self.sin_rotation,
    y=self.center.y +
      self.rx * cos_angle * self.sin_rotation +
      self.ry * sin_angle * self.cos_rotation,
  )
}

///|
fn SvgArcCenter::derivative_at(
  self : SvgArcCenter,
  angle : Double,
) -> @object.Vec3 {
  let cos_angle = @math.cos(angle)
  let sin_angle = @math.sin(angle)
  @object.Vec3::new(
    x=0.0 -
      self.rx * self.cos_rotation * sin_angle -
      self.ry * self.sin_rotation * cos_angle,
    y=0.0 -
      self.rx * self.sin_rotation * sin_angle +
      self.ry * self.cos_rotation * cos_angle,
  )
}

///|
fn same_point(a : @object.Vec3, b : @object.Vec3) -> Bool {
  Double::abs(a.x - b.x) < 0.000000001 &&
  Double::abs(a.y - b.y) < 0.000000001 &&
  Double::abs(a.z - b.z) < 0.000000001
}

///|
fn tau() -> Double {
  2.0 * @math.PI
}
