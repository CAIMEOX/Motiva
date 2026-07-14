///|
pub struct MovieWriter {
  priv image_sequence : ImageSequenceWriter
  priv frame_rate : @ffmpeg.FrameRate
  priv movie_output : @ffmpeg.MovieOutput
  priv profile : @ffmpeg.EncodeProfile
  priv encoder : @ffmpeg.Ffmpeg
}

///|
pub fn MovieWriter::mp4(
  renderer? : CairoRenderer = CairoRenderer::new(),
  output_dir? : String = "output/frames",
  frame_prefix? : String = "frame",
  frame_padding? : Int = 4,
  play_config? : @scene.PlayConfig = @scene.PlayConfig::default(),
  frame_rate~ : Double,
  movie_path~ : String,
) -> MovieWriter {
  {
    image_sequence: ImageSequenceWriter::new(
      renderer~,
      output_dir~,
      frame_prefix~,
      frame_padding~,
      play_config~,
    ),
    frame_rate: @ffmpeg.FrameRate::fps(frame_rate),
    movie_output: @ffmpeg.MovieOutput::mp4(movie_path),
    profile: @ffmpeg.EncodeProfile::manim_mp4(),
    encoder: @ffmpeg.Ffmpeg::default(),
  }
}

///|
pub fn MovieWriter::attach(self : MovieWriter, scene : @scene.Scene) -> Unit {
  self.image_sequence.attach(scene)
}

///|
pub fn MovieWriter::frame_count(self : MovieWriter) -> Int {
  self.image_sequence.frame_count()
}

///|
pub async fn MovieWriter::finish(self : MovieWriter) -> Unit raise RenderError {
  self.encoder.encode_image_sequence(
    @ffmpeg.ImageSequenceInput::png(
      dir=self.image_sequence.output_dir,
      prefix=self.image_sequence.frame_prefix,
      padding=self.image_sequence.frame_padding,
      frame_rate=self.frame_rate,
    ),
    self.movie_output,
    profile=self.profile,
  ) catch {
    error => raise Ffmpeg(error)
  }
}
