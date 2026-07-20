///|
pub(all) struct CameraTarget {
  frame_center : @object.Vec3?
  phi : Double?
  theta : Double?
  gamma : Double?
  zoom : Double?
  focal_distance : Double?
}

///|
pub fn CameraTarget::new(
  frame_center? : @object.Vec3,
  phi? : Double,
  theta? : Double,
  gamma? : Double,
  zoom? : Double,
  focal_distance? : Double,
) -> CameraTarget {
  { frame_center, phi, theta, gamma, zoom, focal_distance }
}

///|
pub fn CameraTarget::resolve(self : CameraTarget, camera : Camera) -> Camera {
  {
    ..camera,
    frame_center: self.frame_center.unwrap_or(camera.frame_center),
    phi: self.phi.unwrap_or(camera.phi),
    theta: self.theta.unwrap_or(camera.theta),
    gamma: self.gamma.unwrap_or(camera.gamma),
    zoom: self.zoom.unwrap_or(camera.zoom),
    focal_distance: self.focal_distance.unwrap_or(camera.focal_distance),
  }
}

///|
pub(all) struct CameraOrbit {
  phi_delta : Double
  theta_delta : Double
  gamma_delta : Double
}

///|
pub fn CameraOrbit::new(
  phi_delta? : Double = 0.0,
  theta_delta? : Double = 0.0,
  gamma_delta? : Double = 0.0,
) -> CameraOrbit {
  { phi_delta, theta_delta, gamma_delta }
}

///|
pub fn CameraOrbit::resolve(self : CameraOrbit, camera : Camera) -> Camera {
  camera.with_view(
    phi=camera.phi + self.phi_delta,
    theta=camera.theta + self.theta_delta,
    gamma=camera.gamma + self.gamma_delta,
  )
}

///|
pub(all) enum CameraMotion {
  MoveTo(CameraTarget)
  Orbit(CameraOrbit)
}

///|
pub fn CameraMotion::resolve(self : CameraMotion, camera : Camera) -> Camera {
  match self {
    MoveTo(target) => target.resolve(camera)
    Orbit(orbit) => orbit.resolve(camera)
  }
}
