///|
using @object {
  into_object,
  type Circle,
  type Dot,
  type Object,
  type Polygon,
  type Rectangle,
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
fn base_style(color : Rgba) -> ShapeStyle {
  ShapeStyle::new(
    fill=color,
    fill_opacity=0.24,
    stroke=color,
    stroke_opacity=1.0,
    stroke_width=4.0,
  )
}

///|
fn dot_style(color : Rgba) -> ShapeStyle {
  ShapeStyle::new(fill=color, fill_opacity=1.0, stroke=color, stroke_width=0.0)
}

///|
fn place(object : Object, x : Double, y : Double) -> Object {
  object.with_transform(Transform::translate(Vec3::new(x~, y~)))
}

///|
fn triangle(style : ShapeStyle) -> Object {
  into_object(
    Polygon::new(
      [
        Vec3::new(x=0.0, y=0.72),
        Vec3::new(x=-0.76, y=-0.56),
        Vec3::new(x=0.76, y=-0.56),
      ],
      style~,
    ),
  )
}

///|
async fn animate() -> Unit {
  let frame_prefix = "style_effects_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/style_effects_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=7.4,
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
  let square = scene.object(
    place(
      into_object(
        Square::new(
          side_length=0.9,
          style=base_style(Rgba::rgb(r=0.20, g=0.62, b=0.94)),
        ),
      ),
      -2.55,
      0.95,
    ),
  )
  let circle = scene.object(
    place(
      into_object(
        Circle::new(
          radius=0.5,
          style=base_style(Rgba::rgb(r=0.93, g=0.28, b=0.34)),
        ),
      ),
      -0.85,
      0.95,
    ),
  )
  let rectangle = scene.object(
    place(
      into_object(
        Rectangle::new(
          width=1.15,
          height=0.72,
          style=base_style(Rgba::rgb(r=0.96, g=0.70, b=0.20)),
        ),
      ),
      0.85,
      0.95,
    ),
  )
  let polygon = scene.object(
    place(triangle(base_style(Rgba::rgb(r=0.52, g=0.35, b=0.88))), 2.55, 0.95),
  )
  let dot = scene.object(
    place(
      into_object(
        Dot::new(
          radius=0.16,
          style=dot_style(Rgba::rgb(r=0.26, g=0.78, b=0.45)),
        ),
      ),
      0.0,
      -1.05,
    ),
  )
  scene.play([
    Animation::lagged_start(
      [
        Animation::create(square, run_time=0.8),
        Animation::create(circle, run_time=0.8),
        Animation::create(rectangle, run_time=0.8),
        Animation::create(polygon, run_time=0.8),
        Animation::fade_in(
          dot,
          shift=Vec3::new(x=0.0, y=-0.55),
          scale=0.4,
          run_time=0.8,
        ),
      ],
      run_time=1.8,
      lag_ratio=0.18,
      rate_func=@scene.Smooth,
    ),
  ])
  scene.play([
    square
    .animate(run_time=1.8, rate_func=@scene.Smooth)
    .set_fill(color=Rgba::rgb(r=0.08, g=0.86, b=0.58), opacity=0.88)
    .set_stroke(color=Rgba::white(), width=8.0, opacity=1.0)
    .move_to(Vec3::new(x=-2.25, y=-0.82)),
    circle
    .animate(run_time=1.8, rate_func=@scene.RushFrom)
    .set_color(Rgba::rgb(r=0.96, g=0.34, b=0.74))
    .set_opacity(0.42)
    .scale(sx=1.4, sy=1.4),
    rectangle
    .animate(run_time=1.8, rate_func=@scene.Smooth)
    .set_fill(color=Rgba::rgb(r=0.15, g=0.48, b=0.92), opacity=0.68)
    .set_stroke(color=Rgba::rgb(r=1.0, g=0.86, b=0.25), width=2.0, opacity=0.85)
    .rotate(angle=@math.PI / 3.0),
    polygon
    .animate(run_time=1.8, rate_func=@scene.RushInto)
    .set_fill(color=Rgba::rgb(r=0.95, g=0.28, b=0.24), opacity=0.9)
    .set_stroke(color=Rgba::black(), width=7.0, opacity=1.0)
    .move_to(Vec3::new(x=2.25, y=-0.82)),
    dot
    .animate(run_time=1.8, rate_func=@scene.Smooth)
    .set_color(Rgba::white())
    .set_opacity(0.75)
    .scale(sx=2.6, sy=2.6),
  ])
  scene.play([Animation::wait(0.35)])
  scene.play([
    square
    .animate(run_time=1.35, rate_func=@scene.Smooth)
    .set_opacity(0.24)
    .set_stroke(width=3.0)
    .move_to(Vec3::new(x=-2.55, y=0.95)),
    circle
    .animate(run_time=1.35, rate_func=@scene.Smooth)
    .set_fill(opacity=0.82)
    .set_stroke(color=Rgba::white(), width=5.0)
    .move_to(Vec3::new(x=-0.85, y=0.95)),
    rectangle
    .animate(run_time=1.35, rate_func=@scene.Smooth)
    .set_color(Rgba::rgb(r=0.96, g=0.70, b=0.20))
    .set_fill(opacity=0.24)
    .rotate(angle=0.0 - @math.PI / 3.0),
    polygon
    .animate(run_time=1.35, rate_func=@scene.Smooth)
    .set_color(Rgba::rgb(r=0.52, g=0.35, b=0.88))
    .set_fill(opacity=0.24)
    .set_stroke(width=4.0)
    .move_to(Vec3::new(x=2.55, y=0.95)),
    dot
    .animate(run_time=1.35, rate_func=@scene.Smooth)
    .set_color(Rgba::rgb(r=0.26, g=0.78, b=0.45))
    .set_opacity(1.0)
    .scale(sx=0.38, sy=0.38),
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
