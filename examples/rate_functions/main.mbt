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
using @scene {type Animation, type RateFunc, type Scene, type SceneConfig}

///|
fn circle_at(x : Double, color : Rgba) -> Object {
  let style = ShapeStyle::new(
    fill=color,
    fill_opacity=0.25,
    stroke=color,
    stroke_width=5.0,
  )
  into_object(Circle::new(radius=0.38, style~)).with_transform(
    Transform::translate(Vec3::new(x~, y=0.0)),
  )
}

///|
fn rate_animation(id : @scene.ObjectId, rate_func : RateFunc) -> Animation {
  Animation::create(id, run_time=3.0, rate_func~)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "rate_functions_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/rate_functions_720p60.mp4"
  let scene = Scene::new(config=SceneConfig::new(frame_rate=60))
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(
      camera=Camera::new(
        pixel_width=1280,
        pixel_height=720,
        frame_width=8.0,
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
  let linear = scene.object(circle_at(-3.0, Rgba::rgb(r=0.96, g=0.26, b=0.21)))
  let smooth = scene.object(circle_at(-1.8, Rgba::rgb(r=0.98, g=0.68, b=0.16)))
  let rush_into = scene.object(
    circle_at(-0.6, Rgba::rgb(r=0.20, g=0.73, b=0.35)),
  )
  let rush_from = scene.object(
    circle_at(0.6, Rgba::rgb(r=0.10, g=0.56, b=0.86)),
  )
  let there_and_back = scene.object(
    circle_at(1.8, Rgba::rgb(r=0.61, g=0.35, b=0.92)),
  )
  let custom = scene.object(circle_at(3.0, Rgba::rgb(r=0.95, g=0.44, b=0.70)))
  scene.play([
    rate_animation(linear, @scene.Linear),
    rate_animation(smooth, @scene.Smooth),
    rate_animation(rush_into, @scene.RushInto),
    rate_animation(rush_from, @scene.RushFrom),
    rate_animation(there_and_back, @scene.ThereAndBack),
    rate_animation(custom, @scene.Custom(t => t * t * t)),
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
