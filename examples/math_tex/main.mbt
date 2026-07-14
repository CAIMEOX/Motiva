///|
using @object {type Object, type Rgba, type Vec3}

///|
using @render {type CairoRenderer, type Camera, type MovieWriter}

///|
using @scene {type Animation, type ObjectId, type Scene, type SceneConfig}

///|
using @tex {type TexEngine}

///|
suberror MathTexExampleError {
  MissingFormulaPart(String)
}

///|
fn resolve_part(
  scene : Scene,
  root : ObjectId,
  paths : Array[@object.FamilyPath],
  name : String,
) -> ObjectId raise {
  match paths {
    [path] => scene.resolve_family_path(root, path)
    _ => raise MissingFormulaPart(name)
  }
}

///|
fn place(object : Object, y : Double) -> Object {
  object.move_to(Vec3::new(x=0.0, y~))
}

///|
async fn animate() -> Unit {
  let frame_prefix = "math_tex_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/math_tex_720p60.mp4"
  let scene = Scene::new(config=SceneConfig::new(frame_rate=60))
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(
      camera=Camera::new(
        pixel_width=1280,
        pixel_height=720,
        frame_width=8.0,
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
  let tex = TexEngine::new()
  let equation = tex
    .math_tex(["a^2", "+", "b^2", "=", "c^2"], font_size=68.0)
    .set_color_by_tex("a^2", Rgba::rgb(r=0.96, g=0.31, b=0.27))
    .set_color_by_tex("b^2", Rgba::rgb(r=0.20, g=0.62, b=0.96))
    .set_color_by_tex("c^2", Rgba::rgb(r=0.24, g=0.82, b=0.48))
  let a_paths = equation.part_paths("a^2")
  let plus_paths = equation.part_paths("+")
  let b_paths = equation.part_paths("b^2")
  let equals_paths = equation.part_paths("=")
  let c_paths = equation.part_paths("c^2")
  let equation_root = scene.object(place(equation.object(), 0.85))
  let a = resolve_part(scene, equation_root, a_paths, "a^2")
  let plus = resolve_part(scene, equation_root, plus_paths, "+")
  let b = resolve_part(scene, equation_root, b_paths, "b^2")
  let equals = resolve_part(scene, equation_root, equals_paths, "=")
  let c = resolve_part(scene, equation_root, c_paths, "c^2")
  let function = tex
    .math_tex(["f(x) = x^3 - 2x"], substrings_to_isolate=["x"], font_size=56.0)
    .set_color_by_tex("x", Rgba::rgb(r=0.98, g=0.72, b=0.20))
  let function_paths = function.part_paths("f(x) = x^3 - 2x")
  let x_paths = function.part_paths("x")
  let function_root = scene.object(place(function.object(), -0.85))
  let function_main = resolve_part(
    scene, function_root, function_paths, "function",
  )
  let x_ids = x_paths.map(path => scene.resolve_family_path(function_root, path))
  scene.play([
    Animation::lagged_start(
      [a, plus, b, equals, c, function_main].map(id => {
        Animation::create(id, run_time=0.8, rate_func=@scene.Smooth)
      }),
      run_time=3.0,
      lag_ratio=0.18,
      rate_func=@scene.Smooth,
    ),
  ])
  scene.play([
    Animation::group(
      [
        Animation::scale(
          a,
          sx=1.25,
          sy=1.25,
          run_time=1.3,
          rate_func=@scene.ThereAndBack,
        ),
        Animation::scale(
          b,
          sx=1.25,
          sy=1.25,
          run_time=1.3,
          rate_func=@scene.ThereAndBack,
        ),
        Animation::scale(
          c,
          sx=1.25,
          sy=1.25,
          run_time=1.3,
          rate_func=@scene.ThereAndBack,
        ),
      ],
      run_time=2.2,
      lag_ratio=0.2,
      rate_func=@scene.Smooth,
    ),
  ])
  scene.play([
    Animation::lagged_start(
      x_ids.map(id => {
        Animation::scale(
          id,
          sx=1.35,
          sy=1.35,
          run_time=1.1,
          rate_func=@scene.ThereAndBack,
        )
      }),
      run_time=2.0,
      lag_ratio=0.3,
      rate_func=@scene.Smooth,
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
