///|
pub fn Scene::parent(self : Scene, id : ObjectId) -> ObjectId? raise SceneError {
  self.require_object(id).parent
}

///|
pub fn Scene::children(
  self : Scene,
  id : ObjectId,
) -> Array[ObjectId] raise SceneError {
  self.require_object(id).children.copy()
}

///|
pub fn Scene::family(
  self : Scene,
  id : ObjectId,
) -> Array[ObjectId] raise SceneError {
  ignore(self.require_object(id))
  self.collect_family(id)
}

///|
fn Scene::collect_family(self : Scene, id : ObjectId) -> Array[ObjectId] {
  match self.objects.get(id) {
    None => []
    Some(scene_object) =>
      Iter::singleton(id)
      .concat(
        scene_object.children
        .iter()
        .flat_map(child => self.collect_family(child).iter()),
      )
      .to_array()
  }
}

///|
fn Scene::materialize_object(self : Scene, id : ObjectId) -> @object.Object? {
  self
  .materialize_local_object(id)
  .map(object => {
    object.with_transform(
      object.transform.then(self.parent_world_transform(id)),
    )
  })
}

///|
fn Scene::materialize_local_object(
  self : Scene,
  id : ObjectId,
) -> @object.Object? {
  self.objects
  .get(id)
  .map(scene_object => {
    match scene_object.object.node {
      Group(_) => {
        let children = scene_object.children.filter_map(child => {
          self.materialize_local_object(child)
        })
        @object.Object::new(
          node=Group(children),
          transform=scene_object.object.transform,
          z_index=scene_object.object.z_index,
        )
      }
      _ => scene_object.object
    }
  })
}

///|
fn Scene::require_materialized_object(
  self : Scene,
  id : ObjectId,
) -> @object.Object raise SceneError {
  match self.materialize_object(id) {
    None => raise UnknownObject(id)
    Some(object) => object
  }
}

///|
fn Scene::insert_object_with_parent(
  self : Scene,
  object : @object.Object,
  state : ObjectState,
  parent : ObjectId?,
) -> ObjectId {
  let id = { value: self.next_id }
  self.next_id += 1
  match object.node {
    Group(children) => {
      let shell = family_shell(object)
      self.objects[id] = { object: shell, state, parent, children: [] }
      let child_ids = children.map(child => {
        self.insert_object_with_parent(child, state, Some(id))
      })
      self.objects[id] = { object: shell, state, parent, children: child_ids }
    }
    _ => self.objects[id] = { object, state, parent, children: [] }
  }
  id
}

///|
fn Scene::replace_object(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> Unit raise SceneError {
  let local_object = self.to_local_object(id, object)
  self.replace_local_object(id, local_object)
}

///|
fn Scene::replace_local_object(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> Unit raise SceneError {
  self.validate_replacement_topology(id, object)
  self.write_local_object(id, object)
}

///|
fn Scene::validate_replacement_topology(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> Unit raise SceneError {
  let scene_object = self.require_object(id)
  match (scene_object.object.node, object.node) {
    (Group(_), Group(children)) => {
      if scene_object.children.length() != children.length() {
        raise FamilyTopologyMismatch(id)
      }
      for index in 0..<children.length() {
        match (scene_object.children.get(index), children.get(index)) {
          (Some(child_id), Some(child)) =>
            self.validate_replacement_topology(child_id, child)
          _ => raise FamilyTopologyMismatch(id)
        }
      }
    }
    (Group(_), _) | (_, Group(_)) => raise FamilyTopologyMismatch(id)
    _ => ()
  }
}

///|
fn Scene::write_local_object(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> Unit raise SceneError {
  let scene_object = self.require_object(id)
  match object.node {
    Group(children) => {
      for index in 0..<children.length() {
        match (scene_object.children.get(index), children.get(index)) {
          (Some(child_id), Some(child)) =>
            self.write_local_object(child_id, child)
          _ => ()
        }
      }
      self.objects[id] = {
        object: family_shell(object),
        state: scene_object.state,
        parent: scene_object.parent,
        children: scene_object.children,
      }
    }
    _ =>
      self.objects[id] = {
        object,
        state: scene_object.state,
        parent: scene_object.parent,
        children: [],
      }
  }
}

///|
fn Scene::family_root(self : Scene, id : ObjectId) -> ObjectId {
  match self.objects.get(id) {
    Some({ parent: Some(parent), .. }) => self.family_root(parent)
    _ => id
  }
}

///|
fn Scene::set_ancestors_visible(self : Scene, id : ObjectId) -> Unit {
  match self.objects.get(id) {
    Some({ parent: Some(parent), .. }) => {
      match self.objects.get(parent) {
        Some(scene_object) =>
          self.objects[parent] = { ..scene_object, state: Visible }
        None => ()
      }
      self.set_ancestors_visible(parent)
    }
    _ => ()
  }
}

///|
fn Scene::prune_empty_ancestors(self : Scene, id : ObjectId?) -> Unit {
  match id {
    None => ()
    Some(id) =>
      match self.objects.get(id) {
        None => ()
        Some(scene_object) => {
          let has_visible_child = scene_object.children.any(child => {
            self.objects
            .get(child)
            .map_or(false, child_object => child_object.state == Visible)
          })
          if !has_visible_child {
            self.objects[id] = { ..scene_object, state: Removed }
            self.prune_empty_ancestors(scene_object.parent)
          }
        }
      }
  }
}

///|
fn Scene::same_family_branch(
  self : Scene,
  first : ObjectId,
  second : ObjectId,
) -> Bool {
  first == second ||
  self.is_ancestor(first, second) ||
  self.is_ancestor(second, first)
}

///|
fn Scene::is_ancestor(
  self : Scene,
  ancestor : ObjectId,
  descendant : ObjectId,
) -> Bool {
  match self.objects.get(descendant) {
    Some({ parent: Some(parent), .. }) =>
      parent == ancestor || self.is_ancestor(ancestor, parent)
    _ => false
  }
}

///|
fn Scene::family_has_visible_member(self : Scene, id : ObjectId) -> Bool {
  self.objects
  .get(id)
  .map_or(false, scene_object => {
    scene_object.state == Visible ||
    scene_object.children.any(child => self.family_has_visible_member(child))
  })
}

///|
fn Scene::set_subtree_state(
  self : Scene,
  id : ObjectId,
  state : ObjectState,
) -> Unit {
  match self.objects.get(id) {
    None => ()
    Some(scene_object) => {
      self.objects[id] = { ..scene_object, state, }
      scene_object.children.each(child => self.set_subtree_state(child, state))
    }
  }
}

///|
fn family_shell(object : @object.Object) -> @object.Object {
  @object.Object::new(
    node=Group([]),
    transform=object.transform,
    z_index=object.z_index,
  )
}

///|
fn Scene::parent_world_transform(
  self : Scene,
  id : ObjectId,
) -> @object.Transform {
  match self.objects.get(id) {
    None => @object.Transform::identity()
    Some(scene_object) =>
      scene_object.parent.map_or(@object.Transform::identity(), parent => {
        self.world_transform(parent)
      })
  }
}

///|
fn Scene::world_transform(self : Scene, id : ObjectId) -> @object.Transform {
  self.objects
  .get(id)
  .map_or(@object.Transform::identity(), scene_object => {
    scene_object.object.transform.then(self.parent_world_transform(id))
  })
}

///|
fn Scene::to_local_object(
  self : Scene,
  id : ObjectId,
  object : @object.Object,
) -> @object.Object raise SceneError {
  match inverse_transform(self.parent_world_transform(id)) {
    None => raise NonInvertibleFamilyTransform(id)
    Some(inverse) => object.with_transform(object.transform.then(inverse))
  }
}

///|
fn inverse_transform(transform : @object.Transform) -> @object.Transform? {
  let a = transform.m00
  let b = transform.m01
  let c = transform.m02
  let d = transform.m10
  let e = transform.m11
  let f = transform.m12
  let g = transform.m20
  let h = transform.m21
  let i = transform.m22
  let determinant = a * (e * i - f * h) -
    b * (d * i - f * g) +
    c * (d * h - e * g)
  if determinant.is_nan() || Double::abs(determinant) < 0.000000000001 {
    None
  } else {
    let m00 = (e * i - f * h) / determinant
    let m01 = (c * h - b * i) / determinant
    let m02 = (b * f - c * e) / determinant
    let m10 = (f * g - d * i) / determinant
    let m11 = (a * i - c * g) / determinant
    let m12 = (c * d - a * f) / determinant
    let m20 = (d * h - e * g) / determinant
    let m21 = (b * g - a * h) / determinant
    let m22 = (a * e - b * d) / determinant
    Some({
      m00,
      m01,
      m02,
      m03: 0.0 -
      (m00 * transform.m03 + m01 * transform.m13 + m02 * transform.m23),
      m10,
      m11,
      m12,
      m13: 0.0 -
      (m10 * transform.m03 + m11 * transform.m13 + m12 * transform.m23),
      m20,
      m21,
      m22,
      m23: 0.0 -
      (m20 * transform.m03 + m21 * transform.m13 + m22 * transform.m23),
    })
  }
}
