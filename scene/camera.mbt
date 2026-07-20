///|
priv enum CameraAnchor {
  Dynamic(ObjectId)
  Static(@object.Vec3)
  Custom(() -> @object.Vec3)
}

///|
priv enum CameraBinding {
  CameraWorld
  CameraFixedOrientation(CameraAnchor)
  CameraFixedInFrame
}

///|
pub fn Scene::camera(self : Scene) -> @camera.Camera {
  self.camera
}

///|
pub fn Scene::set_camera(
  self : Scene,
  camera : @camera.Camera,
) -> Unit raise SceneError {
  validate_camera(camera)
  self.camera = camera
}

///|
pub fn Scene::set_camera_orientation(
  self : Scene,
  frame_center? : @object.Vec3,
  phi? : Double,
  theta? : Double,
  gamma? : Double,
  zoom? : Double,
  focal_distance? : Double,
) -> Unit raise SceneError {
  self.set_camera(
    @camera.CameraTarget::new(
      frame_center?,
      phi?,
      theta?,
      gamma?,
      zoom?,
      focal_distance?,
    ).resolve(self.camera),
  )
}

///|
pub fn Scene::set_camera_projection(
  self : Scene,
  projection : @camera.Projection,
) -> Unit raise SceneError {
  self.set_camera(self.camera.with_projection(projection))
}

///|
pub fn Scene::move_camera(
  self : Scene,
  frame_center? : @object.Vec3,
  phi? : Double,
  theta? : Double,
  gamma? : Double,
  zoom? : Double,
  focal_distance? : Double,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Smooth,
  reverse_rate_function? : Bool = false,
) -> Unit raise SceneError {
  self.play([
    Animation::move_camera(
      frame_center?,
      phi?,
      theta?,
      gamma?,
      zoom?,
      focal_distance?,
      run_time~,
      rate_func~,
      reverse_rate_function~,
    ),
  ])
}

///|
pub fn Scene::orbit_camera(
  self : Scene,
  phi_delta? : Double = 0.0,
  theta_delta? : Double = 2.0 * @math.PI,
  gamma_delta? : Double = 0.0,
  run_time? : Double = 5.0,
  rate_func? : RateFunc = Linear,
  reverse_rate_function? : Bool = false,
) -> Unit raise SceneError {
  self.play([
    Animation::orbit_camera(
      phi_delta~,
      theta_delta~,
      gamma_delta~,
      run_time~,
      rate_func~,
      reverse_rate_function~,
    ),
  ])
}

///|
pub fn Scene::add_fixed_orientation(
  self : Scene,
  id : ObjectId,
  use_static_center_func? : Bool = false,
  center_func? : () -> @object.Vec3,
) -> Unit raise SceneError {
  let anchor = match center_func {
    Some(center) => CameraAnchor::Custom(center)
    None if use_static_center_func =>
      Static(self.require_materialized_object(id).center())
    None => Dynamic(id)
  }
  self.set_family_camera_binding(id, CameraFixedOrientation(anchor))
}

///|
pub fn Scene::add_fixed_in_frame(
  self : Scene,
  id : ObjectId,
) -> Unit raise SceneError {
  self.set_family_camera_binding(id, CameraFixedInFrame)
}

///|
pub fn Scene::remove_fixed_orientation(
  self : Scene,
  id : ObjectId,
) -> Unit raise SceneError {
  self.update_family_camera_binding(id, binding => {
    match binding {
      CameraFixedOrientation(_) => CameraWorld
      _ => binding
    }
  })
}

///|
pub fn Scene::remove_fixed_in_frame(
  self : Scene,
  id : ObjectId,
) -> Unit raise SceneError {
  self.update_family_camera_binding(id, binding => {
    match binding {
      CameraFixedInFrame => CameraWorld
      _ => binding
    }
  })
}

///|
pub fn Scene::camera_space(
  self : Scene,
  id : ObjectId,
) -> @camera.CameraSpace raise SceneError {
  match self.require_object(id).camera_binding {
    CameraWorld => World
    CameraFixedInFrame => FixedInFrame
    CameraFixedOrientation(anchor) =>
      FixedOrientation(self.resolve_camera_anchor(anchor))
  }
}

///|
fn Scene::resolve_camera_anchor(
  self : Scene,
  anchor : CameraAnchor,
) -> @object.Vec3 raise SceneError {
  match anchor {
    Dynamic(id) => self.require_materialized_object(id).center()
    Static(point) => point
    Custom(center) => center()
  }
}

///|
fn Scene::set_family_camera_binding(
  self : Scene,
  id : ObjectId,
  binding : CameraBinding,
) -> Unit raise SceneError {
  self.update_family_camera_binding(id, _ => binding)
}

///|
fn Scene::update_family_camera_binding(
  self : Scene,
  id : ObjectId,
  update : (CameraBinding) -> CameraBinding,
) -> Unit raise SceneError {
  for family_id in self.family(id) {
    let scene_object = self.require_object(family_id)
    self.objects[family_id] = {
      ..scene_object,
      camera_binding: update(scene_object.camera_binding),
    }
  }
}

///|
fn validate_camera(camera : @camera.Camera) -> Unit raise SceneError {
  camera.validate() catch {
    error => raise Camera(error)
  }
}
