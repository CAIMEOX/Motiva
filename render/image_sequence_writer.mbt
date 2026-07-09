///|
pub(all) struct ImageSequenceWriter {
  renderer : CairoRenderer
  output_dir : String
  frame_prefix : String
  frame_padding : Int
  play_config : @scene.PlayConfig
  mut next_frame_index : Int
}

///|
pub fn ImageSequenceWriter::new(
  renderer? : CairoRenderer = CairoRenderer::new(),
  output_dir? : String = "output/frames",
  frame_prefix? : String = "frame",
  frame_padding? : Int = 4,
  play_config? : @scene.PlayConfig = @scene.PlayConfig::image_sequence(),
) -> ImageSequenceWriter {
  {
    renderer,
    output_dir,
    frame_prefix,
    frame_padding,
    play_config,
    next_frame_index: 0,
  }
}

///|
pub fn ImageSequenceWriter::attach(
  self : ImageSequenceWriter,
  scene : @scene.Scene,
) -> Unit {
  scene.set_play_writer(
    Some(
      @scene.PlayWriter::new((scene, animations) => {
        self.write_play(scene, animations) catch {
          error => raise PlayWriteFailed(error)
        }
      }),
    ),
  )
}

///|
pub fn attach_image_sequence_writer(
  scene : @scene.Scene,
  writer : ImageSequenceWriter,
) -> Unit {
  writer.attach(scene)
}

///|
pub fn ImageSequenceWriter::frame_count(self : ImageSequenceWriter) -> Int {
  self.next_frame_index
}

///|
fn ImageSequenceWriter::write_play(
  self : ImageSequenceWriter,
  scene : @scene.Scene,
  animations : Array[@scene.Animation],
) -> Unit raise RenderError {
  let plan = try_scene(() => {
    scene.compile_play_plan(animations, config=self.play_config)
  })
  try_scene(() => plan.begin(scene))
  for frame_time in plan.frame_times() {
    try_scene(() => plan.apply_frame(scene, frame_time))
    self.renderer.write_scene_png(
      scene,
      self.frame_path(self.next_frame_index),
      frame_index=self.next_frame_index,
    )
    self.next_frame_index += 1
  }
  try_scene(() => plan.finish(scene))
}

///|
fn ImageSequenceWriter::frame_path(
  self : ImageSequenceWriter,
  frame_index : Int,
) -> String {
  "\{self.output_dir}/\{self.frame_prefix}_\{padded_frame_index(frame_index, self.frame_padding)}.png"
}

///|
fn padded_frame_index(index : Int, width : Int) -> String {
  index.to_string().pad_start(width, '0')
}
