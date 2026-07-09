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
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn style(color : Rgba) -> ShapeStyle {
  ShapeStyle::new(
    fill=color,
    fill_opacity=0.72,
    stroke=Rgba::white(),
    stroke_width=4.0,
  )
}

///|
fn place(object : Object, x : Double, y : Double) -> Object {
  object.with_transform(Transform::translate(Vec3::new(x~, y~)))
}

///|
fn square_at(x : Double, y : Double, color : Rgba) -> Object {
  place(into_object(Square::new(side_length=0.72, style=style(color))), x, y)
}

///|
fn circle_at(x : Double, y : Double, color : Rgba) -> Object {
  place(into_object(Circle::new(radius=0.46, style=style(color))), x, y)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "animation_group_720p60"
  let movie_path = "output/animation_group_720p60.mp4"
  let scene = Scene::new(config=SceneConfig::new(frame_rate=60))
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(
      camera=Camera::new(
        pixel_width=1280,
        pixel_height=720,
        frame_width=7.5,
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
  let a = scene.object(square_at(-2.2, 1.1, Rgba::rgb(r=0.95, g=0.22, b=0.18)))
  let b = scene.object(square_at(2.2, 1.1, Rgba::rgb(r=0.98, g=0.68, b=0.16)))
  let c = scene.object(square_at(-2.2, -1.1, Rgba::rgb(r=0.16, g=0.67, b=0.35)))
  let d = scene.object(square_at(2.2, -1.1, Rgba::rgb(r=0.14, g=0.55, b=0.92)))
  scene.play([
    Animation::lagged_start(
      [
        Animation::create(a, run_time=1.0, rate_func=@scene.Smooth),
        Animation::create(b, run_time=1.0, rate_func=@scene.Smooth),
        Animation::create(c, run_time=1.0, rate_func=@scene.Smooth),
        Animation::create(d, run_time=1.0, rate_func=@scene.Smooth),
      ],
      run_time=2.4,
      lag_ratio=0.25,
      rate_func=@scene.Smooth,
    ),
  ])
  scene.play([
    Animation::group(
      [
        a
        .animate(run_time=1.8, rate_func=@scene.RushFrom)
        .shift(Vec3::new(x=0.6, y=-0.65))
        .scale(sx=0.85, sy=0.85)
        .to_animation(),
        b
        .animate(run_time=1.6, rate_func=@scene.Smooth)
        .scale(sx=1.25, sy=1.25)
        .to_animation(),
        Animation::transform(
          c,
          circle_at(-2.2, -1.1, Rgba::rgb(r=0.23, g=0.82, b=0.52)),
          run_time=1.9,
          rate_func=@scene.RushInto,
        ),
        Animation::rotate(
          d,
          angle=2.0 * @math.PI,
          run_time=2.0,
          rate_func=@scene.Linear,
        ),
      ],
      run_time=3.0,
      lag_ratio=0.18,
      rate_func=@scene.Smooth,
    ),
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
