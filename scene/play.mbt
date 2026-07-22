///|
pub fn[T : IntoAnimation] Scene::play(
  self : Scene,
  animations : Array[T],
) -> Unit raise SceneError {
  let animations = animations.map(animation => into_animation(animation))
  match self.play_writer {
    None => self.play_immediate(animations)
    Some(writer) => writer.write(self, animations)
  }
}

///|
pub fn Scene::play_immediate(
  self : Scene,
  animations : Array[Animation],
  config? : PlayConfig = PlayConfig::default(),
) -> Unit raise SceneError {
  let plan = self.compile_play_plan(animations, config~)
  plan.begin(self)
  for frame in plan.frame_times() {
    plan.apply_frame(self, frame)
  }
  plan.finish(self)
}

///|
pub fn Scene::time(self : Scene) -> Double {
  self.time
}
