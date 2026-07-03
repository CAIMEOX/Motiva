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
pub fn SceneConfig::default() -> SceneConfig {
  { frame_rate: 60.0, always_update_objects: false }
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
}

///|
pub(all) struct Scene {
  mut next_id : Int
  objects : Map[ObjectId, SceneObject]
  mut draw_order : Array[ObjectId]
  mut foreground : Array[ObjectId]
  mut time : Double
  config : SceneConfig
}

///|
pub fn Scene::new(config? : SceneConfig = SceneConfig::default()) -> Scene {
  { next_id: 0, objects: {}, draw_order: [], foreground: [], time: 0.0, config }
}

///|
pub fn[T : @object.IntoObject] Scene::object(
  self : Scene,
  x : T,
  id? : String = "",
) -> ObjectId {
  self.insert_object(@object.into_object(x, id~), Allocated)
}

///|
pub fn[T : @object.IntoObject] Scene::add(
  self : Scene,
  x : T,
  id? : String = "",
) -> ObjectId {
  let object_id = self.insert_object(@object.into_object(x, id~), Visible)
  self.draw_order.push(object_id)
  object_id
}

///|
pub fn[T : @object.IntoObject] Scene::add_foreground(
  self : Scene,
  x : T,
  id? : String = "",
) -> ObjectId {
  let object_id = self.add(x, id~)
  self.foreground.push(object_id)
  object_id
}

///|
pub fn Scene::show(self : Scene, id : ObjectId) -> Unit raise SceneError {
  let scene_object = self.require_object(id)
  self.remove_from_visible_lists(id)
  self.objects[id] = { ..scene_object, state: Visible }
  self.draw_order.push(id)
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
  self.remove_from_visible_lists(id)
  let next_state = if scene_object.state == Visible {
    Removed
  } else {
    scene_object.state
  }
  self.objects[id] = { ..scene_object, state: next_state }
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
  name? : String = "",
) -> Unit raise SceneError {
  self.replace_object(id, x.to_object(id=name))
}

///|
pub fn Scene::clear(self : Scene) -> Unit {
  for id in self.draw_order {
    match self.objects.get(id) {
      None => ()
      Some(scene_object) =>
        self.objects[id] = { ..scene_object, state: Removed }
    }
  }
  self.draw_order = []
  self.foreground = []
}

///|
pub fn Scene::get(self : Scene, id : ObjectId) -> @object.Object? {
  self.objects.get(id).map(scene_object => scene_object.object)
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
  let id = { value: self.next_id }
  self.next_id += 1
  self.objects[id] = { object, state, parent: None, children: [] }
  id
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

///|
fn Scene::replace_object(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> Unit raise SceneError {
  let scene_object = self.require_object(id)
  self.objects[id] = { ..scene_object, object, }
}

///|
fn Scene::remove_from_visible_lists(self : Scene, id : ObjectId) -> Unit {
  self.draw_order = self.draw_order.filter(current => current != id)
  self.foreground = self.foreground.filter(current => current != id)
}
