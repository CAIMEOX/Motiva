///|
fn[T] try_scene(f : () -> T raise @scene.SceneError) -> T raise RenderError {
  f() catch {
    error => raise Scene(error)
  }
}

///|
pub fn[T : @scene.IntoAnimation] CairoRenderer::render_play(
  self : CairoRenderer,
  scene : @scene.Scene,
  animations : Array[T],
  config? : @scene.PlayConfig = @scene.PlayConfig::image_sequence(),
) -> Array[RenderedFrame] raise RenderError {
  let plan = try_scene(() => scene.compile_play_plan(animations, config~))
  let frames : Array[RenderedFrame] = []
  try_scene(() => plan.begin(scene))
  for frame_time in plan.frame_times() {
    try_scene(() => plan.apply_frame(scene, frame_time))
    frames.push(self.render_scene(scene, frame_index=frame_time.frame_index))
  }
  try_scene(() => plan.finish(scene))
  frames
}

///|
pub fn[T : @scene.IntoAnimation] CairoRenderer::write_play_pngs(
  self : CairoRenderer,
  scene : @scene.Scene,
  animations : Array[T],
  paths : Array[String],
  config? : @scene.PlayConfig = @scene.PlayConfig::image_sequence(),
) -> Unit raise RenderError {
  let plan = try_scene(() => scene.compile_play_plan(animations, config~))
  let expected = plan.frame_count()
  let actual = paths.length()
  if expected != actual {
    raise OutputFrameCountMismatch(expected~, actual~)
  }
  try_scene(() => plan.begin(scene))
  let frame_times = plan.frame_times()
  for index in 0..<frame_times.length() {
    match (frame_times.get(index), paths.get(index)) {
      (Some(frame_time), Some(path)) => {
        try_scene(() => plan.apply_frame(scene, frame_time))
        self.write_scene_png(scene, path, frame_index=frame_time.frame_index)
      }
      _ => ()
    }
  }
  try_scene(() => plan.finish(scene))
}
