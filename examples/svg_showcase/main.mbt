///|
using @object {type Object, type Rgba, type ShapeStyle, type Vec3}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn orbit_svg() -> String {
  let source =
    #|<svg width="360" height="360" viewBox="-180 -180 360 360"
    #|     color="whitesmoke" xmlns="http://www.w3.org/2000/svg">
    #|  <defs>
    #|    <g id="petal">
    #|      <path d="M 0 -10 C 28 -12 40 2 0 25 C -40 2 -28 -12 0 -10 Z"
    #|            fill="currentColor" fill-opacity="0.58"
    #|            stroke="currentColor" stroke-width="3"/>
    #|    </g>
    #|  </defs>
    #|  <circle cx="0" cy="0" r="36" fill="rgba(255,255,255,0.10)"
    #|          stroke="currentColor" stroke-width="2"/>
    #|  <use href="#petal" color="tomato"
    #|       transform="rotate(0) translate(102 0) scale(1.10)"/>
    #|  <use href="#petal" color="rgb(255, 191, 0)"
    #|       transform="rotate(45) translate(102 0) scale(0.92)"/>
    #|  <use href="#petal" color="#65D46EFF"
    #|       transform="rotate(90) translate(102 0) scale(1.10)"/>
    #|  <use href="#petal" color="turquoise"
    #|       transform="rotate(135) translate(102 0) scale(0.92)"/>
    #|  <use href="#petal" color="dodgerblue"
    #|       transform="rotate(180) translate(102 0) scale(1.10)"/>
    #|  <use href="#petal" color="mediumslateblue"
    #|       transform="rotate(225) translate(102 0) scale(0.92)"/>
    #|  <use href="#petal" color="orchid"
    #|       transform="rotate(270) translate(102 0) scale(1.10)"/>
    #|  <use href="#petal" color="deeppink"
    #|       transform="rotate(315) translate(102 0) scale(0.92)"/>
    #|</svg>
  source
}

///|
fn palette_svg() -> String {
  let source =
    #|<svg width="720px" height="120px" viewBox="0 0 360 60"
    #|     xmlns="http://www.w3.org/2000/svg">
    #|  <defs>
    #|    <symbol id="chip" viewBox="0 0 48 48">
    #|      <rect x="2" y="2" width="44" height="44" rx="11" ry="11"
    #|            fill="currentColor" fill-opacity="0.24"
    #|            stroke="currentColor" stroke-width="2"/>
    #|      <circle cx="24" cy="18" r="8" fill="currentColor"/>
    #|      <path d="M 11 37 C 17 27 31 27 37 37"
    #|            fill="none" stroke="currentColor" stroke-width="4"/>
    #|    </symbol>
    #|  </defs>
    #|  <use href="#chip" x="5"   y="6" width="48" height="48" color="tomato"/>
    #|  <use href="#chip" x="65"  y="6" width="48" height="48" color="gold"/>
    #|  <use href="#chip" x="125" y="6" width="48" height="48" color="rgb(67, 214, 136)"/>
    #|  <use href="#chip" x="185" y="6" width="48" height="48" color="rgba(45, 187, 255, 0.82)"/>
    #|  <use href="#chip" x="245" y="6" width="48" height="48" color="#8B7CFFFF"/>
    #|  <use href="#chip" x="305" y="6" width="48" height="48" color="hotpink"/>
    #|</svg>
  source
}

///|
fn viewport_svg() -> String {
  let source =
    #|<svg width="720" height="240" viewBox="0 0 360 120"
    #|     xmlns="http://www.w3.org/2000/svg">
    #|  <rect x="4" y="7" width="166" height="106" rx="8"
    #|        fill="#1A2535" stroke="steelblue" stroke-width="2"/>
    #|  <rect x="190" y="7" width="166" height="106" rx="8"
    #|        fill="#1A2535" stroke="orchid" stroke-width="2"/>
    #|  <svg x="10" y="15" width="154" height="90" viewBox="0 0 100 40"
    #|       preserveAspectRatio="xMidYMid meet">
    #|    <rect x="1" y="1" width="98" height="38" rx="8"
    #|          fill="rgba(70, 150, 240, 0.18)" stroke="lightskyblue"/>
    #|    <circle cx="27" cy="20" r="13" fill="tomato" fill-opacity="0.82"/>
    #|    <path d="M 51 30 L 65 10 L 88 30 Z" fill="gold"/>
    #|  </svg>
    #|  <svg x="196" y="15" width="154" height="90" viewBox="0 0 100 40"
    #|       preserveAspectRatio="none">
    #|    <rect x="1" y="1" width="98" height="38" rx="8"
    #|          fill="rgba(220, 90, 210, 0.16)" stroke="violet"/>
    #|    <circle cx="27" cy="20" r="13" fill="tomato" fill-opacity="0.82"/>
    #|    <path d="M 51 30 L 65 10 L 88 30 Z" fill="gold"/>
    #|  </svg>
    #|</svg>
  source
}

///|
fn tint_style(
  style : ShapeStyle,
  fill_color : Rgba,
  stroke_color : Rgba,
) -> ShapeStyle {
  {
    fill: style.fill.map(_ => fill_color),
    fill_opacity: style.fill_opacity,
    stroke: style.stroke.map(_ => stroke_color),
    stroke_opacity: style.stroke_opacity,
    stroke_width: style.stroke_width,
  }
}

///|
fn tint_existing_paints(
  object : Object,
  fill_color : Rgba,
  stroke_color : Rgba,
) -> Object {
  let node = match object.node {
    Empty => @object.Empty
    Group(children) =>
      Group(
        children.map(child => {
          tint_existing_paints(child, fill_color, stroke_color)
        }),
      )
    Path(path, style) => Path(path, tint_style(style, fill_color, stroke_color))
  }
  { ..object, node, }
}

///|
fn parse_svg(
  source : String,
  height : Double,
  center : Vec3,
) -> Object raise @svg.SvgError {
  @svg.SvgObject::parse_string(source, height~).object().move_to(center)
}

///|
async fn animate() -> Unit {
  let frame_prefix = "svg_showcase_720p30"
  let frame_dir = "output/frames"
  let movie_path = "output/svg_showcase_720p30.mp4"
  let scene = Scene::new(config=SceneConfig::new(frame_rate=30))
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(
      camera=Camera::new(
        pixel_width=1280,
        pixel_height=720,
        frame_width=12.8,
        background=Rgba::rgb(r=0.025, g=0.035, b=0.055),
      ),
    ),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=30,
    movie_path~,
  )
  writer.attach(scene)
  let loader = @loader.SvgLoader::new()
  let a_source = "svg/testdata/manim/A.svg"
  let left_a = scene.object(
    tint_existing_paints(
      loader.load(a_source, height=1.45).object(),
      Rgba::rgb(r=0.20, g=0.72, b=1.0),
      Rgba::rgb(r=0.20, g=0.72, b=1.0),
    ).move_to(Vec3::new(x=-2.55, y=0.45)),
  )
  let right_a = scene.object(
    tint_existing_paints(
      loader.load(a_source, height=1.45).object(),
      Rgba::rgb(r=1.0, g=0.34, b=0.46),
      Rgba::rgb(r=1.0, g=0.34, b=0.46),
    ).move_to(Vec3::new(x=2.55, y=0.45)),
  )
  let palette = scene.object(
    parse_svg(palette_svg(), 0.78, Vec3::new(x=0.0, y=2.75)),
  )
  let orbit = scene.object(
    parse_svg(orbit_svg(), 2.35, Vec3::new(x=0.0, y=0.45)),
  )
  let viewports = scene.object(
    parse_svg(viewport_svg(), 1.5, Vec3::new(x=0.0, y=-2.15)),
  )
  let cool_plot = tint_existing_paints(
    loader
    .load("svg/testdata/manim/multiple_transforms.svg", height=5.55)
    .object(),
    Rgba::rgb(r=0.20, g=0.72, b=0.92),
    Rgba::rgb(r=0.58, g=0.82, b=0.98),
  )
  let warm_plot = tint_existing_paints(
    cool_plot,
    Rgba::rgb(r=0.98, g=0.56, b=0.24),
    Rgba::rgb(r=1.0, g=0.78, b=0.42),
  )
  let plot = scene.object(cool_plot)
  scene.play([
    Animation::lagged_start(
      [
        Animation::draw_border_then_fill(
          palette,
          run_time=1.1,
          rate_func=Smooth,
        ),
        Animation::fade_in(
          left_a,
          shift=Vec3::new(x=-0.55, y=0.0),
          scale=0.55,
          run_time=0.9,
          rate_func=RushFrom,
        ),
        Animation::create(orbit, run_time=1.25, rate_func=Smooth),
        Animation::fade_in(
          right_a,
          shift=Vec3::new(x=0.55, y=0.0),
          scale=0.55,
          run_time=0.9,
          rate_func=RushFrom,
        ),
        Animation::draw_border_then_fill(
          viewports,
          run_time=1.3,
          rate_func=Smooth,
        ),
      ],
      run_time=3.25,
      lag_ratio=0.18,
      rate_func=Smooth,
    ),
  ])
  scene.play([
    Animation::group(
      [
        Animation::rotate(
          orbit,
          angle=2.0 * @math.PI,
          run_time=2.4,
          rate_func=Smooth,
        ),
        left_a
        .animate(run_time=2.1, rate_func=ThereAndBack)
        .shift(Vec3::new(x=0.35, y=0.25))
        .scale(sx=1.16, sy=1.16)
        .to_animation(),
        right_a
        .animate(run_time=2.1, rate_func=ThereAndBack)
        .shift(Vec3::new(x=-0.35, y=0.25))
        .scale(sx=1.16, sy=1.16)
        .to_animation(),
        viewports
        .animate(run_time=2.2, rate_func=ThereAndBack)
        .scale(sx=1.04, sy=1.04)
        .to_animation(),
        palette
        .animate(run_time=2.0, rate_func=ThereAndBack)
        .shift(Vec3::new(x=0.0, y=-0.12))
        .to_animation(),
      ],
      run_time=2.5,
      lag_ratio=0.04,
      rate_func=Smooth,
    ),
  ])
  scene.play([Animation::wait(0.35)])
  scene.play([
    Animation::group(
      [
        Animation::fade_out(
          palette,
          shift=Vec3::new(x=0.0, y=0.35),
          scale=0.82,
          run_time=0.85,
          rate_func=RushInto,
        ),
        Animation::fade_out(
          left_a,
          shift=Vec3::new(x=-0.45, y=0.0),
          scale=0.75,
          run_time=0.85,
          rate_func=RushInto,
        ),
        Animation::fade_out(orbit, scale=0.6, run_time=0.95, rate_func=RushInto),
        Animation::fade_out(
          right_a,
          shift=Vec3::new(x=0.45, y=0.0),
          scale=0.75,
          run_time=0.85,
          rate_func=RushInto,
        ),
        Animation::fade_out(
          viewports,
          shift=Vec3::new(x=0.0, y=-0.35),
          scale=0.82,
          run_time=0.85,
          rate_func=RushInto,
        ),
      ],
      run_time=1.1,
      lag_ratio=0.04,
      rate_func=RushInto,
    ),
  ])
  scene.play([
    Animation::draw_border_then_fill(
      plot,
      run_time=2.35,
      rate_func=DoubleSmooth,
    ),
  ])
  scene.play([
    Animation::transform(plot, warm_plot, run_time=1.65, rate_func=ThereAndBack),
  ])
  scene.play([
    Animation::scale(
      plot,
      sx=1.07,
      sy=1.07,
      run_time=1.2,
      rate_func=ThereAndBack,
    ),
  ])
  scene.play([Animation::wait(0.4)])
  scene.play([
    Animation::fade_out(
      plot,
      shift=Vec3::new(x=0.0, y=0.3),
      scale=0.94,
      run_time=0.9,
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
