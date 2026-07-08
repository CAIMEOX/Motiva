///|
pub async fn Ffmpeg::encode_image_sequence(
  self : Ffmpeg,
  input : ImageSequenceInput,
  output : MovieOutput,
  profile? : EncodeProfile = EncodeProfile::manim_mp4(),
) -> Unit raise FfmpegError {
  self.run(self.encode_image_sequence_argv(input, output, profile))
}

///|
pub async fn Ffmpeg::concat_movies(
  self : Ffmpeg,
  inputs : Array[MovieInput],
  output : MovieOutput,
  list_path~ : String,
  mode? : ConcatMode = StreamCopy,
) -> Unit raise FfmpegError {
  @fs.write_file(
    list_path,
    concat_file_text(inputs),
    create_mode=CreateOrTruncate,
  ) catch {
    error => raise Host(error)
  }
  self.run(self.concat_movies_argv(list_path, output, mode))
}

///|
pub async fn Ffmpeg::transcode_audio(
  self : Ffmpeg,
  input : AudioInput,
  output : AudioOutput,
  codec : AudioCodec,
) -> Unit raise FfmpegError {
  self.run(self.transcode_audio_argv(input, output, codec))
}

///|
pub async fn Ffmpeg::mux_audio(
  self : Ffmpeg,
  video : MovieInput,
  audio : AudioInput,
  output : MovieOutput,
  audio_codec? : AudioCodec = CopyAudio,
  shortest? : Bool = true,
) -> Unit raise FfmpegError {
  self.run(self.mux_audio_argv(video, audio, output, audio_codec, shortest))
}

///|
pub async fn Ffmpeg::make_gif(
  self : Ffmpeg,
  input : MovieInput,
  output : GifOutput,
  options? : GifOptions = GifOptions::default(),
) -> Unit raise FfmpegError {
  self.run(self.make_gif_argv(input, output, options))
}

///|
async fn Ffmpeg::run(
  self : Ffmpeg,
  argv : Array[String],
) -> Unit raise FfmpegError {
  let (exit_code, stdout, stderr) = @process.collect_output(self.binary, argv) catch {
    error => raise Host(error)
  }
  if exit_code != 0 {
    raise CommandFailed(
      exit_code~,
      stdout=output_text(stdout),
      stderr=output_text(stderr),
    )
  }
}

///|
fn output_text(data : &@io.Data) -> String {
  data.text() catch {
    _ => "<non-utf8 output>"
  }
}
