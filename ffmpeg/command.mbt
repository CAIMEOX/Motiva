///|
priv struct ArgvBuilder {
  args : Array[String]
}

///|
fn ArgvBuilder::new() -> ArgvBuilder {
  { args: [] }
}

///|
fn ArgvBuilder::push(self : ArgvBuilder, arg : String) -> Unit {
  self.args.push(arg)
}

///|
fn ArgvBuilder::option(
  self : ArgvBuilder,
  name : String,
  value : String,
) -> Unit {
  self.args.push(name)
  self.args.push(value)
}

///|
fn ArgvBuilder::finish(self : ArgvBuilder) -> Array[String] {
  self.args.copy()
}

///|
fn Ffmpeg::base_argv(self : Ffmpeg) -> ArgvBuilder {
  let builder = ArgvBuilder::new()
  builder.push(if self.overwrite { "-y" } else { "-n" })
  builder.option("-loglevel", self.log_level.to_arg())
  builder
}

///|
fn LogLevel::to_arg(self : LogLevel) -> String {
  match self {
    Quiet => "quiet"
    Panic => "panic"
    Fatal => "fatal"
    Error => "error"
    Warning => "warning"
    Info => "info"
    Verbose => "verbose"
    Debug => "debug"
    Trace => "trace"
  }
}

///|
fn ImageFormat::extension(self : ImageFormat) -> String {
  match self {
    Png => "png"
  }
}

///|
fn FrameRate::to_arg(self : FrameRate) -> String raise FfmpegError {
  if self.value <= 0.0 || self.value.is_nan() || self.value.is_inf() {
    raise InvalidFrameRate(self.value)
  }
  self.value.to_string()
}

///|
fn ImageSequenceInput::pattern(
  self : ImageSequenceInput,
) -> String raise FfmpegError {
  if self.padding <= 0 {
    raise InvalidFramePadding(self.padding)
  }
  "\{self.dir}/\{self.prefix}_%0\{self.padding}d.\{self.format.extension()}"
}

///|
fn VideoCodec::write_args(self : VideoCodec, builder : ArgvBuilder) -> Unit {
  match self {
    CopyVideo => builder.option("-c:v", "copy")
    Libx264(crf) => {
      builder.option("-c:v", "libx264")
      builder.option("-crf", crf.to_string())
    }
    LibvpxVp9 => builder.option("-c:v", "libvpx-vp9")
    Qtrle => builder.option("-c:v", "qtrle")
    Gif => builder.option("-c:v", "gif")
  }
}

///|
fn AudioCodec::to_arg(self : AudioCodec) -> String {
  match self {
    CopyAudio => "copy"
    Aac => "aac"
    LibVorbis => "libvorbis"
    PcmS16le => "pcm_s16le"
  }
}

///|
fn PixelFormat::to_arg(self : PixelFormat) -> String {
  match self {
    Yuv420p => "yuv420p"
    Yuva420p => "yuva420p"
    Argb => "argb"
    Rgb8 => "rgb8"
    Pal8 => "pal8"
  }
}

///|
fn EncodeProfile::write_args(
  self : EncodeProfile,
  builder : ArgvBuilder,
) -> Unit {
  self.video_codec.write_args(builder)
  builder.option("-pix_fmt", self.pixel_format.to_arg())
  if self.no_audio {
    builder.push("-an")
  }
}

///|
fn Ffmpeg::encode_image_sequence_argv(
  self : Ffmpeg,
  input : ImageSequenceInput,
  output : MovieOutput,
  profile : EncodeProfile,
) -> Array[String] raise FfmpegError {
  let builder = self.base_argv()
  builder.option("-framerate", input.frame_rate.to_arg())
  builder.option("-i", input.pattern())
  profile.write_args(builder)
  builder.push(output.path)
  builder.finish()
}

///|
fn Ffmpeg::concat_movies_argv(
  self : Ffmpeg,
  list_path : String,
  output : MovieOutput,
  mode : ConcatMode,
) -> Array[String] {
  let builder = self.base_argv()
  builder.option("-f", "concat")
  builder.option("-safe", "0")
  builder.option("-i", list_path)
  match mode {
    StreamCopy => builder.option("-c", "copy")
    Reencode(profile) => profile.write_args(builder)
  }
  builder.push(output.path)
  builder.finish()
}

///|
fn Ffmpeg::transcode_audio_argv(
  self : Ffmpeg,
  input : AudioInput,
  output : AudioOutput,
  codec : AudioCodec,
) -> Array[String] {
  let builder = self.base_argv()
  builder.option("-i", input.path)
  builder.option("-c:a", codec.to_arg())
  builder.push(output.path)
  builder.finish()
}

///|
fn Ffmpeg::mux_audio_argv(
  self : Ffmpeg,
  video : MovieInput,
  audio : AudioInput,
  output : MovieOutput,
  audio_codec : AudioCodec,
  shortest : Bool,
) -> Array[String] {
  let builder = self.base_argv()
  builder.option("-i", video.path)
  builder.option("-i", audio.path)
  builder.option("-c:v", "copy")
  builder.option("-c:a", audio_codec.to_arg())
  if shortest {
    builder.push("-shortest")
  }
  builder.push(output.path)
  builder.finish()
}

///|
fn Ffmpeg::make_gif_argv(
  self : Ffmpeg,
  input : MovieInput,
  output : GifOutput,
  options : GifOptions,
) -> Array[String] raise FfmpegError {
  let builder = self.base_argv()
  builder.option("-i", input.path)
  match options.frame_rate {
    None => ()
    Some(frame_rate) => builder.option("-r", frame_rate.to_arg())
  }
  builder.option(
    "-vf",
    if options.transparent {
      "split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    } else {
      "split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    },
  )
  Gif.write_args(builder)
  builder.option("-pix_fmt", if options.transparent { "pal8" } else { "rgb8" })
  builder.push(output.path)
  builder.finish()
}

///|
fn concat_file_text(inputs : Array[MovieInput]) -> String raise FfmpegError {
  if inputs.length() == 0 {
    raise EmptyInput
  }
  inputs.map(input => concat_file_line(input.path)).join("")
}

///|
fn concat_file_line(path : String) -> String raise FfmpegError {
  if path.length() == 0 {
    raise InvalidConcatPath(path)
  }
  "file '\{escape_concat_path(path)}'\n"
}

///|
fn escape_concat_path(path : String) -> String {
  path.replace_all(old="\\", new="\\\\").replace_all(old="'", new="'\\''")
}
