///|
pub(all) suberror CameraError {
  InvalidPixelShape(width~ : Int, height~ : Int)
  InvalidFrameShape(width~ : Double, height~ : Double)
  InvalidFrameCenter(@object.Vec3)
  InvalidOrientation(phi~ : Double, theta~ : Double, gamma~ : Double)
  InvalidZoom(Double)
  InvalidFocalDistance(Double)
  InvalidProjectionScale(Double)
  InvalidLightSource(@object.Vec3)
}

///|
pub(all) enum Projection {
  Orthographic
  Perspective
  ExponentialPerspective
} derive(Eq)

///|
pub(all) enum FixedFrameDimension {
  Width
  Height
} derive(Eq)

///|
pub(all) enum CameraSpace {
  World
  FixedOrientation(@object.Vec3)
  FixedInFrame
}

///|
pub(all) struct Camera {
  pixel_width : Int
  pixel_height : Int
  frame_width : Double
  frame_height : Double
  frame_center : @object.Vec3
  background : @object.Rgba
  projection : Projection
  phi : Double
  theta : Double
  gamma : Double
  zoom : Double
  focal_distance : Double
  max_projection_scale : Double
  light_source : @object.Vec3
  shading_enabled : Bool
}

///|
pub fn Camera::new(
  pixel_width? : Int = 1280,
  pixel_height? : Int = 720,
  frame_width? : Double,
  frame_height? : Double,
  frame_center? : @object.Vec3 = @object.Vec3::zero(),
  background? : @object.Rgba = @object.Rgba::black(),
  projection? : Projection = Orthographic,
  phi? : Double = 0.0,
  theta? : Double = 0.0 - @math.PI / 2.0,
  gamma? : Double = 0.0,
  zoom? : Double = 1.0,
  focal_distance? : Double = 20.0,
  max_projection_scale? : Double = 1000000.0,
  light_source? : @object.Vec3 = @object.Vec3::new(x=-7.0, y=-9.0, z=10.0),
  shading_enabled? : Bool = true,
) -> Camera {
  let (frame_width, frame_height) = resolve_frame_shape(
    pixel_width, pixel_height, frame_width, frame_height,
  )
  {
    pixel_width,
    pixel_height,
    frame_width,
    frame_height,
    frame_center,
    background,
    projection,
    phi,
    theta,
    gamma,
    zoom,
    focal_distance,
    max_projection_scale,
    light_source,
    shading_enabled,
  }
}

///|
pub impl Default for Camera with fn default() -> Camera {
  Camera::new()
}

///|
pub fn Camera::validate(self : Camera) -> Unit raise CameraError {
  if self.pixel_width <= 0 || self.pixel_height <= 0 {
    raise InvalidPixelShape(width=self.pixel_width, height=self.pixel_height)
  }
  if invalid_positive(self.frame_width) || invalid_positive(self.frame_height) {
    raise InvalidFrameShape(width=self.frame_width, height=self.frame_height)
  }
  if !finite_vec3(self.frame_center) {
    raise InvalidFrameCenter(self.frame_center)
  }
  if !finite(self.phi) || !finite(self.theta) || !finite(self.gamma) {
    raise InvalidOrientation(phi=self.phi, theta=self.theta, gamma=self.gamma)
  }
  if invalid_positive(self.zoom) {
    raise InvalidZoom(self.zoom)
  }
  if invalid_positive(self.focal_distance) {
    raise InvalidFocalDistance(self.focal_distance)
  }
  if invalid_positive(self.max_projection_scale) {
    raise InvalidProjectionScale(self.max_projection_scale)
  }
  if !finite_vec3(self.light_source) {
    raise InvalidLightSource(self.light_source)
  }
}

///|
pub fn Camera::with_view(
  self : Camera,
  frame_center? : @object.Vec3,
  phi? : Double,
  theta? : Double,
  gamma? : Double,
  zoom? : Double,
  focal_distance? : Double,
) -> Camera {
  {
    ..self,
    frame_center: frame_center.unwrap_or(self.frame_center),
    phi: phi.unwrap_or(self.phi),
    theta: theta.unwrap_or(self.theta),
    gamma: gamma.unwrap_or(self.gamma),
    zoom: zoom.unwrap_or(self.zoom),
    focal_distance: focal_distance.unwrap_or(self.focal_distance),
  }
}

///|
pub fn Camera::with_projection(
  self : Camera,
  projection : Projection,
) -> Camera {
  { ..self, projection, }
}

///|
pub fn Camera::with_background(
  self : Camera,
  background : @object.Rgba,
) -> Camera {
  { ..self, background, }
}

///|
pub fn Camera::with_light_source(
  self : Camera,
  light_source : @object.Vec3,
) -> Camera {
  { ..self, light_source, }
}

///|
pub fn Camera::with_shading(self : Camera, enabled : Bool) -> Camera {
  { ..self, shading_enabled: enabled }
}

///|
pub fn Camera::with_pixel_shape(
  self : Camera,
  width~ : Int,
  height~ : Int,
  fixed? : FixedFrameDimension = Width,
) -> Camera {
  let aspect = safe_aspect(width, height)
  match fixed {
    Width =>
      {
        ..self,
        pixel_width: width,
        pixel_height: height,
        frame_height: self.frame_width / aspect,
      }
    Height =>
      {
        ..self,
        pixel_width: width,
        pixel_height: height,
        frame_width: self.frame_height * aspect,
      }
  }
}

///|
pub fn Camera::interpolate(
  self : Camera,
  target : Camera,
  alpha : Double,
) -> Camera {
  let t = clamp_alpha(alpha)
  {
    pixel_width: choose_endpoint(self.pixel_width, target.pixel_width, t),
    pixel_height: choose_endpoint(self.pixel_height, target.pixel_height, t),
    frame_width: lerp(self.frame_width, target.frame_width, t),
    frame_height: lerp(self.frame_height, target.frame_height, t),
    frame_center: lerp_vec3(self.frame_center, target.frame_center, t),
    background: lerp_rgba(self.background, target.background, t),
    projection: choose_endpoint(self.projection, target.projection, t),
    phi: lerp(self.phi, target.phi, t),
    theta: lerp(self.theta, target.theta, t),
    gamma: lerp(self.gamma, target.gamma, t),
    zoom: lerp(self.zoom, target.zoom, t),
    focal_distance: lerp(self.focal_distance, target.focal_distance, t),
    max_projection_scale: lerp(
      self.max_projection_scale,
      target.max_projection_scale,
      t,
    ),
    light_source: lerp_vec3(self.light_source, target.light_source, t),
    shading_enabled: choose_endpoint(
      self.shading_enabled,
      target.shading_enabled,
      t,
    ),
  }
}

///|
fn resolve_frame_shape(
  pixel_width : Int,
  pixel_height : Int,
  frame_width : Double?,
  frame_height : Double?,
) -> (Double, Double) {
  let aspect = safe_aspect(pixel_width, pixel_height)
  let default_frame_height = 8.0
  match (frame_width, frame_height) {
    (None, None) => (default_frame_height * aspect, default_frame_height)
    (Some(width), None) => (width, width / aspect)
    (None, Some(height)) => (height * aspect, height)
    (Some(width), Some(height)) => (width, height)
  }
}

///|
fn safe_aspect(width : Int, height : Int) -> Double {
  if width <= 0 || height <= 0 {
    1.0
  } else {
    width.to_double() / height.to_double()
  }
}

///|
fn invalid_positive(value : Double) -> Bool {
  value <= 0.0 || value.is_nan() || value.is_inf()
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn finite_vec3(vector : @object.Vec3) -> Bool {
  finite(vector.x) && finite(vector.y) && finite(vector.z)
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
fn lerp(start : Double, target : Double, alpha : Double) -> Double {
  start + (target - start) * alpha
}

///|
fn lerp_vec3(
  start : @object.Vec3,
  target : @object.Vec3,
  alpha : Double,
) -> @object.Vec3 {
  @object.Vec3::new(
    x=lerp(start.x, target.x, alpha),
    y=lerp(start.y, target.y, alpha),
    z=lerp(start.z, target.z, alpha),
  )
}

///|
fn lerp_rgba(
  start : @object.Rgba,
  target : @object.Rgba,
  alpha : Double,
) -> @object.Rgba {
  @object.Rgba::new(
    r=lerp(start.r, target.r, alpha),
    g=lerp(start.g, target.g, alpha),
    b=lerp(start.b, target.b, alpha),
    a=lerp(start.a, target.a, alpha),
  )
}

///|
fn[T] choose_endpoint(start : T, target : T, alpha : Double) -> T {
  if alpha >= 1.0 {
    target
  } else {
    start
  }
}
