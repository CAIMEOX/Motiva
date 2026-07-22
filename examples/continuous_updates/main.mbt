///|
using @object {
  into_object,
  type Axes,
  type Circle,
  type Dot,
  type Line,
  type Object,
  type Rgba,
  type ShapeStyle,
  type Vec3,
}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig, type Updater}

///|
fn stroke(color : Rgba, width : Double) -> ShapeStyle {
  ShapeStyle::new(stroke=color, stroke_width=width)
}

///|
fn filled(color : Rgba, opacity : Double) -> ShapeStyle {
  ShapeStyle::new(
    fill=color,
    fill_opacity=opacity,
    stroke=Rgba::white(),
    stroke_width=1.8,
  )
}

///|
fn animated_curve(axes : Axes, phase : Double, amplitude : Double) -> Object {
  into_object(
    axes.plot(
      x => amplitude * @math.sin(x + phase),
      x_min=-@math.PI,
      x_max=@math.PI,
      step=0.04,
      style=stroke(Rgba::cyan(), 4.5),
    ),
  ).with_z_index(1.0)
}

///|
fn curve_point(axes : Axes, phase : Double, amplitude : Double) -> Vec3 {
  let x = -@math.PI + phase
  axes.coords_to_point(x, amplitude * @math.sin(x + phase))
}

///|
fn tangent(axes : Axes, phase : Double, amplitude : Double) -> Object {
  let x = -@math.PI + phase
  let y = amplitude * @math.sin(x + phase)
  let slope = amplitude * @math.cos(x + phase)
  let dx = 0.52
  into_object(
    Line::new(
      start=axes.coords_to_point(x - dx, y - slope * dx),
      end=axes.coords_to_point(x + dx, y + slope * dx),
      style=stroke(Rgba::yellow(), 4.0),
    ),
  ).with_z_index(3.0)
}

///|
fn satellites(center : Vec3, phase : Double) -> Object {
  let count = if phase < @math.PI { 3 } else { 6 }
  let children : Array[Object] = []
  for index in 0..<count {
    let angle = phase * 1.8 +
      2.0 * @math.PI * index.to_double() / count.to_double()
    let point = center.add(
      Vec3::new(x=0.34 * @math.cos(angle), y=0.34 * @math.sin(angle)),
    )
    children.push(
      into_object(
        Dot::new(point~, radius=0.055, style=filled(Rgba::magenta(), 0.92)),
      ).with_z_index(4.0),
    )
  }
  Object::group(children)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "continuous_updates_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/continuous_updates_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60.0),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=11.5,
      background=Rgba::rgb(r=0.025, g=0.035, b=0.055),
    ),
  )
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60.0,
    movie_path~,
  )
  writer.attach(scene)

  let axes = Axes::new(
    x_min=-@math.PI,
    x_max=@math.PI,
    x_step=@math.PI / 2.0,
    y_min=-1.7,
    y_max=1.7,
    y_step=0.5,
    x_length=8.2,
    y_length=4.5,
    tips=false,
    tick_size=0.07,
    style=stroke(Rgba::rgb(r=0.48, g=0.55, b=0.64), 1.6),
  )
  let axes_id = scene.object(axes)
  let phase = scene.value_tracker(0.0)
  let amplitude = scene.value_tracker(0.72)
  let elapsed = scene.value_tracker(0.0)

  let elapsed_updater = scene.add_updater(
    Updater::value(elapsed, (value, context) => value + context.dt()),
  )
  let camera_updater = scene.add_updater(
    Updater::camera((camera, context) => {
      let pulse = @math.sin(context.value(elapsed) * 1.7)
      camera.with_view(zoom=1.0 + 0.025 * pulse)
    }),
  )

  ignore(
    scene.always_redraw(context => {
      animated_curve(axes, context.value(phase), context.value(amplitude))
    }),
  )
  let moving_dot = scene.always_redraw(context => {
    into_object(
      Dot::new(
        point=curve_point(axes, context.value(phase), context.value(amplitude)),
        radius=0.115,
        style=filled(Rgba::red(), 1.0),
      ),
    ).with_z_index(5.0)
  })
  ignore(
    scene.always_redraw(context => {
      tangent(axes, context.value(phase), context.value(amplitude))
    }),
  )
  ignore(
    scene.always_redraw(context => {
      let center = context.object(moving_dot).center()
      satellites(center, context.value(phase))
    }),
  )
  ignore(
    scene.always_redraw(context => {
      let radius = 0.22 + 0.07 * (1.0 + @math.sin(context.value(elapsed) * 3.0))
      into_object(Circle::new(radius~, style=filled(Rgba::green(), 0.75)))
      .move_to(Vec3::new(x=4.55, y=2.45))
      .with_z_index(2.0)
    }),
  )

  scene.play([Animation::create(axes_id, run_time=0.8)])
  scene.play([
    phase.animate_to(2.0 * @math.PI, run_time=3.4, rate_func=@scene.Smooth),
    amplitude.animate_to(1.32, run_time=3.4, rate_func=@scene.Smooth),
  ])
  scene.play([
    phase.animate_to(0.0, run_time=2.3, rate_func=@scene.Smooth),
    amplitude.animate_to(0.82, run_time=2.3, rate_func=@scene.Smooth),
  ])
  assert_true(scene.remove_updater(camera_updater))
  assert_true(scene.remove_updater(elapsed_updater))
  scene.play([Animation::wait(0.4)])

  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
