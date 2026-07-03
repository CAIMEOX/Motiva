///|
pub fn[T : IntoAnimation] Scene::play(
  self : Scene,
  animations : Array[T],
) -> Unit raise SceneError {
  let compiled = animations.map(into_animation)
  let run_time = compiled.fold(init=0.0, (duration, animation) => {
    if animation.timing.run_time > duration {
      animation.timing.run_time
    } else {
      duration
    }
  })
  for animation in compiled {
    self.finish_animation(animation)
  }
  self.time += run_time
}

///|
pub fn Scene::time(self : Scene) -> Double {
  self.time
}

///|
fn Scene::finish_animation(
  self : Scene,
  animation : Animation,
) -> Unit raise SceneError {
  match animation.kind {
    Wait => ()
    Create(id) | FadeIn(id) => self.show(id)
    FadeOut(id) => self.remove(id)
    Transform(id, target) => {
      self.replace_object(id, target)
      self.show_if_hidden(id)
    }
    ApplyOps(id, ops) => {
      let scene_object = self.require_object(id)
      let target = ops.fold(init=scene_object.object, (object, op) => {
        op.apply(object)
      })
      self.replace_object(id, target)
      self.show_if_hidden(id)
    }
  }
}

///|
fn Scene::show_if_hidden(self : Scene, id : ObjectId) -> Unit raise SceneError {
  if !self.is_visible(id) {
    self.show(id)
  }
}
