///|
using @object {
  into_object,
  type Circle,
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
fn degrees(value : Double) -> Double {
  value * @math.PI / 180.0
}

///|
fn rgb(r : Double, g : Double, b : Double) -> Rgba {
  Rgba::rgb(r~, g~, b~)
}

///|
fn stroke_style(
  color : Rgba,
  width? : Double = 3.0,
  opacity? : Double = 1.0,
) -> ShapeStyle {
  ShapeStyle::new(stroke=color, stroke_width=width, stroke_opacity=opacity)
}

///|
fn fill_style(
  color : Rgba,
  opacity? : Double = 1.0,
  stroke? : Rgba = Rgba::white(),
  stroke_width? : Double = 2.0,
) -> ShapeStyle {
  ShapeStyle::new(fill=color, fill_opacity=opacity, stroke~, stroke_width~)
}

///|
fn world_line(
  start : Vec3,
  end : Vec3,
  color : Rgba,
  width? : Double = 2.0,
  opacity? : Double = 1.0,
  z_index? : Double = 0.0,
) -> Object {
  into_object(
    Line::new(start~, end~, style=stroke_style(color, width~, opacity~)),
  ).with_z_index(z_index)
}

///|
fn floor_grid() -> Object {
  let lines : Array[Object] = []
  let minor = rgb(0.27, 0.34, 0.39)
  for index in 0..<=8 {
    let coordinate = (index - 4).to_double()
    lines.push(
      world_line(
        Vec3::new(x=coordinate, y=-4.0),
        Vec3::new(x=coordinate, y=4.0),
        minor,
        width=1.2,
        opacity=0.56,
        z_index=-1.0,
      ),
    )
    lines.push(
      world_line(
        Vec3::new(x=-4.0, y=coordinate),
        Vec3::new(x=4.0, y=coordinate),
        minor,
        width=1.2,
        opacity=0.56,
        z_index=-1.0,
      ),
    )
  }
  Object::group(lines)
}

///|
fn coordinate_axes() -> Object {
  let objects : Array[Object] = []
  let red = rgb(0.96, 0.30, 0.28)
  let green = rgb(0.24, 0.82, 0.48)
  let blue = rgb(0.24, 0.58, 0.98)
  objects.push(
    world_line(
      Vec3::new(x=-3.7, y=0.0),
      Vec3::new(x=3.7, y=0.0),
      red,
      width=5.0,
      z_index=1.0,
    ),
  )
  objects.push(
    world_line(
      Vec3::new(x=0.0, y=-3.7),
      Vec3::new(x=0.0, y=3.7),
      green,
      width=5.0,
      z_index=1.0,
    ),
  )
  objects.push(
    world_line(
      Vec3::zero(),
      Vec3::new(x=0.0, y=0.0, z=3.2),
      blue,
      width=5.0,
      z_index=1.0,
    ),
  )
  for index in 1..<=3 {
    let value = index.to_double()
    for sign in [-1.0, 1.0] {
      let coordinate = sign * value
      objects.push(
        world_line(
          Vec3::new(x=coordinate, y=-0.09),
          Vec3::new(x=coordinate, y=0.09),
          red,
          width=2.4,
          z_index=1.0,
        ),
      )
      objects.push(
        world_line(
          Vec3::new(x=-0.09, y=coordinate),
          Vec3::new(x=0.09, y=coordinate),
          green,
          width=2.4,
          z_index=1.0,
        ),
      )
    }
    objects.push(
      world_line(
        Vec3::new(x=-0.09, y=0.0, z=value),
        Vec3::new(x=0.09, y=0.0, z=value),
        blue,
        width=2.4,
        z_index=1.0,
      ),
    )
  }
  Object::group(objects)
}

///|
fn axis_marker(point : Vec3, color : Rgba) -> Object {
  into_object(
    Circle::new(
      radius=0.12,
      style=fill_style(color, stroke=Rgba::white(), stroke_width=1.8),
    ),
  )
  .move_to(point)
  .with_z_index(3.0)
}

///|
fn billboard(
  camera : Camera,
  position : Vec3,
  radius : Double,
  color : Rgba,
  opacity : Double,
  z_index : Double,
) -> Object {
  let world_center = camera.camera_to_world(position)
  into_object(
    Circle::new(
      radius~,
      style=fill_style(color, opacity~, stroke=Rgba::white(), stroke_width=1.4),
    ),
  )
  .with_transform(
    camera.inverse_rotation_transform().then(Transform::translate(world_center)),
  )
  .with_z_index(z_index)
}

///|
fn far_layer(camera : Camera) -> Object {
  let color = rgb(0.20, 0.42, 0.78)
  Object::group([
    billboard(camera, Vec3::new(x=-4.7, y=1.9, z=-5.0), 0.32, color, 0.34, -4.0),
    billboard(
      camera,
      Vec3::new(x=-4.2, y=-1.9, z=-5.0),
      0.22,
      color,
      0.30,
      -4.0,
    ),
    billboard(camera, Vec3::new(x=4.5, y=1.75, z=-5.0), 0.26, color, 0.32, -4.0),
    billboard(
      camera,
      Vec3::new(x=4.8, y=-1.65, z=-5.0),
      0.36,
      color,
      0.28,
      -4.0,
    ),
  ])
}

///|
fn middle_layer(camera : Camera) -> Object {
  let color = rgb(0.18, 0.78, 0.72)
  Object::group([
    billboard(camera, Vec3::new(x=-3.9, y=0.85), 0.24, color, 0.46, -2.0),
    billboard(camera, Vec3::new(x=-2.8, y=-2.1), 0.34, color, 0.40, -2.0),
    billboard(camera, Vec3::new(x=3.75, y=-1.0), 0.28, color, 0.44, -2.0),
    billboard(camera, Vec3::new(x=3.55, y=2.15), 0.20, color, 0.48, -2.0),
  ])
}

///|
fn near_layer(camera : Camera) -> Object {
  let color = rgb(0.98, 0.42, 0.30)
  Object::group([
    billboard(
      camera,
      Vec3::new(x=-3.45, y=-1.65, z=5.0),
      0.34,
      color,
      0.58,
      2.0,
    ),
    billboard(camera, Vec3::new(x=-3.25, y=1.8, z=5.0), 0.26, color, 0.62, 2.0),
    billboard(camera, Vec3::new(x=3.25, y=1.45, z=5.0), 0.40, color, 0.56, 2.0),
  ])
}

///|
fn camera_card(camera : Camera) -> Object {
  let navy = rgb(0.08, 0.13, 0.24)
  let cyan = rgb(0.20, 0.82, 0.92)
  let yellow = rgb(1.0, 0.78, 0.20)
  let coral = rgb(0.98, 0.34, 0.32)
  let background = into_object(
    Rectangle::new(
      width=2.25,
      height=1.35,
      style=fill_style(navy, opacity=0.96, stroke=cyan, stroke_width=3.0),
    ),
  ).with_z_index(5.0)
  let badge = into_object(
      Circle::new(
        radius=0.24,
        style=fill_style(coral, stroke=Rgba::white(), stroke_width=1.7),
      ),
    )
    .move_to(Vec3::new(x=-0.62, y=0.24))
    .with_z_index(6.0)
  let arrow = into_object(
    Polygon::new(
      [
        Vec3::new(x=0.20, y=-0.38),
        Vec3::new(x=0.88, y=0.0),
        Vec3::new(x=0.20, y=0.38),
      ],
      style=fill_style(yellow, stroke=yellow, stroke_width=1.0),
    ),
  ).with_z_index(6.0)
  let accent = world_line(
    Vec3::new(x=-0.92, y=-0.42),
    Vec3::new(x=-0.18, y=-0.42),
    cyan,
    width=4.0,
    z_index=6.0,
  )
  let center = camera.camera_to_world(Vec3::new(x=2.25, y=0.30, z=2.0))
  Object::group([background, badge, arrow, accent]).with_transform(
    camera.inverse_rotation_transform().then(Transform::translate(center)),
  )
}

///|
fn camera_hud() -> Object {
  let cyan = rgb(0.20, 0.82, 0.92)
  let frame = into_object(
    Rectangle::new(
      width=1.22,
      height=0.58,
      style=ShapeStyle::new(
        fill=rgb(0.04, 0.08, 0.13),
        fill_opacity=0.86,
        stroke=cyan,
        stroke_width=2.0,
      ),
    ),
  ).with_z_index(10.0)
  let red = axis_marker(Vec3::new(x=-0.36, y=0.0), rgb(0.96, 0.30, 0.28)).with_z_index(
    11.0,
  )
  let green = axis_marker(Vec3::zero(), rgb(0.24, 0.82, 0.48)).with_z_index(
    11.0,
  )
  let blue = axis_marker(Vec3::new(x=0.36, y=0.0), rgb(0.24, 0.58, 0.98)).with_z_index(
    11.0,
  )
  Object::group([frame, red, green, blue]).with_transform(
    Transform::translate(Vec3::new(x=-4.86, y=2.58)),
  )
}

///|
async fn animate() -> Unit {
  let frame_prefix = "camera_showcase_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/camera_showcase_720p60.mp4"
  let camera = Camera::new(
    pixel_width=1280,
    pixel_height=720,
    frame_width=11.2,
    background=rgb(0.025, 0.04, 0.065),
    projection=Perspective,
    phi=degrees(65.0),
    theta=degrees(-135.0),
    zoom=0.94,
    focal_distance=18.0,
  )
  let scene = Scene::new(config=SceneConfig::new(frame_rate=60.0), camera~)
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60.0,
    movie_path~,
  )
  writer.attach(scene)

  let far = scene.object(far_layer(camera))
  let middle = scene.object(middle_layer(camera))
  let near = scene.object(near_layer(camera))
  let grid = scene.object(floor_grid())
  let axes = scene.object(coordinate_axes())
  let x_marker = scene.object(
    axis_marker(Vec3::new(x=3.7, y=0.0), rgb(0.96, 0.30, 0.28)),
  )
  let y_marker = scene.object(
    axis_marker(Vec3::new(x=0.0, y=3.7), rgb(0.24, 0.82, 0.48)),
  )
  let z_marker = scene.object(
    axis_marker(Vec3::new(x=0.0, y=0.0, z=3.2), rgb(0.24, 0.58, 0.98)),
  )
  scene.add_fixed_orientation(x_marker)
  scene.add_fixed_orientation(y_marker)
  scene.add_fixed_orientation(z_marker)
  let card = scene.object(camera_card(camera))
  let card_axis = camera
    .inverse_rotation_transform()
    .apply_vec(Vec3::new(x=0.0, y=1.0, z=0.0))
    .normalize_or(Vec3::new(x=0.0, y=1.0, z=0.0))
  let hud = scene.object(camera_hud())
  scene.add_fixed_in_frame(hud)

  scene.play([
    Animation::lagged_start(
      [
        Animation::draw_border_then_fill(far, run_time=0.75, rate_func=Smooth),
        Animation::draw_border_then_fill(
          middle,
          run_time=0.75,
          rate_func=Smooth,
        ),
        Animation::draw_border_then_fill(near, run_time=0.75, rate_func=Smooth),
        Animation::create(grid, run_time=1.1, rate_func=Smooth),
        Animation::create(axes, run_time=1.1, rate_func=Smooth),
        Animation::create(x_marker, run_time=0.45, rate_func=Smooth),
        Animation::create(y_marker, run_time=0.45, rate_func=Smooth),
        Animation::create(z_marker, run_time=0.45, rate_func=Smooth),
        Animation::draw_border_then_fill(card, run_time=1.0, rate_func=Smooth),
        Animation::create(hud, run_time=0.55, rate_func=Smooth),
      ],
      run_time=2.3,
      lag_ratio=0.10,
      rate_func=Smooth,
    ),
  ])
  scene.play([Animation::wait(0.25)])

  scene.play([
    Animation::move_camera(
      frame_center=Vec3::new(x=0.28, y=-0.16, z=0.24),
      phi=degrees(73.0),
      theta=degrees(-118.0),
      zoom=1.02,
      focal_distance=16.0,
      run_time=2.5,
      rate_func=Smooth,
    ),
    Animation::rotate(
      card,
      angle=@math.PI,
      axis=card_axis,
      run_time=2.5,
      rate_func=Smooth,
    ),
  ])

  scene.play([
    Animation::move_camera(
      frame_center=Vec3::new(x=-0.48, y=0.38, z=0.18),
      phi=degrees(58.0),
      theta=degrees(-154.0),
      gamma=degrees(4.0),
      zoom=0.88,
      focal_distance=13.5,
      run_time=2.6,
      rate_func=Smooth,
    ),
    Animation::rotate(
      card,
      angle=@math.PI,
      axis=card_axis,
      run_time=2.6,
      rate_func=Smooth,
    ),
  ])

  scene.play([
    Animation::orbit_camera(
      phi_delta=degrees(8.0),
      theta_delta=degrees(34.0),
      gamma_delta=degrees(-4.0),
      run_time=1.9,
      rate_func=Smooth,
    ),
  ])

  scene.play([
    Animation::move_camera(
      frame_center=camera.frame_center,
      phi=camera.phi,
      theta=camera.theta,
      gamma=camera.gamma,
      zoom=camera.zoom,
      focal_distance=camera.focal_distance,
      run_time=2.1,
      rate_func=Smooth,
    ),
  ])
  scene.play([Animation::wait(0.35)])

  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
