///|
using @object {type Object, type Rgba, type Vec3}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn mdn_rotated_arc_svg() -> String {
  let source =
    #|<svg width="320" height="320" xmlns="http://www.w3.org/2000/svg">
    #|  <path
    #|    d="M 10 315
    #|       L 110 215
    #|       A 30 50 0 0 1 162.55 162.45
    #|       L 172.55 152.45
    #|       A 30 50 -45 0 1 215.1 109.9
    #|       L 315 10"
    #|    stroke="black"
    #|    fill="green"
    #|    stroke-width="2"
    #|    fill-opacity="0.5" />
    #|</svg>
  source
}

///|
fn mdn_flag_grid_svg() -> String {
  let source =
    #|<svg width="360" height="360" xmlns="http://www.w3.org/2000/svg">
    #|  <path
    #|    d="M 100 100
    #|       A 45 45, 0, 0, 0, 145 145
    #|       L 145 100 Z"
    #|    fill="#00FF00A0"
    #|    stroke="black"
    #|    stroke-width="2" />
    #|  <path
    #|    d="M 250 100
    #|       A 45 45, 0, 1, 0, 295 145
    #|       L 295 100 Z"
    #|    fill="#FF0000A0"
    #|    stroke="black"
    #|    stroke-width="2" />
    #|  <path
    #|    d="M 100 250
    #|       A 45 45, 0, 0, 1, 145 295
    #|       L 145 250 Z"
    #|    fill="#FF00FFA0"
    #|    stroke="black"
    #|    stroke-width="2" />
    #|  <path
    #|    d="M 250 250
    #|       A 45 45, 0, 1, 1, 295 295
    #|       L 295 250 Z"
    #|    fill="#0000FFA0"
    #|    stroke="black"
    #|    stroke-width="2" />
    #|  <path
    #|    d="M 45 45 L 345 45 L 345 345 L 45 345 Z M 195 45 L 195 345 M 45 195 L 345 195"
    #|    fill="none"
    #|    stroke="black" />
    #|</svg>
  source
}

///|
fn mdn_semicircle_arc_svg() -> String {
  let source =
    #|<svg width="320" height="220" xmlns="http://www.w3.org/2000/svg">
    #|  <path
    #|    d="M 60 150 A 100 100 0 1 0 260 150"
    #|    fill="none"
    #|    stroke="red"
    #|    stroke-width="8" />
    #|  <path
    #|    d="M 60 150 A 100 100 0 1 1 260 150"
    #|    fill="none"
    #|    stroke="blue"
    #|    stroke-width="4" />
    #|</svg>
  source
}

///|
fn svg_object(
  source : String,
  height : Double,
  x : Double,
) -> Object raise @svg.SvgError {
  @svg.parse_string(source, height~).move_to(Vec3::new(x~, y=0.0))
}

///|
async fn animate() -> Unit {
  let frame_prefix = "svg_arc_showcase_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/svg_arc_showcase_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=7.5,
      background=Rgba::white(),
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
  let rotated = scene.object(svg_object(mdn_rotated_arc_svg(), 1.85, -2.45))
  let flags = scene.object(svg_object(mdn_flag_grid_svg(), 2.15, 0.0))
  let semicircle = scene.object(
    svg_object(mdn_semicircle_arc_svg(), 1.55, 2.55),
  )
  scene.play([
    Animation::lagged_start(
      [
        Animation::draw_border_then_fill(
          rotated,
          run_time=1.0,
          rate_func=Smooth,
        ),
        Animation::draw_border_then_fill(flags, run_time=1.1, rate_func=Smooth),
        Animation::draw_border_then_fill(
          semicircle,
          run_time=1.0,
          rate_func=Smooth,
        ),
      ],
      run_time=2.4,
      lag_ratio=0.22,
      rate_func=Smooth,
    ),
  ])
  scene.play([
    Animation::group(
      [
        Animation::rotate(
          rotated,
          angle=@math.PI / 8.0,
          run_time=1.8,
          rate_func=ThereAndBack,
        ),
        flags
        .animate(run_time=1.8, rate_func=ThereAndBack)
        .scale(sx=1.08, sy=1.08)
        .to_animation(),
        semicircle
        .animate(run_time=1.8, rate_func=ThereAndBack)
        .shift(Vec3::new(x=0.0, y=0.25))
        .to_animation(),
      ],
      run_time=2.1,
      lag_ratio=0.05,
      rate_func=Smooth,
    ),
  ])
  scene.play([Animation::wait(0.35)])
  scene.play([
    Animation::group(
      [
        Animation::fade_out(
          rotated,
          shift=Vec3::new(x=-0.4, y=0.35),
          scale=0.8,
          run_time=0.9,
          rate_func=RushInto,
        ),
        Animation::fade_out(
          flags,
          shift=Vec3::new(x=0.0, y=-0.3),
          scale=0.8,
          run_time=0.9,
          rate_func=RushInto,
        ),
        Animation::fade_out(
          semicircle,
          shift=Vec3::new(x=0.4, y=0.35),
          scale=0.8,
          run_time=0.9,
          rate_func=RushInto,
        ),
      ],
      run_time=1.0,
      lag_ratio=0.08,
      rate_func=RushInto,
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
