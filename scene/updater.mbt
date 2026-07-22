///|
pub struct ValueTracker {
  priv id : Int
} derive(Eq, Hash)

///|
pub fn ValueTracker::id(self : ValueTracker) -> Int {
  self.id
}

///|
pub struct UpdaterId {
  priv updater_id : Int
} derive(Eq, Hash)

///|
pub fn UpdaterId::value(self : UpdaterId) -> Int {
  self.updater_id
}

///|
priv enum ObjectUpdateMode {
  PreserveFamily
  RebuildFamily
} derive(Eq)

///|
priv enum UpdateTarget {
  ObjectTarget(ObjectId)
  ValueTarget(ValueTracker)
  CameraTarget
} derive(Eq, Hash)

///|
priv enum UpdateBehavior {
  UpdateObject(
    ObjectId,
    ObjectUpdateMode,
    (@object.Object, UpdateContext) -> @object.Object raise SceneError
  )
  UpdateValue(ValueTracker, (Double, UpdateContext) -> Double raise SceneError)
  UpdateCamera(
    (@camera.Camera, UpdateContext) -> @camera.Camera raise SceneError
  )
}

///|
pub struct Updater {
  priv behavior : UpdateBehavior
}

///|
priv struct RegisteredUpdater {
  id : UpdaterId
  updater : Updater
}

///|
pub struct UpdateContext {
  priv time : Double
  priv dt : Double
  priv objects : Map[ObjectId, @object.Object]
  priv values : Map[ValueTracker, Double]
  priv camera : @camera.Camera
}

///|
priv struct PendingObjectUpdate {
  object : @object.Object
  rebuild_family : Bool
}

///|
pub fn UpdateContext::time(self : UpdateContext) -> Double {
  self.time
}

///|
pub fn UpdateContext::dt(self : UpdateContext) -> Double {
  self.dt
}

///|
pub fn UpdateContext::object(
  self : UpdateContext,
  id : ObjectId,
) -> @object.Object raise SceneError {
  match self.objects.get(id) {
    Some(object) => object.copy()
    None => raise UnknownObject(id)
  }
}

///|
pub fn UpdateContext::value(
  self : UpdateContext,
  tracker : ValueTracker,
) -> Double raise SceneError {
  match self.values.get(tracker) {
    Some(value) => value
    None => raise UnknownValueTracker(tracker)
  }
}

///|
pub fn UpdateContext::camera(self : UpdateContext) -> @camera.Camera {
  self.camera
}

///|
pub fn Updater::object(
  id : ObjectId,
  update : (@object.Object, UpdateContext) -> @object.Object raise SceneError,
) -> Updater {
  { behavior: UpdateObject(id, PreserveFamily, update) }
}

///|
pub fn Updater::redraw(
  id : ObjectId,
  redraw : (UpdateContext) -> @object.Object raise SceneError,
) -> Updater {
  {
    behavior: UpdateObject(id, RebuildFamily, (_object, context) => {
      redraw(context)
    }),
  }
}

///|
pub fn Updater::value(
  tracker : ValueTracker,
  update : (Double, UpdateContext) -> Double raise SceneError,
) -> Updater {
  { behavior: UpdateValue(tracker, update) }
}

///|
pub fn Updater::camera(
  update : (@camera.Camera, UpdateContext) -> @camera.Camera raise SceneError,
) -> Updater {
  { behavior: UpdateCamera(update) }
}

///|
pub fn Scene::value_tracker(self : Scene, value : Double) -> ValueTracker {
  let tracker = { id: self.next_value_tracker_id }
  self.next_value_tracker_id += 1
  self.value_trackers[tracker] = value
  tracker
}

///|
pub fn Scene::value(
  self : Scene,
  tracker : ValueTracker,
) -> Double raise SceneError {
  match self.value_trackers.get(tracker) {
    Some(value) => value
    None => raise UnknownValueTracker(tracker)
  }
}

///|
pub fn Scene::set_value(
  self : Scene,
  tracker : ValueTracker,
  value : Double,
) -> Unit raise SceneError {
  ignore(self.value(tracker))
  self.value_trackers[tracker] = value
}

///|
pub fn Scene::increment_value(
  self : Scene,
  tracker : ValueTracker,
  delta : Double,
) -> Unit raise SceneError {
  self.set_value(tracker, self.value(tracker) + delta)
}

///|
pub fn Scene::add_updater(
  self : Scene,
  updater : Updater,
  call_now? : Bool = false,
) -> UpdaterId raise SceneError {
  self.validate_updater_target(updater)
  let id : UpdaterId = { updater_id: self.next_updater_id }
  let registered = { id, updater }
  if call_now {
    self.run_registered_updaters([registered], 0.0, force=true)
  }
  self.next_updater_id += 1
  self.updaters.push(registered)
  id
}

///|
pub fn Scene::remove_updater(self : Scene, id : UpdaterId) -> Bool {
  let before = self.updaters.length()
  self.updaters = self.updaters.filter(registered => registered.id != id)
  self.updaters.length() != before
}

///|
pub fn Scene::clear_updaters(self : Scene) -> Unit {
  self.updaters = []
}

///|
pub fn Scene::clear_object_updaters(
  self : Scene,
  id : ObjectId,
  recursive? : Bool = true,
) -> Unit raise SceneError {
  let ids = if recursive {
    self.family(id)
  } else {
    ignore(self.require_object(id))
    [id]
  }
  self.updaters = self.updaters.filter(registered => {
    match registered.updater.behavior {
      UpdateObject(target, _, _) => !ids.contains(target)
      _ => true
    }
  })
}

///|
pub fn Scene::clear_value_updaters(
  self : Scene,
  tracker : ValueTracker,
) -> Unit raise SceneError {
  ignore(self.value(tracker))
  self.updaters = self.updaters.filter(registered => {
    match registered.updater.behavior {
      UpdateValue(target, _) => target != tracker
      _ => true
    }
  })
}

///|
pub fn Scene::clear_camera_updaters(self : Scene) -> Unit {
  self.updaters = self.updaters.filter(registered => {
    match registered.updater.behavior {
      UpdateCamera(_) => false
      _ => true
    }
  })
}

///|
pub fn Scene::updater_count(self : Scene) -> Int {
  self.updaters.length()
}

///|
pub fn[T : @object.IntoObject] Scene::always_redraw(
  self : Scene,
  redraw : (UpdateContext) -> T raise SceneError,
) -> ObjectId raise SceneError {
  let object_redraw = context => @object.into_object(redraw(context))
  let object = object_redraw(self.update_context(0.0))
  let id = self.add(object)
  ignore(self.add_updater(Updater::redraw(id, object_redraw)))
  id
}

///|
pub fn Scene::advance(self : Scene, dt : Double) -> Unit raise SceneError {
  validate_delta_time(dt)
  let transaction = self.frame_transaction()
  transaction.time += dt
  transaction.run_updaters(dt)
  self.commit_frame_transaction(transaction)
}

///|
pub fn Scene::suspend_updating(
  self : Scene,
  id : ObjectId,
  recursive? : Bool = true,
) -> Unit raise SceneError {
  let targets = if recursive {
    self.family(id).map(id => ObjectTarget(id))
  } else {
    ignore(self.require_object(id))
    [ObjectTarget(id)]
  }
  self.push_updater_suspensions(targets)
}

///|
pub fn Scene::resume_updating(
  self : Scene,
  id : ObjectId,
  recursive? : Bool = true,
) -> Unit raise SceneError {
  let targets = if recursive {
    self.family(id).map(id => ObjectTarget(id))
  } else {
    ignore(self.require_object(id))
    [ObjectTarget(id)]
  }
  let resumed = self.pop_updater_suspensions(targets)
  self.run_updaters_for_targets(resumed, 0.0)
}

///|
pub fn Scene::suspend_value_updating(
  self : Scene,
  tracker : ValueTracker,
) -> Unit raise SceneError {
  ignore(self.value(tracker))
  self.push_updater_suspensions([ValueTarget(tracker)])
}

///|
pub fn Scene::resume_value_updating(
  self : Scene,
  tracker : ValueTracker,
) -> Unit raise SceneError {
  ignore(self.value(tracker))
  let resumed = self.pop_updater_suspensions([ValueTarget(tracker)])
  self.run_updaters_for_targets(resumed, 0.0)
}

///|
pub fn Scene::suspend_camera_updating(self : Scene) -> Unit {
  self.push_updater_suspensions([CameraTarget])
}

///|
pub fn Scene::resume_camera_updating(self : Scene) -> Unit raise SceneError {
  let resumed = self.pop_updater_suspensions([CameraTarget])
  self.run_updaters_for_targets(resumed, 0.0)
}

///|
fn Scene::validate_updater_target(
  self : Scene,
  updater : Updater,
) -> Unit raise SceneError {
  match updater.behavior {
    UpdateObject(id, _, _) => ignore(self.require_object(id))
    UpdateValue(tracker, _) => ignore(self.value(tracker))
    UpdateCamera(_) => ()
  }
}

///|
fn Scene::run_updaters(self : Scene, dt : Double) -> Unit raise SceneError {
  self.run_registered_updaters(self.updaters.copy(), dt)
}

///|
fn Scene::run_updaters_for_targets(
  self : Scene,
  targets : Array[UpdateTarget],
  dt : Double,
) -> Unit raise SceneError {
  if targets.length() > 0 {
    let selected = self.updaters.filter(registered => {
      targets.contains(registered.updater.target())
    })
    self.run_registered_updaters(selected, dt)
  }
}

///|
fn Scene::run_registered_updaters(
  self : Scene,
  updaters : Array[RegisteredUpdater],
  dt : Double,
  force? : Bool = false,
) -> Unit raise SceneError {
  validate_delta_time(dt)
  let active = if force {
    updaters
  } else {
    updaters.filter(registered => {
      self.updater_is_active(registered.updater.target())
    })
  }
  if active.length() == 0 {
    return
  }
  let frame_context = self.update_context(dt)
  let values : Map[ValueTracker, Double] = Map([])
  for registered in active {
    match registered.updater.behavior {
      UpdateValue(tracker, update) => {
        let current = values
          .get(tracker)
          .unwrap_or_else(() => frame_context.value(tracker))
        values[tracker] = update(current, frame_context)
      }
      _ => ()
    }
  }
  let object_context = frame_context.with_pending(values, Map([]))
  let objects : Map[ObjectId, PendingObjectUpdate] = Map([])
  let object_order : Array[ObjectId] = []
  for registered in active {
    match registered.updater.behavior {
      UpdateObject(id, mode, update) => {
        let current = objects
          .get(id)
          .map_or_else(() => object_context.object(id), pending => {
            pending.object
          })
        let next = update(current, object_context)
        let rebuild_family = mode == RebuildFamily ||
          objects.get(id).map_or(false, pending => pending.rebuild_family)
        if !objects.contains(id) {
          object_order.push(id)
        }
        objects[id] = { object: next, rebuild_family }
      }
      _ => ()
    }
  }
  let camera_context = frame_context.with_pending(values, objects)
  let mut camera : @camera.Camera? = None
  for registered in active {
    match registered.updater.behavior {
      UpdateCamera(update) => {
        let current = camera.unwrap_or(camera_context.camera())
        camera = Some(update(current, camera_context))
      }
      _ => ()
    }
  }
  self.validate_pending_updates(objects, values, camera)
  object_order.sort_by((left, right) => {
    self.family_depth(left) - self.family_depth(right)
  })
  let patches : Array[FramePatch] = []
  for id in object_order {
    match objects.get(id) {
      Some({ object, rebuild_family: true }) =>
        patches.push(FramePatch::rebuild(id, object))
      Some({ object, rebuild_family: false }) =>
        patches.push(FramePatch::put(id, object))
      None => ()
    }
  }
  for entry in values.iter() {
    let (tracker, value) = entry
    patches.push(FramePatch::set_value(tracker, value))
  }
  match camera {
    Some(camera) => patches.push(FramePatch::set_camera(camera))
    None => ()
  }
  self.apply_frame_patch(FramePatch::all(patches))
}

///|
fn UpdateContext::with_pending(
  self : UpdateContext,
  pending_values : Map[ValueTracker, Double],
  pending_objects : Map[ObjectId, PendingObjectUpdate],
) -> UpdateContext {
  let values = self.values.copy()
  for entry in pending_values.iter() {
    let (tracker, value) = entry
    values[tracker] = value
  }
  let objects = self.objects.copy()
  for entry in pending_objects.iter() {
    let (id, pending) = entry
    objects[id] = pending.object
  }
  { ..self, values, objects }
}

///|
fn Scene::validate_pending_updates(
  self : Scene,
  objects : Map[ObjectId, PendingObjectUpdate],
  values : Map[ValueTracker, Double],
  camera : @camera.Camera?,
) -> Unit raise SceneError {
  for entry in objects.iter() {
    let (id, pending) = entry
    if !pending.rebuild_family {
      self.validate_replacement_topology(id, pending.object)
    }
  }
  for entry in values.iter() {
    let (tracker, _) = entry
    ignore(self.value(tracker))
  }
  match camera {
    Some(camera) => validate_camera(camera)
    None => ()
  }
}

///|
fn Scene::update_context(self : Scene, dt : Double) -> UpdateContext {
  let objects : Map[ObjectId, @object.Object] = Map([])
  for entry in self.objects.iter() {
    let (id, _) = entry
    match self.materialize_object(id) {
      Some(object) => objects[id] = object
      None => ()
    }
  }
  {
    time: self.time,
    dt,
    objects,
    values: self.value_trackers.copy(),
    camera: self.camera,
  }
}

///|
fn Updater::target(self : Updater) -> UpdateTarget {
  match self.behavior {
    UpdateObject(id, _, _) => ObjectTarget(id)
    UpdateValue(tracker, _) => ValueTarget(tracker)
    UpdateCamera(_) => CameraTarget
  }
}

///|
fn Scene::updater_is_active(self : Scene, target : UpdateTarget) -> Bool {
  let suspended = self.updater_suspensions.get(target).unwrap_or(0) > 0
  if suspended {
    false
  } else {
    match target {
      ObjectTarget(id) => self.is_visible(id)
      ValueTarget(_) | CameraTarget => true
    }
  }
}

///|
fn Scene::push_updater_suspensions(
  self : Scene,
  targets : Array[UpdateTarget],
) -> Unit {
  for target in unique_update_targets(targets) {
    self.updater_suspensions[target] = self.updater_suspensions
      .get(target)
      .unwrap_or(0) +
      1
  }
}

///|
fn Scene::pop_updater_suspensions(
  self : Scene,
  targets : Array[UpdateTarget],
) -> Array[UpdateTarget] {
  let resumed : Array[UpdateTarget] = []
  for target in unique_update_targets(targets) {
    match self.updater_suspensions.get(target) {
      Some(count) if count > 1 => self.updater_suspensions[target] = count - 1
      Some(_) => {
        self.updater_suspensions.remove(target)
        resumed.push(target)
      }
      None => ()
    }
  }
  resumed
}

///|
fn unique_update_targets(targets : Array[UpdateTarget]) -> Array[UpdateTarget] {
  let unique : Array[UpdateTarget] = []
  for target in targets {
    if !unique.contains(target) {
      unique.push(target)
    }
  }
  unique
}

///|
fn Scene::family_depth(self : Scene, id : ObjectId) -> Int {
  match self.objects.get(id).bind(object => object.parent) {
    Some(parent) => 1 + self.family_depth(parent)
    None => 0
  }
}

///|
fn validate_delta_time(dt : Double) -> Unit raise SceneError {
  if dt < 0.0 || dt.is_nan() || dt.is_inf() {
    raise InvalidDeltaTime(dt)
  }
}
