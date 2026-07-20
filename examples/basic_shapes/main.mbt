///|
using @object {
  into_object,
  type Dot,
  type Line,
  type Object,
  type Polygon,
  type Rectangle,
  type Rgba,
  type ShapeStyle,
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
fn vmobject_style() -> ShapeStyle {
  ShapeStyle::new(fill_opacity=0.0, stroke=Rgba::white(), stroke_width=4.0)
}

///|
fn dot_style() -> ShapeStyle {
  ShapeStyle::new(
    fill=Rgba::white(),
    fill_opacity=1.0,
    stroke=Rgba::white(),
    stroke_width=0.0,
  )
}

///|
fn place(object : Object, x : Double, y : Double) -> Object {
  object.with_transform(Transform::translate(Vec3::new(x~, y~)))
}

///|
fn line_object() -> Object {
  let style = vmobject_style()
  place(
    into_object(
      Line::new(
        start=Vec3::new(x=-0.9, y=-0.45),
        end=Vec3::new(x=0.9, y=0.45),
        style~,
      ),
    ),
    -2.4,
    1.05,
  )
}

///|
fn polygon_object() -> Object {
  let style = vmobject_style()
  place(
    into_object(
      Polygon::new(
        [
          Vec3::new(x=-0.85, y=-0.55),
          Vec3::new(x=0.65, y=-0.55),
          Vec3::new(x=0.95, y=0.2),
          Vec3::new(x=-0.25, y=0.75),
        ],
        style~,
      ),
    ),
    2.35,
    1.0,
  )
}

///|
fn rectangle_object() -> Object {
  let style = vmobject_style()
  place(
    into_object(Rectangle::new(width=1.9, height=1.1, style~)),
    -2.35,
    -1.15,
  )
}

///|
fn dot_object() -> Object {
  let style = dot_style()
  place(into_object(Dot::new(style~)), 2.35, -1.15)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "basic_shapes_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/basic_shapes_720p60.mp4"
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
  let line = scene.object(line_object())
  let polygon = scene.object(polygon_object())
  let rectangle = scene.object(rectangle_object())
  let dot = scene.object(dot_object())
  scene.play([
    Animation::lagged_start(
      [
        Animation::create(line, run_time=1.0),
        Animation::create(polygon, run_time=1.0),
        Animation::create(rectangle, run_time=1.0),
        Animation::create(dot, run_time=1.0),
      ],
      run_time=2.4,
      lag_ratio=0.18,
      rate_func=@scene.Smooth,
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
