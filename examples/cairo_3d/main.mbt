///|
using @object {
  into_object,
  type Arrow3D,
  type Cube,
  type Rgba,
  type ShapeStyle,
  type Sphere,
  type Surface,
  type ThreeDAxes,
  type Torus,
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
fn rgba(r : Double, g : Double, b : Double, a? : Double = 1.0) -> Rgba {
  Rgba::new(r~, g~, b~, a~)
}

///|
fn wave_surface() -> Surface {
  Surface::new(
    (u, v) => {
      Vec3::new(
        x=u,
        y=v,
        z=-1.35 + 0.18 * @math.sin(1.4 * u) * @math.cos(1.6 * v),
      )
    },
    u_min=-4.6,
    u_max=4.6,
    v_min=-3.2,
    v_max=3.2,
    u_resolution=12,
    v_resolution=10,
    style=ShapeStyle::surface(
      fill=rgba(0.08, 0.36, 0.48),
      fill_opacity=0.58,
      stroke=rgba(0.18, 0.72, 0.82),
      stroke_opacity=0.35,
      stroke_width=0.45,
    ),
    checkerboard_colors=[rgba(0.06, 0.28, 0.40), rgba(0.10, 0.48, 0.58)],
  )
}

///|
async fn animate() -> Unit {
  let frame_dir = "output/frames"
  let frame_prefix = "cairo_3d_720p30"
  let movie_path = "output/cairo_3d_720p30.mp4"
  let camera = Camera::new(
    pixel_width=1280,
    pixel_height=720,
    frame_width=11.5,
    background=rgba(0.018, 0.025, 0.045),
    projection=Perspective,
    phi=degrees(68.0),
    theta=degrees(-52.0),
    focal_distance=18.0,
    light_source=Vec3::new(x=-6.0, y=-8.0, z=9.0),
  )
  let scene = Scene::new(config=SceneConfig::new(frame_rate=30.0), camera~)
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=30.0,
    movie_path~,
  )
  writer.attach(scene)

  let axes = scene.object(
    ThreeDAxes::new(
      x_min=-4.0,
      x_max=4.0,
      y_min=-3.0,
      y_max=3.0,
      z_min=-2.0,
      z_max=3.0,
      x_length=8.0,
      y_length=6.0,
      z_length=5.0,
      tips=false,
      tick_size=0.08,
      style=ShapeStyle::stroked(color=rgba(0.56, 0.61, 0.70), stroke_width=1.4),
    ),
  )
  let floor = scene.object(wave_surface())
  let sphere = scene.object(
    Sphere::new(
      center=Vec3::new(x=-2.25, y=0.0, z=0.15),
      radius=1.05,
      u_resolution=16,
      v_resolution=10,
      style=ShapeStyle::surface(stroke_width=0.25),
      checkerboard_colors=[rgba(0.16, 0.64, 0.90), rgba(0.10, 0.34, 0.72)],
    ),
  )
  let cube_object = into_object(
    Cube::new(
      side_length=1.75,
      style=ShapeStyle::surface(
        fill=rgba(0.94, 0.30, 0.24),
        fill_opacity=0.82,
        stroke=rgba(1.0, 0.78, 0.34),
        stroke_width=0.7,
      ),
    ),
  ).with_transform(
    Transform::rotate_x(angle=degrees(18.0))
    .then(Transform::rotate_z(angle=degrees(24.0)))
    .then(Transform::translate(Vec3::new(x=2.15, y=0.0, z=0.1))),
  )
  let cube = scene.object(cube_object)
  let arrow = scene.object(
    Arrow3D::new(
      start=Vec3::new(x=-0.4, y=-1.6, z=-0.8),
      end=Vec3::new(x=0.9, y=-0.7, z=1.65),
      thickness=0.035,
      tip_height=0.38,
      tip_radius=0.12,
      radial_resolution=12,
      style=ShapeStyle::surface(
        fill=rgba(0.98, 0.78, 0.22),
        stroke=rgba(1.0, 0.90, 0.48),
        stroke_width=0.35,
      ),
    ),
  )

  scene.play([
    Animation::lagged_start(
      [
        Animation::create(floor, run_time=1.3),
        Animation::create(axes, run_time=1.0),
        Animation::create(sphere, run_time=1.2),
        Animation::create(cube, run_time=0.9),
        Animation::create(arrow, run_time=0.8),
      ],
      run_time=2.2,
      lag_ratio=0.12,
      rate_func=Smooth,
    ),
  ])

  scene.play([
    Animation::orbit_camera(
      phi_delta=degrees(7.0),
      theta_delta=degrees(42.0),
      run_time=2.2,
      rate_func=Smooth,
    ),
    Animation::rotate(
      cube,
      angle=1.5 * @math.PI,
      axis=Vec3::new(x=1.0, y=1.0, z=0.5),
      run_time=2.2,
      rate_func=Smooth,
    ),
  ])

  let torus_target = into_object(
    Torus::new(
      major_radius=0.82,
      minor_radius=0.30,
      u_resolution=16,
      v_resolution=10,
      style=ShapeStyle::surface(stroke_width=0.25),
      checkerboard_colors=[rgba(0.26, 0.82, 0.56), rgba(0.08, 0.48, 0.40)],
    ),
  ).with_transform(Transform::translate(Vec3::new(x=-2.25, y=0.0, z=0.15)))
  scene.play([
    Animation::transform(sphere, torus_target, run_time=2.0, rate_func=Smooth),
    Animation::orbit_camera(
      theta_delta=degrees(34.0),
      run_time=2.0,
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
