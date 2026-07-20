///|
pub fn Camera::rotation_transform(self : Camera) -> @object.Transform {
  @object.Transform::rotate_z(angle=0.0 - self.theta - @math.PI / 2.0)
  .then(@object.Transform::rotate_x(angle=0.0 - self.phi))
  .then(@object.Transform::rotate_z(angle=self.gamma))
}

///|
pub fn Camera::inverse_rotation_transform(self : Camera) -> @object.Transform {
  @object.Transform::rotate_z(angle=0.0 - self.gamma)
  .then(@object.Transform::rotate_x(angle=self.phi))
  .then(@object.Transform::rotate_z(angle=self.theta + @math.PI / 2.0))
}

///|
pub fn Camera::world_to_camera(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  self.rotation_transform().apply_vec(point.sub(self.frame_center))
}

///|
pub fn Camera::camera_to_world(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  self.inverse_rotation_transform().apply_vec(point).add(self.frame_center)
}

///|
pub fn Camera::projection_scale(self : Camera, depth : Double) -> Double {
  let projection_scale = match self.projection {
    Orthographic => 1.0
    Perspective => perspective_scale(self, depth)
    ExponentialPerspective =>
      if depth < 0.0 {
        perspective_scale(self, depth)
      } else {
        @math.exp(depth / self.focal_distance)
      }
  }
  clamp_projection_scale(
    projection_scale * self.zoom,
    self.max_projection_scale,
  )
}

///|
pub fn Camera::project_camera_point(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  let scale = self.projection_scale(point.z)
  @object.Vec3::new(x=point.x * scale, y=point.y * scale, z=point.z)
}

///|
pub fn Camera::unproject_camera_point(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  let scale = self.projection_scale(point.z)
  if Double::abs(scale) < 0.000000000001 {
    @object.Vec3::new(x=0.0, y=0.0, z=point.z)
  } else {
    @object.Vec3::new(x=point.x / scale, y=point.y / scale, z=point.z)
  }
}

///|
pub fn Camera::project_point(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  self.project_camera_point(self.world_to_camera(point))
}

///|
pub fn Camera::unproject_point(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  self.camera_to_world(self.unproject_camera_point(point))
}

///|
pub fn Camera::transform_point(
  self : Camera,
  point : @object.Vec3,
  space : CameraSpace,
) -> @object.Vec3 {
  match space {
    World => self.project_point(point)
    FixedOrientation(center) =>
      point.add(self.project_point(center).sub(center))
    FixedInFrame => point
  }
}

///|
pub fn Camera::transform_points(
  self : Camera,
  points : Array[@object.Vec3],
  space? : CameraSpace = World,
) -> Array[@object.Vec3] {
  points.map(point => self.transform_point(point, space))
}

///|
pub fn Camera::depth_at(
  self : Camera,
  point : @object.Vec3,
  space? : CameraSpace = World,
) -> Double {
  match space {
    World => self.world_to_camera(point).z
    FixedOrientation(center) => self.world_to_camera(center).z
    FixedInFrame => 0.0
  }
}

///|
pub fn Camera::frame_to_pixel(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  let width_scale = self.pixel_width.to_double() / self.frame_width
  let height_scale = self.pixel_height.to_double() / self.frame_height
  @object.Vec3::new(
    x=point.x * width_scale + self.pixel_width.to_double() / 2.0,
    y=0.0 - point.y * height_scale + self.pixel_height.to_double() / 2.0,
    z=point.z,
  )
}

///|
pub fn Camera::pixel_to_frame(
  self : Camera,
  point : @object.Vec3,
) -> @object.Vec3 {
  let width_scale = self.frame_width / self.pixel_width.to_double()
  let height_scale = self.frame_height / self.pixel_height.to_double()
  @object.Vec3::new(
    x=(point.x - self.pixel_width.to_double() / 2.0) * width_scale,
    y=(self.pixel_height.to_double() / 2.0 - point.y) * height_scale,
    z=point.z,
  )
}

///|
pub fn Camera::world_to_pixel(
  self : Camera,
  point : @object.Vec3,
  space? : CameraSpace = World,
) -> @object.Vec3 {
  self.frame_to_pixel(self.transform_point(point, space))
}

///|
pub fn Camera::project_bounds(
  self : Camera,
  bounds : @object.Aabb,
  space? : CameraSpace = World,
) -> @object.Aabb {
  let corners = bounds_corners(bounds)
  let first = self.transform_point(corners[0], space)
  corners[1:].fold(init=@object.Aabb::point(first), (projected, corner) => {
    projected.include_point(self.transform_point(corner, space))
  })
}

///|
pub fn Camera::is_in_frame(
  self : Camera,
  bounds : @object.Aabb,
  space? : CameraSpace = World,
) -> Bool {
  let projected = self.project_bounds(bounds, space~)
  let half_width = self.frame_width / 2.0
  let half_height = self.frame_height / 2.0
  projected.max.x >= 0.0 - half_width &&
  projected.min.x <= half_width &&
  projected.max.y >= 0.0 - half_height &&
  projected.min.y <= half_height
}

///|
pub fn Camera::is_pixel_visible(self : Camera, point : @object.Vec3) -> Bool {
  point.x >= 0.0 &&
  point.x < self.pixel_width.to_double() &&
  point.y >= 0.0 &&
  point.y < self.pixel_height.to_double()
}

///|
fn perspective_scale(camera : Camera, depth : Double) -> Double {
  let denominator = camera.focal_distance - depth
  if denominator <= 0.0 || denominator.is_nan() {
    camera.max_projection_scale
  } else {
    camera.focal_distance / denominator
  }
}

///|
fn clamp_projection_scale(value : Double, limit : Double) -> Double {
  if value.is_nan() {
    1.0
  } else if value.is_inf() || value > limit {
    limit
  } else if value < 0.0 - limit {
    0.0 - limit
  } else {
    value
  }
}

///|
fn bounds_corners(bounds : @object.Aabb) -> Array[@object.Vec3] {
  [
    bounds.min,
    @object.Vec3::new(x=bounds.max.x, y=bounds.min.y, z=bounds.min.z),
    @object.Vec3::new(x=bounds.min.x, y=bounds.max.y, z=bounds.min.z),
    @object.Vec3::new(x=bounds.max.x, y=bounds.max.y, z=bounds.min.z),
    @object.Vec3::new(x=bounds.min.x, y=bounds.min.y, z=bounds.max.z),
    @object.Vec3::new(x=bounds.max.x, y=bounds.min.y, z=bounds.max.z),
    @object.Vec3::new(x=bounds.min.x, y=bounds.max.y, z=bounds.max.z),
    bounds.max,
  ]
}
