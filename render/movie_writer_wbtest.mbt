///|
test "movie writer wraps image sequence settings and mp4 output" {
  let writer = MovieWriter::mp4(
    output_dir="output",
    frame_prefix="circle_to_square",
    frame_padding=4,
    frame_rate=60.0,
    movie_path="output/circle_to_square.mp4",
  )
  assert_eq(writer.frame_count(), 0)
  assert_eq(writer.image_sequence.output_dir, "output")
  assert_eq(writer.image_sequence.frame_prefix, "circle_to_square")
  assert_eq(writer.image_sequence.frame_padding, 4)
  assert_true(writer.frame_rate.value().is_close(60.0))
  assert_eq(writer.movie_output.path, "output/circle_to_square.mp4")
  assert_true(writer.movie_output.format is Mp4)
}
