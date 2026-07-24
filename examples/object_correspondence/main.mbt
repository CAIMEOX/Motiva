///|
using @object {
  into_object,
  type Circle,
  type CorrespondencePart,
  type Dot,
  type FamilyPath,
  type Line,
  type MotionPath,
  type Object,
  type ObjectCorrespondence,
  type Polygon,
  type Rgba,
  type ShapeStyle,
  type Square,
  type Vec3,
}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn shape_style(color : Rgba) -> ShapeStyle {
  ShapeStyle::new(
    fill=color,
    fill_opacity=0.78,
    stroke=Rgba::white(),
    stroke_width=3.0,
  )
}

///|
fn triangle(style : ShapeStyle) -> Object {
  into_object(
    Polygon::new(
      [
        Vec3::new(x=0.0, y=0.7),
        Vec3::new(x=-0.65, y=-0.45),
        Vec3::new(x=0.65, y=-0.45),
      ],
      style~,
    ),
  )
}

///|
fn hexagon(style : ShapeStyle) -> Object {
  into_object(
    Polygon::new(
      [
        Vec3::new(x=0.75, y=0.0),
        Vec3::new(x=0.375, y=0.65),
        Vec3::new(x=-0.375, y=0.65),
        Vec3::new(x=-0.75, y=0.0),
        Vec3::new(x=-0.375, y=-0.65),
        Vec3::new(x=0.375, y=-0.65),
      ],
      style~,
    ),
  )
}

///|
fn child_path(index : Int) -> FamilyPath {
  FamilyPath::root().child(index)
}

///|
fn source_object() -> Object {
  let blue = shape_style(Rgba::manim_blue())
  let yellow = shape_style(Rgba::yellow())
  let green = shape_style(Rgba::rgb(r=0.18, g=0.78, b=0.44))
  let red = ShapeStyle::stroked(
    color=Rgba::rgb(r=0.95, g=0.25, b=0.22),
    stroke_width=5.0,
  )
  Object::group([
    into_object(Square::new(side_length=1.35, style=blue)).move_to(
      Vec3::new(x=-2.45, y=0.1),
    ),
    triangle(yellow).move_to(Vec3::new(x=-0.25, y=0.85)),
    into_object(Circle::new(radius=0.52, style=green)).move_to(
      Vec3::new(x=-0.25, y=-0.85),
    ),
    into_object(
      Line::new(
        start=Vec3::new(x=-0.7, y=-0.55),
        end=Vec3::new(x=0.7, y=0.55),
        style=red,
      ),
    ).move_to(Vec3::new(x=2.35, y=0.0)),
  ])
}

///|
fn target_object() -> Object {
  let blue = shape_style(Rgba::manim_blue())
  let magenta = shape_style(Rgba::rgb(r=0.86, g=0.28, b=0.68))
  let spark = ShapeStyle::filled(color=Rgba::yellow())
  Object::group([
    into_object(Circle::new(radius=0.42, style=blue)).move_to(
      Vec3::new(x=-2.7, y=-0.7),
    ),
    into_object(Circle::new(radius=0.42, style=blue)).move_to(
      Vec3::new(x=-1.85, y=0.75),
    ),
    into_object(Circle::new(radius=0.42, style=blue)).move_to(
      Vec3::new(x=-1.0, y=-0.7),
    ),
    hexagon(magenta).move_to(Vec3::new(x=0.9, y=0.0)),
    into_object(
      Dot::new(point=Vec3::new(x=2.55, y=0.75), radius=0.2, style=spark),
    ),
  ])
}

///|
fn correspondence() -> ObjectCorrespondence {
  ObjectCorrespondence::by_key(
    [
      CorrespondencePart::new(child_path(0), "seed"),
      CorrespondencePart::new(child_path(1), "merge"),
      CorrespondencePart::new(child_path(2), "merge"),
      CorrespondencePart::new(child_path(3), "old"),
    ],
    [
      CorrespondencePart::new(child_path(0), "seed"),
      CorrespondencePart::new(child_path(1), "seed"),
      CorrespondencePart::new(child_path(2), "seed"),
      CorrespondencePart::new(child_path(3), "merge"),
      CorrespondencePart::new(child_path(4), "spark"),
    ],
  )
}

///|
async fn animate() -> Unit {
  let frame_prefix = "object_correspondence_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/object_correspondence_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=8.0,
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
  let source = scene.object(source_object())
  let target = scene.object(target_object())
  scene.play([
    Animation::create(source, run_time=1.8, rate_func=Smooth, lag_ratio=0.18),
  ])
  scene.play([
    scene.transform_matching(
      source,
      target,
      correspondence(),
      run_time=3.2,
      rate_func=Smooth,
      path=MotionPath::arc(angle=@math.PI / 2.5),
    ),
  ])
  let final_style = shape_style(Rgba::rgb(r=0.95, g=0.32, b=0.28))
  let final_object = Object::group([
    into_object(Circle::new(radius=1.15, style=final_style)),
  ])
  scene.play([
    Animation::transform(
      target,
      final_object,
      run_time=2.6,
      rate_func=Smooth,
      lag_ratio=0.16,
      path=MotionPath::arc(angle=-@math.PI / 2.0),
    ),
  ])
  scene.play([Animation::wait(0.5)])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
