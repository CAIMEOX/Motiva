///|
using @object {
  into_object,
  type Circle,
  type Object,
  type Rgba,
  type ShapeStyle,
  type Square,
  type Transform,
  type Vec3,
}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn style(color : Rgba) -> ShapeStyle {
  ShapeStyle::new(
    fill=color,
    fill_opacity=0.75,
    stroke=Rgba::white(),
    stroke_opacity=1.0,
    stroke_width=5.0,
  )
}

///|
fn place(object : Object, x : Double, y : Double) -> Object {
  object.with_transform(Transform::translate(Vec3::new(x~, y~)))
}

///|
fn circle_at(x : Double, y : Double, color : Rgba) -> Object {
  place(into_object(Circle::new(radius=0.58, style=style(color))), x, y)
}

///|
fn square_at(x : Double, y : Double, color : Rgba) -> Object {
  place(into_object(Square::new(side_length=1.04, style=style(color))), x, y)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "fade_in_out_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/fade_in_out_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=7.0,
      background=Rgba::black(),
    ),
  )
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60,
    movie_path~,
  )
  writer.attach(scene)
  let circle = scene.object(
    circle_at(-1.7, 0.0, Rgba::rgb(r=0.24, g=0.70, b=0.95)),
  )
  let square = scene.object(
    square_at(1.7, 0.0, Rgba::rgb(r=0.98, g=0.55, b=0.20)),
  )
  scene.play([
    Animation::fade_in(
      circle,
      shift=Vec3::new(x=0.0, y=-1.1),
      scale=0.45,
      run_time=1.4,
      rate_func=@scene.Smooth,
    ),
    Animation::fade_in(
      square,
      target_position=Vec3::new(x=0.0, y=1.65),
      scale=1.35,
      run_time=1.4,
      rate_func=@scene.Smooth,
    ),
  ])
  scene.play([Animation::wait(0.35)])
  scene.play([
    Animation::fade_out(
      circle,
      shift=Vec3::new(x=-1.1, y=0.8),
      scale=1.45,
      run_time=1.25,
      rate_func=@scene.RushInto,
    ),
    Animation::fade_out(
      square,
      target_position=Vec3::new(x=0.0, y=-1.65),
      scale=0.45,
      run_time=1.25,
      rate_func=@scene.RushInto,
    ),
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
