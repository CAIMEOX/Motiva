///|
pub(all) suberror PathEvalError {
  LineToWithoutCurrent
  CubicToWithoutCurrent
  CloseWithoutSubpath
}

///|
pub(all) suberror PathBufferError {
  InvalidPointCount(Int)
}

///|
pub(all) struct SubpathSpan {
  start_curve : Int
  curve_count : Int
  closed : Bool
}

///|
pub struct PathBuffer3D {
  priv points : Array[Vec3]
  priv subpaths : Array[SubpathSpan]
}

///|
pub fn PathBuffer3D::from_points(
  points : Array[Vec3],
) -> PathBuffer3D raise PathBufferError {
  if points.length() / 4 * 4 != points.length() {
    raise InvalidPointCount(points.length())
  }
  let subpaths = if points.length() == 0 {
    []
  } else {
    [{ start_curve: 0, curve_count: points.length() / 4, closed: false }]
  }
  PathBuffer3D::unsafe_new(points, subpaths)
}

///|
fn PathBuffer3D::unsafe_new(
  points : Array[Vec3],
  subpaths : Array[SubpathSpan],
) -> PathBuffer3D {
  { points: points.copy(), subpaths: subpaths.copy() }
}

///|
pub fn PathBuffer3D::points(self : PathBuffer3D) -> Array[Vec3] {
  self.points.copy()
}

///|
pub fn PathBuffer3D::subpaths(self : PathBuffer3D) -> Array[SubpathSpan] {
  self.subpaths.copy()
}

///|
pub fn PathBuffer3D::point_count(self : PathBuffer3D) -> Int {
  self.points.length()
}

///|
pub fn PathBuffer3D::curve_count(self : PathBuffer3D) -> Int {
  self.points.length() / 4
}

///|
pub fn PathBuffer3D::is_empty(self : PathBuffer3D) -> Bool {
  self.points.length() == 0
}

///|
pub fn PathBuffer3D::point(self : PathBuffer3D, index : Int) -> Vec3? {
  self.points.get(index)
}

///|
pub fn PathBuffer3D::map_points(
  self : PathBuffer3D,
  f : (Vec3) -> Vec3,
) -> PathBuffer3D {
  PathBuffer3D::unsafe_new(self.points.map(f), self.subpaths)
}

///|
pub fn PathBuffer3D::prefix(
  self : PathBuffer3D,
  alpha : Double,
) -> PathBuffer3D {
  self.partial(start=0.0, end=alpha)
}

///|
pub fn PathBuffer3D::partial(
  self : PathBuffer3D,
  start~ : Double,
  end~ : Double,
) -> PathBuffer3D {
  let start = clamp_unit(start)
  let end = clamp_unit(end)
  if start >= end || self.is_empty() {
    PathBuffer3D::unsafe_new([], [])
  } else if start <= 0.0 && end >= 1.0 {
    PathBuffer3D::unsafe_new(self.points, self.subpaths)
  } else {
    let points : Array[Vec3] = []
    let subpaths : Array[SubpathSpan] = []
    let curve_count = self.curve_count().to_double()
    let start_curve = start * curve_count
    let end_curve = end * curve_count
    for span in self.subpaths {
      append_partial_span(
        points,
        subpaths,
        self.points,
        span,
        start_curve,
        end_curve,
      )
    }
    PathBuffer3D::unsafe_new(points, subpaths)
  }
}

///|
pub fn PathBuffer3D::normalize_pair(
  self : PathBuffer3D,
  other : PathBuffer3D,
) -> (PathBuffer3D, PathBuffer3D) {
  let left_points : Array[Vec3] = []
  let right_points : Array[Vec3] = []
  let left_spans : Array[SubpathSpan] = []
  let right_spans : Array[SubpathSpan] = []
  let subpath_count = max_int(self.subpaths.length(), other.subpaths.length())
  for index in 0..<subpath_count {
    let left_span = self.subpaths.get(index)
    let right_span = other.subpaths.get(index)
    let left_curve_count = left_span.map_or(0, span => span.curve_count)
    let right_curve_count = right_span.map_or(0, span => span.curve_count)
    let target_curve_count = max_int(left_curve_count, right_curve_count)
    if target_curve_count > 0 {
      let left_anchor = self.anchor_for_missing_subpath()
      let right_anchor = other.anchor_for_missing_subpath()
      let left_remapped = remap_subpath_points(
        self.subpath_points(left_span),
        target_curve_count,
        left_anchor,
      )
      let right_remapped = remap_subpath_points(
        other.subpath_points(right_span),
        target_curve_count,
        right_anchor,
      )
      let closed = left_span.map_or(false, span => span.closed) ||
        right_span.map_or(false, span => span.closed)
      left_spans.push({
        start_curve: left_points.length() / 4,
        curve_count: target_curve_count,
        closed,
      })
      right_spans.push({
        start_curve: right_points.length() / 4,
        curve_count: target_curve_count,
        closed,
      })
      left_points.append(left_remapped)
      right_points.append(right_remapped)
    }
  }
  (
    PathBuffer3D::unsafe_new(left_points, left_spans),
    PathBuffer3D::unsafe_new(right_points, right_spans),
  )
}

///|
pub fn PathBuffer3D::lerp(
  self : PathBuffer3D,
  other : PathBuffer3D,
  alpha : Double,
) -> PathBuffer3D {
  let (left, right) = self.normalize_pair(other)
  let points : Array[Vec3] = []
  for index in 0..<left.points.length() {
    match (left.points.get(index), right.points.get(index)) {
      (Some(start), Some(target)) => points.push(lerp(start, target, alpha))
      _ => ()
    }
  }
  PathBuffer3D::unsafe_new(points, left.subpaths)
}

///|
pub fn PathBuffer3D::to_path(self : PathBuffer3D) -> Path3D {
  let path = Path3D::empty()
  for span in self.subpaths {
    if span.curve_count > 0 {
      let first = span.start_curve * 4
      path.move_to(self.points[first])
      for offset in 0..<span.curve_count {
        let base = (span.start_curve + offset) * 4
        path.cubic_to(
          self.points[base + 1],
          self.points[base + 2],
          self.points[base + 3],
        )
      }
      if span.closed {
        path.close()
      }
    }
  }
  path
}

///|
pub fn Path3D::eval(self : Path3D) -> PathBuffer3D raise PathEvalError {
  let points : Array[Vec3] = []
  let subpaths : Array[SubpathSpan] = []
  let mut current : Vec3? = None
  let mut subpath_start : Vec3? = None
  let mut subpath_start_curve : Int? = None
  let mut subpath_closed = false
  for command in self.commands {
    match (command, current, subpath_start) {
      (MoveTo(point), _, _) => {
        finish_subpath(subpaths, points, subpath_start_curve, subpath_closed)
        current = Some(point)
        subpath_start = Some(point)
        subpath_start_curve = Some(points.length() / 4)
        subpath_closed = false
      }
      (LineTo(_), None, _) => raise LineToWithoutCurrent
      (LineTo(anchor), Some(start), _) => {
        append_line(points, start, anchor)
        current = Some(anchor)
      }
      (CubicTo(_, _, _), None, _) => raise CubicToWithoutCurrent
      (CubicTo(handle1, handle2, anchor), Some(start), _) => {
        append_cubic(points, start, handle1, handle2, anchor)
        current = Some(anchor)
      }
      (Close, Some(point), Some(start)) =>
        if !points_nearly_equal(point, start) {
          append_line(points, point, start)
          current = Some(start)
          subpath_closed = true
        } else {
          subpath_closed = true
        }
      (Close, _, _) => raise CloseWithoutSubpath
    }
  }
  finish_subpath(subpaths, points, subpath_start_curve, subpath_closed)
  PathBuffer3D::unsafe_new(points, subpaths)
}

///|
fn finish_subpath(
  subpaths : Array[SubpathSpan],
  points : Array[Vec3],
  start_curve : Int?,
  closed : Bool,
) -> Unit {
  match start_curve {
    None => ()
    Some(start_curve) => {
      let curve_count = points.length() / 4 - start_curve
      if curve_count > 0 {
        subpaths.push({ start_curve, curve_count, closed })
      }
    }
  }
}

///|
fn append_line(points : Array[Vec3], start : Vec3, anchor : Vec3) -> Unit {
  append_cubic(
    points,
    start,
    lerp(start, anchor, 1.0 / 3.0),
    lerp(start, anchor, 2.0 / 3.0),
    anchor,
  )
}

///|
fn append_cubic(
  points : Array[Vec3],
  anchor0 : Vec3,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor1 : Vec3,
) -> Unit {
  points.push(anchor0)
  points.push(handle1)
  points.push(handle2)
  points.push(anchor1)
}

///|
fn append_partial_span(
  output_points : Array[Vec3],
  output_subpaths : Array[SubpathSpan],
  source_points : Array[Vec3],
  span : SubpathSpan,
  start_curve : Double,
  end_curve : Double,
) -> Unit {
  let output_start_curve = output_points.length() / 4
  let mut output_curve_count = 0
  for offset in 0..<span.curve_count {
    let curve_index = span.start_curve + offset
    let local_start = clamp_unit(start_curve - curve_index.to_double())
    let local_end = clamp_unit(end_curve - curve_index.to_double())
    if local_end > local_start {
      append_partial_curve(
        output_points, source_points, curve_index, local_start, local_end,
      )
      output_curve_count += 1
    }
  }
  if output_curve_count > 0 {
    output_subpaths.push({
      start_curve: output_start_curve,
      curve_count: output_curve_count,
      closed: span_fully_selected(span, start_curve, end_curve),
    })
  }
}

///|
fn append_partial_curve(
  output : Array[Vec3],
  points : Array[Vec3],
  curve_index : Int,
  start : Double,
  end : Double,
) -> Unit {
  let base = curve_index * 4
  let (p0, p1, p2, p3) = partial_cubic(
    points[base],
    points[base + 1],
    points[base + 2],
    points[base + 3],
    start,
    end,
  )
  append_cubic(output, p0, p1, p2, p3)
}

///|
fn span_fully_selected(
  span : SubpathSpan,
  start_curve : Double,
  end_curve : Double,
) -> Bool {
  span.closed &&
  start_curve <= span.start_curve.to_double() &&
  end_curve >= (span.start_curve + span.curve_count).to_double()
}

///|
fn lerp(start : Vec3, end : Vec3, t : Double) -> Vec3 {
  start.add(end.sub(start).scale(t))
}

///|
fn points_nearly_equal(a : Vec3, b : Vec3) -> Bool {
  Double::abs(a.x - b.x) < 0.000000001 &&
  Double::abs(a.y - b.y) < 0.000000001 &&
  Double::abs(a.z - b.z) < 0.000000001
}

///|
fn PathBuffer3D::subpath_points(
  self : PathBuffer3D,
  span : SubpathSpan?,
) -> Array[Vec3] {
  match span {
    None => []
    Some(span) => {
      let points : Array[Vec3] = []
      let start = span.start_curve * 4
      let end = start + span.curve_count * 4
      for index in start..<end {
        points.push(self.points[index])
      }
      points
    }
  }
}

///|
fn PathBuffer3D::anchor_for_missing_subpath(self : PathBuffer3D) -> Vec3 {
  self.points.last().map_or(Vec3::zero(), point => point)
}

///|
fn remap_subpath_points(
  points : Array[Vec3],
  target_curve_count : Int,
  fallback_anchor : Vec3,
) -> Array[Vec3] {
  let current_curve_count = points.length() / 4
  if target_curve_count == 0 {
    []
  } else if current_curve_count == 0 {
    degenerate_points(fallback_anchor, target_curve_count)
  } else if current_curve_count == target_curve_count {
    points.copy()
  } else {
    let remapped : Array[Vec3] = []
    for curve_index in 0..<current_curve_count {
      let split_factor = split_factor_for_curve(
        curve_index, current_curve_count, target_curve_count,
      )
      append_subdivided_curve(remapped, points, curve_index, split_factor)
    }
    remapped
  }
}

///|
fn degenerate_points(anchor : Vec3, curve_count : Int) -> Array[Vec3] {
  let points : Array[Vec3] = []
  for _ in 0..<curve_count {
    append_cubic(points, anchor, anchor, anchor, anchor)
  }
  points
}

///|
fn split_factor_for_curve(
  curve_index : Int,
  current_curve_count : Int,
  target_curve_count : Int,
) -> Int {
  let mut count = 0
  for target_index in 0..<target_curve_count {
    if target_index * current_curve_count / target_curve_count == curve_index {
      count += 1
    }
  }
  count
}

///|
fn append_subdivided_curve(
  output : Array[Vec3],
  points : Array[Vec3],
  curve_index : Int,
  split_factor : Int,
) -> Unit {
  let base = curve_index * 4
  let anchor0 = points[base]
  let handle1 = points[base + 1]
  let handle2 = points[base + 2]
  let anchor1 = points[base + 3]
  for index in 0..<split_factor {
    let start = index.to_double() / split_factor.to_double()
    let end = (index + 1).to_double() / split_factor.to_double()
    let (p0, p1, p2, p3) = partial_cubic(
      anchor0, handle1, handle2, anchor1, start, end,
    )
    append_cubic(output, p0, p1, p2, p3)
  }
}

///|
fn partial_cubic(
  anchor0 : Vec3,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor1 : Vec3,
  start : Double,
  end : Double,
) -> (Vec3, Vec3, Vec3, Vec3) {
  let p0 = cubic_point(anchor0, handle1, handle2, anchor1, start)
  let p3 = cubic_point(anchor0, handle1, handle2, anchor1, end)
  let scale = end - start
  let p1 = p0.add(
    cubic_derivative(anchor0, handle1, handle2, anchor1, start).scale(
      scale / 3.0,
    ),
  )
  let p2 = p3.sub(
    cubic_derivative(anchor0, handle1, handle2, anchor1, end).scale(scale / 3.0),
  )
  (p0, p1, p2, p3)
}

///|
fn cubic_point(
  anchor0 : Vec3,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor1 : Vec3,
  t : Double,
) -> Vec3 {
  let u = 1.0 - t
  anchor0
  .scale(u * u * u)
  .add(handle1.scale(3.0 * u * u * t))
  .add(handle2.scale(3.0 * u * t * t))
  .add(anchor1.scale(t * t * t))
}

///|
fn cubic_derivative(
  anchor0 : Vec3,
  handle1 : Vec3,
  handle2 : Vec3,
  anchor1 : Vec3,
  t : Double,
) -> Vec3 {
  let u = 1.0 - t
  handle1
  .sub(anchor0)
  .scale(3.0 * u * u)
  .add(handle2.sub(handle1).scale(6.0 * u * t))
  .add(anchor1.sub(handle2).scale(3.0 * t * t))
}

///|
fn clamp_unit(value : Double) -> Double {
  if value.is_nan() || value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
