///|
using @object {type Rgba, type ShapeStyle, type Square}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn rotating_square() -> Square {
  let fill = Rgba::rgb(r=0.95, g=0.45, b=0.12)
  let stroke = Rgba::white()
  let style = ShapeStyle::new(
    fill~,
    fill_opacity=0.85,
    stroke~,
    stroke_width=4.0,
  )
  Square::new(side_length=1.8, style~)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "rotating_square_720p60"
  let movie_path = "output/rotating_square_720p60.mp4"
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
  let square = scene.object(rotating_square())
  scene.play([Animation::create(square, run_time=0.75)])
  scene.play([Animation::rotate(square, angle=2.0 * @math.PI, run_time=2.0)])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to output/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
