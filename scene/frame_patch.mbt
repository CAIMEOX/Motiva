///|
priv enum FrameOp {
  Put(ObjectId, @object.Object)
  EnsureVisible(ObjectId)
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
fn FramePatch::ensure_visible(id : ObjectId) -> FramePatch {
  FramePatch::from_ops([EnsureVisible(id)])
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
  patch.ops.each(op => {
    match op {
      Put(id, object) => self.replace_object(id, object)
      EnsureVisible(id) => self.ensure_visible(id)
      Hide(id) => self.remove(id)
    }
  })
}

///|
fn Scene::ensure_visible(self : Scene, id : ObjectId) -> Unit raise SceneError {
  if !self.is_visible(id) {
    self.show(id)
  } else {
    ignore(self.require_object(id))
  }
}
