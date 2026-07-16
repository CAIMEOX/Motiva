///|
priv type NativeEngine

///|
priv type NativeJob

///|
priv type NativeRender

///|
priv type NativeStatus

///|
priv type NativeFontList

///|
extern "c" fn native_engine_new() -> NativeEngine = "motiva_pango_engine_new"

///|
extern "c" fn native_pango_version() -> Bytes = "motiva_pango_version"

///|
extern "c" fn native_cairo_version() -> Bytes = "motiva_cairo_version"

///|
#borrow(engine, path)
extern "c" fn native_engine_register_font(
  engine : NativeEngine,
  path : Bytes,
) -> NativeStatus = "motiva_pango_engine_register_font"

///|
#borrow(engine, path)
extern "c" fn native_engine_unregister_font(
  engine : NativeEngine,
  path : Bytes,
) -> NativeStatus = "motiva_pango_engine_unregister_font"

///|
#borrow(engine)
extern "c" fn native_engine_list_fonts(engine : NativeEngine) -> NativeFontList = "motiva_pango_engine_list_fonts"

///|
#borrow(status)
extern "c" fn native_status_code(status : NativeStatus) -> Int = "motiva_pango_status_code"

///|
#borrow(status)
extern "c" fn native_status_message(status : NativeStatus) -> Bytes = "motiva_pango_status_message"

///|
#borrow(fonts)
extern "c" fn native_font_list_length(fonts : NativeFontList) -> Int = "motiva_pango_font_list_length"

///|
#borrow(fonts)
extern "c" fn native_font_list_get(
  fonts : NativeFontList,
  index : Int,
) -> Bytes = "motiva_pango_font_list_get"

///|
#borrow(text)
extern "c" fn native_job_new(text : Bytes, markup : Bool) -> NativeJob = "motiva_pango_job_new"

///|
#borrow(job, font_family)
extern "c" fn native_job_set_font(
  job : NativeJob,
  font_family : Bytes,
  font_size : Double,
  slant : Int,
  weight : Int,
  stretch : Int,
) = "motiva_pango_job_set_font"

///|
#borrow(job)
extern "c" fn native_job_set_paint(
  job : NativeJob,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) = "motiva_pango_job_set_paint"

///|
#borrow(job, language)
extern "c" fn native_job_set_base_language(job : NativeJob, language : Bytes) = "motiva_pango_job_set_base_language"

///|
#borrow(job, font_features)
extern "c" fn native_job_set_base_features(
  job : NativeJob,
  font_features : Bytes,
) = "motiva_pango_job_set_base_features"

///|
#borrow(job)
extern "c" fn native_job_set_box(
  job : NativeJob,
  has_width : Bool,
  width : Double,
  height_mode : Int,
  height : Double,
  dpi : Double,
) = "motiva_pango_job_set_box"

///|
#borrow(job)
extern "c" fn native_job_set_flow(
  job : NativeJob,
  wrap : Int,
  ellipsize : Int,
  alignment : Int,
  auto_dir : Bool,
  direction : Int,
  single_paragraph : Bool,
) = "motiva_pango_job_set_flow"

///|
#borrow(job)
extern "c" fn native_job_set_paragraph(
  job : NativeJob,
  justify : Bool,
  justify_last_line : Bool,
  indent : Double,
  spacing : Double,
  has_line_spacing : Bool,
  line_spacing : Double,
) = "motiva_pango_job_set_paragraph"

///|
#borrow(job, family)
extern "c" fn native_job_add_family(
  job : NativeJob,
  start : Int,
  end : Int,
  family : Bytes,
) = "motiva_pango_job_add_family"

///|
#borrow(job)
extern "c" fn native_job_add_size(
  job : NativeJob,
  start : Int,
  end : Int,
  size : Double,
) = "motiva_pango_job_add_size"

///|
#borrow(job)
extern "c" fn native_job_add_slant(
  job : NativeJob,
  start : Int,
  end : Int,
  slant : Int,
) = "motiva_pango_job_add_slant"

///|
#borrow(job)
extern "c" fn native_job_add_weight(
  job : NativeJob,
  start : Int,
  end : Int,
  weight : Int,
) = "motiva_pango_job_add_weight"

///|
#borrow(job)
extern "c" fn native_job_add_stretch(
  job : NativeJob,
  start : Int,
  end : Int,
  stretch : Int,
) = "motiva_pango_job_add_stretch"

///|
#borrow(job)
extern "c" fn native_job_add_foreground(
  job : NativeJob,
  start : Int,
  end : Int,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) = "motiva_pango_job_add_foreground"

///|
#borrow(job)
extern "c" fn native_job_add_background(
  job : NativeJob,
  start : Int,
  end : Int,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) = "motiva_pango_job_add_background"

///|
#borrow(job)
extern "c" fn native_job_add_underline(
  job : NativeJob,
  start : Int,
  end : Int,
  underline : Int,
) = "motiva_pango_job_add_underline"

///|
#borrow(job)
extern "c" fn native_job_add_underline_color(
  job : NativeJob,
  start : Int,
  end : Int,
  red : Double,
  green : Double,
  blue : Double,
) = "motiva_pango_job_add_underline_color"

///|
#borrow(job)
extern "c" fn native_job_add_overline(
  job : NativeJob,
  start : Int,
  end : Int,
  enabled : Bool,
) = "motiva_pango_job_add_overline"

///|
#borrow(job)
extern "c" fn native_job_add_overline_color(
  job : NativeJob,
  start : Int,
  end : Int,
  red : Double,
  green : Double,
  blue : Double,
) = "motiva_pango_job_add_overline_color"

///|
#borrow(job)
extern "c" fn native_job_add_strikethrough(
  job : NativeJob,
  start : Int,
  end : Int,
  enabled : Bool,
) = "motiva_pango_job_add_strikethrough"

///|
#borrow(job)
extern "c" fn native_job_add_strikethrough_color(
  job : NativeJob,
  start : Int,
  end : Int,
  red : Double,
  green : Double,
  blue : Double,
) = "motiva_pango_job_add_strikethrough_color"

///|
#borrow(job)
extern "c" fn native_job_add_rise(
  job : NativeJob,
  start : Int,
  end : Int,
  rise : Double,
) = "motiva_pango_job_add_rise"

///|
#borrow(job)
extern "c" fn native_job_add_letter_spacing(
  job : NativeJob,
  start : Int,
  end : Int,
  spacing : Double,
) = "motiva_pango_job_add_letter_spacing"

///|
#borrow(job, features)
extern "c" fn native_job_add_font_features(
  job : NativeJob,
  start : Int,
  end : Int,
  features : Bytes,
) = "motiva_pango_job_add_font_features"

///|
#borrow(job, language)
extern "c" fn native_job_add_language(
  job : NativeJob,
  start : Int,
  end : Int,
  language : Bytes,
) = "motiva_pango_job_add_language"

///|
#borrow(engine, job)
extern "c" fn native_job_render(
  engine : NativeEngine,
  job : NativeJob,
) -> NativeRender = "motiva_pango_job_render"

///|
#borrow(render)
extern "c" fn native_render_status(render : NativeRender) -> Int = "motiva_pango_render_status"

///|
#borrow(render)
extern "c" fn native_render_message(render : NativeRender) -> Bytes = "motiva_pango_render_message"

///|
#borrow(render)
extern "c" fn native_render_svg(render : NativeRender) -> Bytes = "motiva_pango_render_svg"

///|
#borrow(render)
extern "c" fn native_render_text(render : NativeRender) -> Bytes = "motiva_pango_render_text"

///|
#borrow(render, ink_x, ink_y, ink_width, ink_height, logical_x, logical_y, logical_width, logical_height, baseline, unknown_glyphs, glyph_count, line_count)
extern "c" fn native_render_metrics(
  render : NativeRender,
  ink_x : Ref[Double],
  ink_y : Ref[Double],
  ink_width : Ref[Double],
  ink_height : Ref[Double],
  logical_x : Ref[Double],
  logical_y : Ref[Double],
  logical_width : Ref[Double],
  logical_height : Ref[Double],
  baseline : Ref[Double],
  unknown_glyphs : Ref[Int],
  glyph_count : Ref[Int],
  line_count : Ref[Int],
) = "motiva_pango_render_metrics"

///|
#borrow(render)
extern "c" fn native_render_cluster_count(render : NativeRender) -> Int = "motiva_pango_render_cluster_count"

///|
#borrow(render, source_start, source_end, glyph_start, glyph_end, line_index, bidi_level, x, y, width, height)
extern "c" fn native_render_cluster(
  render : NativeRender,
  index : Int,
  source_start : Ref[Int],
  source_end : Ref[Int],
  glyph_start : Ref[Int],
  glyph_end : Ref[Int],
  line_index : Ref[Int],
  bidi_level : Ref[Int],
  x : Ref[Double],
  y : Ref[Double],
  width : Ref[Double],
  height : Ref[Double],
) -> Bool = "motiva_pango_render_cluster"

///|
#borrow(render)
extern "c" fn native_render_line_count(render : NativeRender) -> Int = "motiva_pango_render_line_count"

///|
#borrow(render, source_start, source_end, ink_x, ink_y, ink_width, ink_height, logical_x, logical_y, logical_width, logical_height, baseline)
extern "c" fn native_render_line(
  render : NativeRender,
  index : Int,
  source_start : Ref[Int],
  source_end : Ref[Int],
  ink_x : Ref[Double],
  ink_y : Ref[Double],
  ink_width : Ref[Double],
  ink_height : Ref[Double],
  logical_x : Ref[Double],
  logical_y : Ref[Double],
  logical_width : Ref[Double],
  logical_height : Ref[Double],
  baseline : Ref[Double],
) -> Bool = "motiva_pango_render_line"
