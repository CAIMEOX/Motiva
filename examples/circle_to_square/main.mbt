///|
using @object {type Circle, type Rgba, type Square}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
async fn animate() -> Unit {
  let frame_prefix = "create_circle_to_square_720p60"
  let movie_path = "output/create_circle_to_square_720p60.mp4"
  let scene = Scene::new(config=SceneConfig::new(frame_rate=60))
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(
      camera=Camera::new(
        pixel_width=1280,
        pixel_height=720,
        frame_width=6.0,
        background=Rgba::black(),
      ),
    ),
    output_dir="output",
    frame_prefix~,
    frame_padding=4,
    frame_rate=60,
    movie_path~,
  )
  writer.attach(scene)
  let circle = scene.object(Circle::new(radius=1.2))
  scene.play([Animation::create(circle, run_time=1.0)])
  scene.play([
    Animation::transform(circle, Square::new(side_length=2.4), run_time=1.0),
  ])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to output/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
