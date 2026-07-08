///|
test "encode image sequence builds manim mp4 argv" {
  let ffmpeg = Ffmpeg::new()
  let argv = ffmpeg.encode_image_sequence_argv(
    ImageSequenceInput::png(
      dir="output",
      prefix="circle_to_square",
      padding=4,
      frame_rate=FrameRate::fps(12.0),
    ),
    MovieOutput::mp4("output/circle_to_square.mp4"),
    EncodeProfile::manim_mp4(),
  )
  assert_eq(argv, [
    "-y", "-loglevel", "error", "-framerate", "12", "-i", "output/circle_to_square_%04d.png",
    "-c:v", "libx264", "-crf", "23", "-pix_fmt", "yuv420p", "-an", "output/circle_to_square.mp4",
  ])
}

///|
test "concat movie argv uses concat demuxer and stream copy" {
  let ffmpeg = Ffmpeg::new(log_level=Warning, overwrite=false)
  let argv = ffmpeg.concat_movies_argv(
    "output/partial_movie_file_list.txt",
    MovieOutput::mp4("output/final.mp4"),
    StreamCopy,
  )
  assert_eq(argv, [
    "-n", "-loglevel", "warning", "-f", "concat", "-safe", "0", "-i", "output/partial_movie_file_list.txt",
    "-c", "copy", "output/final.mp4",
  ])
}

///|
test "concat file text escapes quotes and backslashes" {
  let text = concat_file_text([
    MovieInput::new("partial/a.mp4"),
    MovieInput::new("partial/it's\\odd.mp4"),
  ])
  inspect(
    text,
    content=(
      #|file 'partial/a.mp4'
      #|file 'partial/it'\''s\\odd.mp4'
      #|
    ),
  )
}

///|
test "invalid frame rates are rejected while building argv" {
  let ffmpeg = Ffmpeg::new()
  let result = try
    ffmpeg.encode_image_sequence_argv(
      ImageSequenceInput::png(
        dir="output",
        prefix="frame",
        frame_rate=FrameRate::fps(0.0),
      ),
      MovieOutput::mp4("out.mp4"),
      EncodeProfile::manim_mp4(),
    )
  catch {
    error => Err(error)
  } noraise {
    _ => Ok(())
  }
  guard result is Err(InvalidFrameRate(0.0)) else {
    fail("zero frame rate should be rejected")
  }
}

///|
test "audio mux argv keeps video stream and can shorten to video length" {
  let ffmpeg = Ffmpeg::new()
  let argv = ffmpeg.mux_audio_argv(
    MovieInput::new("video.mp4"),
    AudioInput::new("audio.aac"),
    MovieOutput::mp4("with_audio.mp4"),
    CopyAudio,
    true,
  )
  assert_eq(argv, [
    "-y", "-loglevel", "error", "-i", "video.mp4", "-i", "audio.aac", "-c:v", "copy",
    "-c:a", "copy", "-shortest", "with_audio.mp4",
  ])
}
