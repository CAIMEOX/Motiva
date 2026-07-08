///|
pub(all) suberror FfmpegError {
  EmptyInput
  InvalidFrameRate(Double)
  InvalidFramePadding(Int)
  InvalidConcatPath(String)
  Host(Error)
  CommandFailed(exit_code~ : Int, stdout~ : String, stderr~ : String)
}

///|
pub(all) enum LogLevel {
  Quiet
  Panic
  Fatal
  Error
  Warning
  Info
  Verbose
  Debug
  Trace
} derive(Eq)

///|
pub(all) struct Ffmpeg {
  binary : String
  ffprobe : String
  log_level : LogLevel
  overwrite : Bool
}

///|
pub fn Ffmpeg::new(
  binary? : String = "ffmpeg",
  ffprobe? : String = "ffprobe",
  log_level? : LogLevel = Error,
  overwrite? : Bool = true,
) -> Ffmpeg {
  { binary, ffprobe, log_level, overwrite }
}

///|
pub fn Ffmpeg::default() -> Ffmpeg {
  Ffmpeg::new()
}

///|
pub(all) struct FrameRate {
  value : Double
}

///|
pub fn FrameRate::fps(value : Double) -> FrameRate {
  { value, }
}

///|
pub fn FrameRate::value(self : FrameRate) -> Double {
  self.value
}

///|
pub(all) enum ImageFormat {
  Png
}

///|
pub(all) struct ImageSequenceInput {
  dir : String
  prefix : String
  padding : Int
  frame_rate : FrameRate
  format : ImageFormat
}

///|
pub fn ImageSequenceInput::png(
  dir~ : String,
  prefix~ : String,
  padding? : Int = 4,
  frame_rate~ : FrameRate,
) -> ImageSequenceInput {
  { dir, prefix, padding, frame_rate, format: Png }
}

///|
pub(all) enum MovieFormat {
  Mp4
  Webm
  Mov
}

///|
pub(all) struct MovieInput {
  path : String
}

///|
pub fn MovieInput::new(path : String) -> MovieInput {
  { path, }
}

///|
pub(all) struct MovieOutput {
  path : String
  format : MovieFormat
}

///|
pub fn MovieOutput::mp4(path : String) -> MovieOutput {
  { path, format: Mp4 }
}

///|
pub fn MovieOutput::webm(path : String) -> MovieOutput {
  { path, format: Webm }
}

///|
pub fn MovieOutput::mov(path : String) -> MovieOutput {
  { path, format: Mov }
}

///|
pub(all) struct AudioInput {
  path : String
}

///|
pub fn AudioInput::new(path : String) -> AudioInput {
  { path, }
}

///|
pub(all) struct AudioOutput {
  path : String
}

///|
pub fn AudioOutput::new(path : String) -> AudioOutput {
  { path, }
}

///|
pub(all) struct GifOutput {
  path : String
}

///|
pub fn GifOutput::new(path : String) -> GifOutput {
  { path, }
}

///|
pub(all) enum VideoCodec {
  CopyVideo
  Libx264(Int)
  LibvpxVp9
  Qtrle
  Gif
}

///|
pub(all) enum AudioCodec {
  CopyAudio
  Aac
  LibVorbis
  PcmS16le
}

///|
pub(all) enum PixelFormat {
  Yuv420p
  Yuva420p
  Argb
  Rgb8
  Pal8
}

///|
pub(all) struct EncodeProfile {
  video_codec : VideoCodec
  pixel_format : PixelFormat
  no_audio : Bool
}

///|
pub fn EncodeProfile::manim_mp4() -> EncodeProfile {
  { video_codec: Libx264(23), pixel_format: Yuv420p, no_audio: true }
}

///|
pub fn EncodeProfile::manim_webm(transparent? : Bool = false) -> EncodeProfile {
  {
    video_codec: LibvpxVp9,
    pixel_format: if transparent {
      Yuva420p
    } else {
      Yuv420p
    },
    no_audio: true,
  }
}

///|
pub fn EncodeProfile::manim_mov_transparent() -> EncodeProfile {
  { video_codec: Qtrle, pixel_format: Argb, no_audio: true }
}

///|
pub(all) enum ConcatMode {
  StreamCopy
  Reencode(EncodeProfile)
}

///|
pub(all) struct GifOptions {
  frame_rate : FrameRate?
  transparent : Bool
}

///|
pub fn GifOptions::new(
  frame_rate? : FrameRate? = None,
  transparent? : Bool = false,
) -> GifOptions {
  { frame_rate, transparent }
}

///|
pub fn GifOptions::default() -> GifOptions {
  GifOptions::new()
}
