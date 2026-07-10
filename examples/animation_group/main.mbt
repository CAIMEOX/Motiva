///|
using @object {
  into_object,
  type Circle,
  type Object,
  type Rgba,
  type ShapeStyle,
  type Square,
  type Vec3,
}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
suberror AnimationGroupExampleError {
  UnexpectedFamilyStructure
}

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
fn square(color : Rgba) -> Object {
  into_object(Square::new(side_length=0.72, style=style(color)))
}

///|
fn circle(color : Rgba) -> Object {
  into_object(Circle::new(radius=0.46, style=style(color)))
}

///|
async fn animate() -> Unit {
  let frame_prefix = "animation_group_720p60"
  let frame_dir = "output/frames"
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
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60,
    movie_path~,
  )
  writer.attach(scene)
  let top_row = Object::group([
    square(Rgba::rgb(r=0.95, g=0.22, b=0.18)),
    square(Rgba::rgb(r=0.98, g=0.68, b=0.16)),
  ]).arrange(direction=Vec3::new(x=1.0, y=0.0), buff=1.35)
  let bottom_row = Object::group([
    square(Rgba::rgb(r=0.16, g=0.67, b=0.35)),
    square(Rgba::rgb(r=0.14, g=0.55, b=0.92)),
  ]).arrange(direction=Vec3::new(x=1.0, y=0.0), buff=1.35)
  let family = scene.object(
    Object::group([top_row, bottom_row]).arrange(
      direction=Vec3::new(x=0.0, y=-1.0),
      buff=0.85,
    ),
  )
  guard scene.children(family) is [top_row_id, bottom_row_id] else {
    raise UnexpectedFamilyStructure
  }
  guard (scene.children(top_row_id), scene.children(bottom_row_id))
    is ([a, b], [c, d]) else {
    raise UnexpectedFamilyStructure
  }
  scene.play([
    Animation::lagged_start(
      [
        Animation::create(a, run_time=1.0, rate_func=Smooth),
        Animation::create(b, run_time=1.0, rate_func=Smooth),
        Animation::create(c, run_time=1.0, rate_func=Smooth),
        Animation::create(d, run_time=1.0, rate_func=Smooth),
      ],
      run_time=2.4,
      lag_ratio=0.25,
      rate_func=Smooth,
    ),
  ])
  scene.play([
    Animation::group(
      [
        a
        .animate(run_time=1.8, rate_func=RushFrom)
        .shift(Vec3::new(x=0.6, y=-0.65))
        .scale(sx=0.85, sy=0.85)
        .to_animation(),
        b
        .animate(run_time=1.6, rate_func=Smooth)
        .scale(sx=1.25, sy=1.25)
        .to_animation(),
        Animation::transform(
          c,
          scene
          .get(c)
          .map_or(circle(Rgba::rgb(r=0.23, g=0.82, b=0.52)), current => {
            circle(Rgba::rgb(r=0.23, g=0.82, b=0.52)).move_to(current.center())
          }),
          run_time=1.9,
          rate_func=RushInto,
        ),
        Animation::rotate(
          d,
          angle=2.0 * @math.PI,
          run_time=2.0,
          rate_func=Linear,
        ),
      ],
      run_time=3.0,
      lag_ratio=0.18,
      rate_func=Smooth,
    ),
  ])
  scene.play([
    family
    .animate(run_time=1.4, rate_func=ThereAndBack)
    .scale(sx=1.12, sy=1.12)
    .rotate(angle=@math.PI / 12.0),
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
