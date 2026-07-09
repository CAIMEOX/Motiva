///|
using @object {
  into_object,
  type Circle,
  type Object,
  type Rgba,
  type ShapeStyle,
  type Transform,
  type Vec3,
}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn circle_at(x : Double) -> Object {
  let fill = Rgba::rgb(r=0.16, g=0.42, b=0.95)
  let stroke = Rgba::white()
  let style = ShapeStyle::new(
    fill~,
    fill_opacity=0.85,
    stroke~,
    stroke_width=4.0,
  )
  into_object(Circle::new(radius=0.9, style~)).with_transform(
    Transform::translate(Vec3::new(x~, y=0.0)),
  )
}

///|
async fn animate() -> Unit {
  let frame_prefix = "create_vs_draw_border_then_fill_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/create_vs_draw_border_then_fill_720p60.mp4"
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
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60,
    movie_path~,
  )
  writer.attach(scene)
  let left = scene.object(circle_at(-1.5))
  let right = scene.object(circle_at(1.5))
  scene.play([
    Animation::create(left, run_time=2.0),
    Animation::draw_border_then_fill(right, run_time=2.0),
  ])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
