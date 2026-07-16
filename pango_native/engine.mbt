///|
let manim_text_adjustment : Double = 4.8

///|
let manim_text_scale : Double = 0.05

///|
let max_pango_value : Double = 2097151.0

///|
pub(all) struct FontRegistration {
  path : String
} derive(Eq, Debug)

///|
pub struct PangoTextEngine {
  priv native : NativeEngine
}

///|
pub fn PangoTextEngine::new() -> PangoTextEngine {
  { native: native_engine_new() }
}

///|
pub impl Default for PangoTextEngine with fn default() {
  PangoTextEngine::new()
}

///|
pub fn pango_version() -> String {
  @utf8.decode_lossy(native_pango_version())
}

///|
pub fn cairo_version() -> String {
  @utf8.decode_lossy(native_cairo_version())
}

///|
pub fn PangoTextEngine::register_font(
  self : PangoTextEngine,
  path : String,
) -> FontRegistration raise TextError {
  let status = native_engine_register_font(self.native, @utf8.encode(path))
  check_native_status(status)
  { path, }
}

///|
pub fn PangoTextEngine::unregister_font(
  self : PangoTextEngine,
  registration : FontRegistration,
) -> Unit raise TextError {
  let status = native_engine_unregister_font(
    self.native,
    @utf8.encode(registration.path),
  )
  check_native_status(status)
}

///|
pub fn PangoTextEngine::font_list(self : PangoTextEngine) -> Array[String] {
  let native = native_engine_list_fonts(self.native)
  [
    for index in 0..<native_font_list_length(native) => {
      @utf8.decode_lossy(native_font_list_get(native, index))
    }
  ]
}

///|
pub fn PangoTextEngine::has_font(
  self : PangoTextEngine,
  family : String,
) -> Bool {
  let normalized = family.to_lower()
  self.font_list().any(font => font.to_lower() == normalized)
}

///|
fn check_native_status(status : NativeStatus) -> Unit raise TextError {
  let code = native_status_code(status)
  if code != 0 {
    raise Native(
      status=code,
      message=@utf8.decode_lossy(native_status_message(status)),
    )
  }
}

///|
pub fn PangoTextEngine::render_text(
  self : PangoTextEngine,
  spec : TextSpec,
) -> RenderedText raise TextError {
  validate_style(spec.style)
  validate_layout(spec.layout)
  let index_map = prepare_plain_text(spec.text, spec.tab_width)
  let job = make_native_job(
    index_map.rendered,
    markup=false,
    spec.style,
    spec.layout,
    spec.disable_ligatures,
  )
  for span in spec.spans {
    apply_span(job, index_map, span)
  }
  lower_native_render(
    native_job_render(self.native, job),
    index_map,
    expected_native_text=Some(index_map.rendered),
  )
}

///|
pub fn PangoTextEngine::render_markup(
  self : PangoTextEngine,
  spec : MarkupTextSpec,
) -> RenderedText raise TextError {
  validate_style(spec.style)
  validate_layout(spec.layout)
  let expanded_markup = prepare_plain_text(spec.markup, spec.tab_width).rendered
  let job = make_native_job(
    expanded_markup,
    markup=true,
    spec.style,
    spec.layout,
    spec.disable_ligatures,
  )
  let native = native_job_render(self.native, job)
  check_render_status(native)
  let plain_text = @utf8.decode_lossy(native_render_text(native))
  lower_native_render(
    native,
    prepare_identity_text(plain_text),
    expected_native_text=None,
  )
}

///|
pub fn render_text(spec : TextSpec) -> RenderedText raise TextError {
  PangoTextEngine::new().render_text(spec)
}

///|
pub fn render_markup(spec : MarkupTextSpec) -> RenderedText raise TextError {
  PangoTextEngine::new().render_markup(spec)
}

///|
fn make_native_job(
  source : String,
  markup~ : Bool,
  style : TextStyle,
  layout : TextLayout,
  disable_ligatures : Bool,
) -> NativeJob raise TextError {
  let features = combined_font_features(style.font_features, disable_ligatures)
  let job = native_job_new(@utf8.encode(source), markup)
  native_job_set_font(
    job,
    @utf8.encode(style.font_family),
    style.font_size / manim_text_adjustment,
    slant_code(style.slant),
    weight_code(style.weight),
    stretch_code(style.stretch),
  )
  native_job_set_paint(
    job,
    style.color.r,
    style.color.g,
    style.color.b,
    style.color.a,
  )
  native_job_set_base_language(job, @utf8.encode(style.language.unwrap_or("")))
  native_job_set_base_features(job, @utf8.encode(features))
  configure_native_layout(job, layout)
  job
}

///|
fn combined_font_features(
  features : String,
  disable_ligatures : Bool,
) -> String {
  if !disable_ligatures {
    features
  } else if features == "" {
    "liga=0,dlig=0,clig=0,hlig=0"
  } else {
    "\{features},liga=0,dlig=0,clig=0,hlig=0"
  }
}

///|
fn configure_native_layout(
  job : NativeJob,
  layout : TextLayout,
) -> Unit raise TextError {
  let (has_width, width) = layout.width.map_or((false, 0.0), width => {
    (true, width)
  })
  let (height_mode, height) = match (layout.height, layout.max_lines) {
    (Some(_), Some(_)) =>
      raise InvalidLayout("height and max_lines cannot both be set")
    (Some(height), None) => (1, height)
    (None, Some(lines)) => (2, Double::from_int(lines))
    (None, None) => (0, 0.0)
  }
  let (has_line_spacing, line_spacing) = layout.line_spacing.map_or(
    (false, 0.0),
    spacing => (true, spacing),
  )
  native_job_set_box(job, has_width, width, height_mode, height, layout.dpi)
  native_job_set_flow(
    job,
    wrap_code(layout.wrap),
    ellipsize_code(layout.ellipsize),
    alignment_code(layout.alignment),
    layout.auto_dir,
    direction_code(layout.direction),
    layout.single_paragraph,
  )
  native_job_set_paragraph(
    job,
    layout.justify,
    layout.justify_last_line,
    layout.indent,
    layout.spacing,
    has_line_spacing,
    line_spacing,
  )
}

///|
fn apply_span(
  job : NativeJob,
  index_map : TextIndexMap,
  span : TextSpan,
) -> Unit raise TextError {
  validate_span(span)
  let (start, end) = index_map.span_bytes(span.start, span.end)
  match span.font_family {
    Some(family) => native_job_add_family(job, start, end, @utf8.encode(family))
    None => ()
  }
  match span.font_size {
    Some(size) =>
      native_job_add_size(job, start, end, size / manim_text_adjustment)
    None => ()
  }
  match span.slant {
    Some(slant) => native_job_add_slant(job, start, end, slant_code(slant))
    None => ()
  }
  match span.weight {
    Some(weight) => native_job_add_weight(job, start, end, weight_code(weight))
    None => ()
  }
  match span.stretch {
    Some(stretch) =>
      native_job_add_stretch(job, start, end, stretch_code(stretch))
    None => ()
  }
  match span.color {
    Some(color) =>
      native_job_add_foreground(
        job,
        start,
        end,
        color.r,
        color.g,
        color.b,
        color.a,
      )
    None => ()
  }
  match span.background {
    Some(color) =>
      native_job_add_background(
        job,
        start,
        end,
        color.r,
        color.g,
        color.b,
        color.a,
      )
    None => ()
  }
  match span.underline {
    Some(underline) =>
      native_job_add_underline(job, start, end, underline_code(underline))
    None => ()
  }
  match span.underline_color {
    Some(color) =>
      native_job_add_underline_color(job, start, end, color.r, color.g, color.b)
    None => ()
  }
  match span.overline {
    Some(enabled) => native_job_add_overline(job, start, end, enabled)
    None => ()
  }
  match span.overline_color {
    Some(color) =>
      native_job_add_overline_color(job, start, end, color.r, color.g, color.b)
    None => ()
  }
  match span.strikethrough {
    Some(enabled) => native_job_add_strikethrough(job, start, end, enabled)
    None => ()
  }
  match span.strikethrough_color {
    Some(color) =>
      native_job_add_strikethrough_color(
        job,
        start,
        end,
        color.r,
        color.g,
        color.b,
      )
    None => ()
  }
  match span.rise {
    Some(rise) => native_job_add_rise(job, start, end, rise)
    None => ()
  }
  match span.letter_spacing {
    Some(spacing) => native_job_add_letter_spacing(job, start, end, spacing)
    None => ()
  }
  match span.font_features {
    Some(features) =>
      native_job_add_font_features(job, start, end, @utf8.encode(features))
    None => ()
  }
  match span.language {
    Some(language) =>
      native_job_add_language(job, start, end, @utf8.encode(language))
    None => ()
  }
}

///|
fn lower_native_render(
  native : NativeRender,
  index_map : TextIndexMap,
  expected_native_text~ : String?,
) -> RenderedText raise TextError {
  check_render_status(native)
  let native_text = @utf8.decode_lossy(native_render_text(native))
  match expected_native_text {
    Some(expected) if native_text != expected =>
      raise Native(
        status=4,
        message="Pango changed the plain text unexpectedly",
      )
    _ => ()
  }
  let svg_source = @utf8.decode_lossy(native_render_svg(native))
  let svg = @svg.SvgObject::parse_string(svg_source, center=false) catch {
    error => raise SvgParse(error)
  }
  let svg_object = svg.object()
  let metrics = read_metrics(native)
  let clusters = read_clusters(native, index_map, svg, svg_object)
  clusters.sort_by((left, right) => {
    if left.range.start != right.range.start {
      left.range.start - right.range.start
    } else {
      left.range.end - right.range.end
    }
  })
  {
    source: index_map.source,
    character_count: index_map.source_character_count,
    svg,
    clusters,
    lines: read_lines(native, index_map),
    metrics,
  }
}

///|
fn family_path_has_geometry(
  object : @object.Object,
  path : @object.FamilyPath,
) -> Bool {
  object_at_family_indices(object, path.indices(), 0)
  .bind(child => child.bounds())
  .map_or(false, bounds => bounds.width() != 0.0 || bounds.height() != 0.0)
}

///|
fn object_at_family_indices(
  object : @object.Object,
  indices : Array[Int],
  depth : Int,
) -> @object.Object? {
  if depth == indices.length() {
    return Some(object)
  }
  match object.node {
    Group(children) =>
      children
      .get(indices[depth])
      .bind(child => object_at_family_indices(child, indices, depth + 1))
    _ => None
  }
}

///|
fn check_render_status(native : NativeRender) -> Unit raise TextError {
  let status = native_render_status(native)
  if status != 0 {
    let message = @utf8.decode_lossy(native_render_message(native))
    if status == 2 {
      raise InvalidMarkup(message)
    }
    raise Native(status~, message~)
  }
}

///|
fn read_metrics(native : NativeRender) -> PangoTextMetrics {
  let ink_x = Ref(0.0)
  let ink_y = Ref(0.0)
  let ink_width = Ref(0.0)
  let ink_height = Ref(0.0)
  let logical_x = Ref(0.0)
  let logical_y = Ref(0.0)
  let logical_width = Ref(0.0)
  let logical_height = Ref(0.0)
  let baseline = Ref(0.0)
  let unknown_glyphs = Ref(0)
  let glyph_count = Ref(0)
  let line_count = Ref(0)
  native_render_metrics(
    native, ink_x, ink_y, ink_width, ink_height, logical_x, logical_y, logical_width,
    logical_height, baseline, unknown_glyphs, glyph_count, line_count,
  )
  {
    ink: {
      x: ink_x.val,
      y: ink_y.val,
      width: ink_width.val,
      height: ink_height.val,
    },
    logical: {
      x: logical_x.val,
      y: logical_y.val,
      width: logical_width.val,
      height: logical_height.val,
    },
    baseline: baseline.val,
    unknown_glyphs: unknown_glyphs.val,
    glyph_count: glyph_count.val,
    line_count: line_count.val,
  }
}

///|
fn read_clusters(
  native : NativeRender,
  index_map : TextIndexMap,
  svg : @svg.SvgObject,
  svg_object : @object.Object,
) -> Array[TextCluster] raise TextError {
  let clusters : Array[TextCluster] = []
  for index in 0..<native_render_cluster_count(native) {
    let source_start = Ref(0)
    let source_end = Ref(0)
    let glyph_start = Ref(0)
    let glyph_end = Ref(0)
    let line_index = Ref(0)
    let bidi_level = Ref(0)
    let x = Ref(0.0)
    let y = Ref(0.0)
    let width = Ref(0.0)
    let height = Ref(0.0)
    let present = native_render_cluster(
      native, index, source_start, source_end, glyph_start, glyph_end, line_index,
      bidi_level, x, y, width, height,
    )
    if !present {
      raise Native(status=4, message="missing Pango cluster record")
    }
    let paths = svg
      .group_paths("motiva-cluster-\{index}")
      .filter(path => family_path_has_geometry(svg_object, path))
    clusters.push({
      range: index_map.source_range(source_start.val, source_end.val),
      glyphs: { start: glyph_start.val, end: glyph_end.val },
      line_index: line_index.val,
      bidi_level: bidi_level.val,
      pango_logical_bounds: {
        x: x.val,
        y: y.val,
        width: width.val,
        height: height.val,
      },
      paths,
    })
  }
  clusters
}

///|
fn read_lines(
  native : NativeRender,
  index_map : TextIndexMap,
) -> Array[PangoTextLine] raise TextError {
  let lines : Array[PangoTextLine] = []
  for index in 0..<native_render_line_count(native) {
    let source_start = Ref(0)
    let source_end = Ref(0)
    let ink_x = Ref(0.0)
    let ink_y = Ref(0.0)
    let ink_width = Ref(0.0)
    let ink_height = Ref(0.0)
    let logical_x = Ref(0.0)
    let logical_y = Ref(0.0)
    let logical_width = Ref(0.0)
    let logical_height = Ref(0.0)
    let baseline = Ref(0.0)
    let present = native_render_line(
      native, index, source_start, source_end, ink_x, ink_y, ink_width, ink_height,
      logical_x, logical_y, logical_width, logical_height, baseline,
    )
    if !present {
      raise Native(status=4, message="missing Pango line record")
    }
    lines.push({
      range: index_map.source_range(source_start.val, source_end.val),
      pango_ink: {
        x: ink_x.val,
        y: ink_y.val,
        width: ink_width.val,
        height: ink_height.val,
      },
      pango_logical: {
        x: logical_x.val,
        y: logical_y.val,
        width: logical_width.val,
        height: logical_height.val,
      },
      pango_baseline: baseline.val,
    })
  }
  lines
}

///|
fn validate_style(style : TextStyle) -> Unit raise TextError {
  validate_font_size(style.font_size)
  validate_color(style.color, "text color")
}

///|
fn validate_font_size(size : Double) -> Unit raise TextError {
  if size <= 0.0 ||
    size.is_nan() ||
    size.is_inf() ||
    size / manim_text_adjustment > max_pango_value {
    raise InvalidFontSize(size)
  }
}

///|
fn validate_span(span : TextSpan) -> Unit raise TextError {
  match span.font_size {
    Some(size) => validate_font_size(size)
    None => ()
  }
  for
    entry in [
      ("foreground", span.color),
      ("background", span.background),
      ("underline", span.underline_color),
      ("overline", span.overline_color),
      ("strikethrough", span.strikethrough_color),
    ] {
    let (name, color) = entry
    match color {
      Some(color) => validate_color(color, name)
      None => ()
    }
  }
  match span.rise {
    Some(value) => validate_pango_value(value, "rise")
    None => ()
  }
  match span.letter_spacing {
    Some(value) => validate_pango_value(value, "letter_spacing")
    None => ()
  }
}

///|
fn validate_color(color : @object.Rgba, name : String) -> Unit raise TextError {
  for channel in [color.r, color.g, color.b, color.a] {
    if channel < 0.0 || channel > 1.0 || channel.is_nan() || channel.is_inf() {
      raise InvalidColor(
        "\{name} channels must be finite and between zero and one",
      )
    }
  }
}

///|
fn validate_pango_value(value : Double, name : String) -> Unit raise TextError {
  if value.is_nan() || value.is_inf() || Double::abs(value) > max_pango_value {
    raise InvalidLayout("\{name} exceeds the finite Pango unit range")
  }
}

///|
fn validate_layout(layout : TextLayout) -> Unit raise TextError {
  if layout.dpi <= 0.0 ||
    layout.dpi > 1000000.0 ||
    layout.dpi.is_nan() ||
    layout.dpi.is_inf() {
    raise InvalidDpi(layout.dpi)
  }
  match layout.width {
    Some(width) if width < 0.0 =>
      raise InvalidLayout("width must be non-negative")
    Some(width) => validate_pango_value(width, "width")
    _ => ()
  }
  match layout.height {
    Some(height) if height < 0.0 =>
      raise InvalidLayout("height must be non-negative")
    Some(height) => validate_pango_value(height, "height")
    _ => ()
  }
  match layout.max_lines {
    Some(lines) if lines <= 0 =>
      raise InvalidLayout("max_lines must be greater than zero")
    _ => ()
  }
  match layout.line_spacing {
    Some(spacing) if spacing < 0.0 ||
      spacing > 1000000.0 ||
      spacing.is_nan() ||
      spacing.is_inf() =>
      raise InvalidLayout("line_spacing must be finite and non-negative")
    _ => ()
  }
  validate_pango_value(layout.indent, "indent")
  validate_pango_value(layout.spacing, "spacing")
}

///|
fn slant_code(slant : FontSlant) -> Int {
  match slant {
    NormalSlant => 0
    Oblique => 1
    Italic => 2
  }
}

///|
fn weight_code(weight : FontWeight) -> Int {
  match weight {
    Thin => 100
    UltraLight => 200
    Light => 300
    SemiLight => 350
    Book => 380
    NormalWeight => 400
    Medium => 500
    SemiBold => 600
    Bold => 700
    UltraBold => 800
    Heavy => 900
    UltraHeavy => 1000
  }
}

///|
fn stretch_code(stretch : FontStretch) -> Int {
  match stretch {
    UltraCondensed => 0
    ExtraCondensed => 1
    Condensed => 2
    SemiCondensed => 3
    NormalStretch => 4
    SemiExpanded => 5
    Expanded => 6
    ExtraExpanded => 7
    UltraExpanded => 8
  }
}

///|
fn alignment_code(alignment : TextAlignment) -> Int {
  match alignment {
    AlignLeft => 0
    AlignCenter => 1
    AlignRight => 2
  }
}

///|
fn wrap_code(wrap : TextWrap) -> Int {
  match wrap {
    WrapWord => 0
    WrapChar => 1
    WrapWordChar => 2
    NoWrap => 3
  }
}

///|
fn ellipsize_code(ellipsize : TextEllipsize) -> Int {
  match ellipsize {
    NoEllipsize => 0
    EllipsizeStart => 1
    EllipsizeMiddle => 2
    EllipsizeEnd => 3
  }
}

///|
fn direction_code(direction : TextDirection) -> Int {
  match direction {
    AutoDirection => -1
    LeftToRight => 0
    RightToLeft => 1
  }
}

///|
fn underline_code(underline : TextUnderline) -> Int {
  match underline {
    NoUnderline => 0
    SingleUnderline => 1
    DoubleUnderline => 2
    LowUnderline => 3
    ErrorUnderline => 4
  }
}
