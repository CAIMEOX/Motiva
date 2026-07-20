///|
using @object {type Object, type Rgba, type Vec3}

///|
using @pango_native {type MarkupText, type Text, type TextSpan, type TextStyle}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn place(object : Object, x : Double, y : Double) -> Object {
  object.move_to(Vec3::new(x~, y~))
}

///|
async fn animate() -> Unit {
  let frame_prefix = "pango_native_showcase_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/pango_native_showcase_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=8.0,
      background=Rgba::rgb(r=0.025, g=0.03, b=0.045),
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

  let title = Text::new(
    "Motiva Text",
    style=TextStyle::new(font_size=78.0, weight=Bold),
  ).set_color_by_gradient([
    Rgba::rgb(r=0.20, g=0.72, b=1.0),
    Rgba::rgb(r=0.42, g=0.92, b=0.62),
    Rgba::rgb(r=1.0, g=0.73, b=0.26),
  ])
  let title_id = scene.object(place(title.object(), 0.0, 1.75))

  let multilingual = Text::new(
    "Hello  العربية  中文",
    style=TextStyle::new(font_size=54.0),
    spans=[
      TextSpan::new(0, 5, color=Rgba::rgb(r=0.35, g=0.72, b=1.0)),
      TextSpan::new(7, 14, color=Rgba::rgb(r=0.98, g=0.42, b=0.56), weight=Bold),
      TextSpan::new(16, 18, color=Rgba::rgb(r=1.0, g=0.78, b=0.28)),
    ],
  ).set_gradient_by_text("中文", [
    Rgba::rgb(r=1.0, g=0.78, b=0.28),
    Rgba::rgb(r=1.0, g=0.48, b=0.30),
  ])
  let multilingual_id = scene.object(place(multilingual.object(), 0.0, 0.45))

  let markup = MarkupText::new(
    "<b>Pango</b> shaping  <span foreground='#55d68b' underline='double'>ligatures</span>  <i>office</i>",
    style=TextStyle::new(font_size=42.0),
  )
  let markup_id = scene.object(place(markup.object(), 0.0, -0.65))

  let caption = Text::new(
    "Unicode ranges remain animatable",
    style=TextStyle::new(
      font_size=34.0,
      color=Rgba::rgb(r=0.68, g=0.72, b=0.82),
    ),
  )
  let caption_id = scene.object(place(caption.object(), 0.0, -1.65))

  scene.play([
    Animation::group(
      [
        Animation::write(title_id, run_time=1.7, lag_ratio=0.08),
        Animation::group([
          Animation::fade_in(
            multilingual_id,
            shift=Vec3::new(x=0.0, y=-0.3),
            run_time=1.1,
            rate_func=Smooth,
          ),
          Animation::fade_in(
            markup_id,
            shift=Vec3::new(x=0.0, y=-0.3),
            run_time=1.3,
            rate_func=Smooth,
          ),
        ]),
        Animation::write(caption_id, run_time=1.5, lag_ratio=0.04),
        Animation::wait(0.5),
      ],
      lag_ratio=1.0,
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
