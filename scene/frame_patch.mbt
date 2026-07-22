///|
priv enum FrameOp {
  Put(ObjectId, @object.Object)
  Rebuild(ObjectId, @object.Object)
  SetTrackedValue(ValueTracker, Double)
  SetCamera(@camera.Camera)
  EnsureVisible(ObjectId)
  ShowSubtree(ObjectId)
  Hide(ObjectId)
}

///|
priv struct FramePatch {
  ops : Array[FrameOp]
}

///|
fn FramePatch::empty() -> FramePatch {
  { ops: [] }
}

///|
fn FramePatch::from_ops(ops : Array[FrameOp]) -> FramePatch {
  { ops, }
}

///|
fn FramePatch::put(id : ObjectId, object : @object.Object) -> FramePatch {
  FramePatch::from_ops([Put(id, object)])
}

///|
fn FramePatch::rebuild(id : ObjectId, object : @object.Object) -> FramePatch {
  FramePatch::from_ops([Rebuild(id, object)])
}

///|
fn FramePatch::set_value(tracker : ValueTracker, value : Double) -> FramePatch {
  FramePatch::from_ops([SetTrackedValue(tracker, value)])
}

///|
fn FramePatch::set_camera(camera : @camera.Camera) -> FramePatch {
  FramePatch::from_ops([SetCamera(camera)])
}

///|
fn FramePatch::ensure_visible(id : ObjectId) -> FramePatch {
  FramePatch::from_ops([EnsureVisible(id)])
}

///|
fn FramePatch::show_subtree(id : ObjectId) -> FramePatch {
  FramePatch::from_ops([ShowSubtree(id)])
}

///|
fn FramePatch::hide(id : ObjectId) -> FramePatch {
  FramePatch::from_ops([Hide(id)])
}

///|
fn FramePatch::then(self : FramePatch, next : FramePatch) -> FramePatch {
  { ops: self.ops.iter().concat(next.ops.iter()).to_array() }
}

///|
fn FramePatch::all(patches : Array[FramePatch]) -> FramePatch {
  { ops: patches.iter().flat_map(patch => patch.ops.iter()).to_array() }
}

///|
fn Scene::apply_frame_patch(
  self : Scene,
  patch : FramePatch,
) -> Unit raise SceneError {
  if patch.ops.length() == 0 {
    return
  }
  let transaction = self.frame_transaction()
  transaction.apply_frame_patch_unchecked(patch)
  self.commit_frame_transaction(transaction)
}

///|
fn Scene::apply_frame_patch_unchecked(
  self : Scene,
  patch : FramePatch,
) -> Unit raise SceneError {
  patch.ops.each(op => {
    match op {
      Put(id, object) => self.replace_object(id, object)
      Rebuild(id, object) => self.rebuild_object(id, object)
      SetTrackedValue(tracker, value) => self.set_value(tracker, value)
      SetCamera(camera) => self.set_camera(camera)
      EnsureVisible(id) => self.ensure_visible(id)
      ShowSubtree(id) => self.show(id)
      Hide(id) => self.remove(id)
    }
  })
}

///|
fn Scene::frame_transaction(self : Scene) -> Scene {
  {
    next_id: self.next_id,
    objects: self.objects.copy(),
    draw_order: self.draw_order.copy(),
    foreground: self.foreground.copy(),
    time: self.time,
    config: self.config,
    camera: self.camera,
    play_writer: self.play_writer,
    next_value_tracker_id: self.next_value_tracker_id,
    value_trackers: self.value_trackers.copy(),
    next_updater_id: self.next_updater_id,
    updaters: self.updaters.copy(),
    updater_suspensions: self.updater_suspensions.copy(),
  }
}

///|
fn Scene::commit_frame_transaction(self : Scene, transaction : Scene) -> Unit {
  self.next_id = transaction.next_id
  self.objects.clear()
  for entry in transaction.objects.iter() {
    let (id, object) = entry
    self.objects[id] = object
  }
  self.draw_order = transaction.draw_order
  self.foreground = transaction.foreground
  self.time = transaction.time
  self.camera = transaction.camera
  self.value_trackers.clear()
  for entry in transaction.value_trackers.iter() {
    let (tracker, value) = entry
    self.value_trackers[tracker] = value
  }
}

///|
fn Scene::ensure_visible(self : Scene, id : ObjectId) -> Unit raise SceneError {
  if !self.is_visible(id) {
    self.show(id)
  } else {
    ignore(self.require_object(id))
  }
}
