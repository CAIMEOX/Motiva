///|
pub(all) struct ObjectId {
  value : Int
} derive(Eq, Hash)

///|
pub fn ObjectId::value(self : ObjectId) -> Int {
  self.value
}

///|
pub(all) enum ObjectState {
  Allocated
  Visible
  Removed
} derive(Eq)

///|
pub(all) struct SceneConfig {
  frame_rate : Double
  always_update_objects : Bool
}

///|
pub fn SceneConfig::new(
  frame_rate? : Double = 60.0,
  always_update_objects? : Bool = false,
) -> SceneConfig {
  { frame_rate, always_update_objects }
}

///|
pub impl Default for SceneConfig with fn default() -> SceneConfig {
  SceneConfig::new()
}

///|
pub(all) struct SceneObject {
  object : @object.Object
  state : ObjectState
  parent : ObjectId?
  children : Array[ObjectId]
}

///|
pub(all) suberror SceneError {
  UnknownObject(ObjectId)
  UnknownFamilyPath(ObjectId, @object.FamilyPath)
  NonInvertibleFamilyTransform(ObjectId)
  FamilyTopologyMismatch(ObjectId)
  ConflictingFamilyAnimations(ObjectId, ObjectId)
  EmptyPlay
  InvalidRunTime(Double)
  InvalidFrameRate(Double)
  PlayWriteFailed(Error)
}

///|
pub(all) struct PlayWriter {
  run : (Scene, Array[Animation]) -> Unit raise SceneError
}

///|
pub(all) struct Scene {
  mut next_id : Int
  objects : Map[ObjectId, SceneObject]
  mut draw_order : Array[ObjectId]
  mut foreground : Array[ObjectId]
  mut time : Double
  config : SceneConfig
  mut play_writer : PlayWriter?
}

///|
pub fn Scene::new(config? : SceneConfig = SceneConfig::default()) -> Scene {
  {
    next_id: 0,
    objects: {},
    draw_order: [],
    foreground: [],
    time: 0.0,
    config,
    play_writer: None,
  }
}

///|
pub fn PlayWriter::new(
  run : (Scene, Array[Animation]) -> Unit raise SceneError,
) -> PlayWriter {
  { run, }
}

///|
pub fn PlayWriter::write(
  self : PlayWriter,
  scene : Scene,
  animations : Array[Animation],
) -> Unit raise SceneError {
  (self.run)(scene, animations)
}

///|
pub fn Scene::set_play_writer(self : Scene, writer : PlayWriter?) -> Unit {
  self.play_writer = writer
}

///|
pub fn[T : @object.IntoObject] Scene::object(self : Scene, x : T) -> ObjectId {
  self.insert_object(@object.into_object(x), Allocated)
}

///|
pub fn[T : @object.IntoObject] Scene::add(self : Scene, x : T) -> ObjectId {
  let object_id = self.insert_object(@object.into_object(x), Visible)
  self.draw_order.push(object_id)
  object_id
}

///|
pub fn[T : @object.IntoObject] Scene::add_foreground(
  self : Scene,
  x : T,
) -> ObjectId {
  let object_id = self.add(x)
  self.foreground.push(object_id)
  object_id
}

///|
pub fn Scene::show(self : Scene, id : ObjectId) -> Unit raise SceneError {
  ignore(self.require_object(id))
  self.set_subtree_state(id, Visible)
  self.set_ancestors_visible(id)
  let root = self.family_root(id)
  self.draw_order = self.draw_order.filter(current => current != root)
  self.draw_order.push(root)
}

///|
pub fn Scene::show_foreground(
  self : Scene,
  id : ObjectId,
) -> Unit raise SceneError {
  self.show(id)
  self.foreground = self.foreground.filter(current => current != id)
  self.foreground.push(id)
}

///|
pub fn Scene::remove(self : Scene, id : ObjectId) -> Unit raise SceneError {
  let scene_object = self.require_object(id)
  if self.family_has_visible_member(id) {
    let root = self.family_root(id)
    let removed_family = self.collect_family(id)
    self.set_subtree_state(id, Removed)
    self.prune_empty_ancestors(scene_object.parent)
    self.foreground = self.foreground.filter(current => {
      !removed_family.contains(current)
    })
    if !self.family_has_visible_member(root) {
      self.draw_order = self.draw_order.filter(current => current != root)
    }
  }
}

///|
pub fn Scene::remove_foreground(
  self : Scene,
  id : ObjectId,
) -> Unit raise SceneError {
  ignore(self.require_object(id))
  self.foreground = self.foreground.filter(current => current != id)
}

///|
pub fn[T : @object.IntoObject] Scene::replace(
  self : Scene,
  id : ObjectId,
  x : T,
) -> Unit raise SceneError {
  self.replace_object(id, x.to_object())
}

///|
pub fn Scene::clear(self : Scene) -> Unit {
  self.draw_order.each(id => self.set_subtree_state(id, Removed))
  self.draw_order = []
  self.foreground = []
}

///|
pub fn Scene::get(self : Scene, id : ObjectId) -> @object.Object? {
  self.materialize_object(id)
}

///|
pub fn Scene::state(self : Scene, id : ObjectId) -> ObjectState? {
  self.objects.get(id).map(scene_object => scene_object.state)
}

///|
pub fn Scene::is_visible(self : Scene, id : ObjectId) -> Bool {
  self.state(id).map_or(false, state => state == Visible)
}

///|
pub fn Scene::visible_objects(self : Scene) -> Array[ObjectId] {
  self.draw_order.copy()
}

///|
pub fn Scene::foreground_objects(self : Scene) -> Array[ObjectId] {
  self.foreground.copy()
}

///|
pub fn Scene::object_count(self : Scene) -> Int {
  self.objects.length()
}

///|
pub fn Scene::visible_count(self : Scene) -> Int {
  self.draw_order.length()
}

///|
fn Scene::insert_object(
  self : Scene,
  object : @object.Object,
  state : ObjectState,
) -> ObjectId {
  self.insert_object_with_parent(object, state, None)
}

///|
fn Scene::require_object(
  self : Scene,
  id : ObjectId,
) -> SceneObject raise SceneError {
  match self.objects.get(id) {
    None => raise UnknownObject(id)
    Some(scene_object) => scene_object
  }
}
