///|
pub fn[T : IntoAnimation] Scene::play(
  self : Scene,
  animations : Array[T],
) -> Unit raise SceneError {
  let compiled = animations.map(into_animation)
  let active_animations = compiled.map(animation => {
    ActiveAnimation::compile(self, animation)
  })
  let _affected_ids = active_animations.fold(init=[], (ids, animation) => {
    let next = ids.copy()
    next.append(animation.affected_ids())
    next
  })
  let run_time = active_animations.fold(init=0.0, (duration, animation) => {
    if animation.run_time() > duration {
      animation.run_time()
    } else {
      duration
    }
  })
  for animation in active_animations {
    self.apply_frame_patch(animation.begin_patch())
  }
  for animation in active_animations {
    self.apply_frame_patch(animation.finish_patch())
  }
  self.time += run_time
}

///|
pub fn Scene::time(self : Scene) -> Double {
  self.time
}
