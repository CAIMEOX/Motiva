///|
pub fn[T : IntoAnimation] Scene::play(
  self : Scene,
  animations : Array[T],
) -> Unit raise SceneError {
  let plan = self.compile_play_plan(animations)
  plan.begin(self)
  plan.finish(self)
}

///|
pub fn Scene::time(self : Scene) -> Double {
  self.time
}
