///|
using @object {type Rgba, type Vec3}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
using @tex {type TexEngine, type TransformMatchingTex}

///|
async fn animate() -> Unit {
  let frame_prefix = "transform_matching_tex_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/transform_matching_tex_720p60.mp4"
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
  let tex = TexEngine::new()
  let source = tex
    .math_tex(["a^2", "+", "b^2", "=", "c^2"], font_size=72.0)
    .set_color_by_tex("a^2", Rgba::rgb(r=0.95, g=0.34, b=0.30))
    .set_color_by_tex("b^2", Rgba::rgb(r=0.25, g=0.65, b=0.98))
    .set_color_by_tex("c^2", Rgba::rgb(r=0.30, g=0.84, b=0.52))
  let target = tex
    .math_tex(["c^2", "-", "a^2", "=", "b^2"], font_size=72.0)
    .set_color_by_tex("a^2", Rgba::rgb(r=0.95, g=0.34, b=0.30))
    .set_color_by_tex("b^2", Rgba::rgb(r=0.25, g=0.65, b=0.98))
    .set_color_by_tex("c^2", Rgba::rgb(r=0.30, g=0.84, b=0.52))
  let source_root = scene.object(source.object().move_to(Vec3::zero()))
  scene.play([Animation::write(source_root, run_time=2.0)])
  scene.play([Animation::wait(0.35)])
  let matching = TransformMatchingTex::new(
    scene,
    source_root,
    source,
    target,
    target_object=target.object().move_to(Vec3::zero()),
    run_time=2.2,
  )
  scene.play([matching])
  scene.play([Animation::wait(0.75)])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
