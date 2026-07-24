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
  priv mut font_map : @pangocairo.FontMap
  priv font_files : Array[String]
}

///|
priv struct PangoRenderAttributes(@pango.AttrList)

///|
priv struct SvgGeometryIndex {
  object : @object.Object
}

///|
pub fn PangoTextEngine::new() -> PangoTextEngine {
  { font_map: @pangocairo.FontMap::new(), font_files: [] }
}

///|
pub impl Default for PangoTextEngine with fn default() {
  PangoTextEngine::new()
}

///|
pub fn pango_version() -> String {
  @pango.version_string()
}

///|
pub fn cairo_version() -> String {
  @cairoon.cairo_version_string()
}

///|
pub fn PangoTextEngine::register_font(
  self : PangoTextEngine,
  path : String,
) -> FontRegistration raise TextError {
  if path == "" {
    raise Native(status=1, message="empty font path")
  }
  if self.font_files.contains(path) {
    return { path, }
  }
  let added = self.font_map.as_pango_font_map().add_font_file(path) catch {
      error => raise Native(status=5, message=error.message())
    }
  if !added {
    raise Native(status=5, message="failed to register font")
  }
  self.font_map.as_pango_font_map().changed()
  self.font_files.push(path)
  { path, }
}

///|
pub fn PangoTextEngine::unregister_font(
  self : PangoTextEngine,
  registration : FontRegistration,
) -> Unit raise TextError {
  let mut removed_index = -1
  for index, path in self.font_files {
    if path == registration.path {
      removed_index = index
      break
    }
  }
  if removed_index < 0 {
    raise Native(
      status=7,
      message="font is not registered with this text engine",
    )
  }
  let replacement = @pangocairo.FontMap::new()
  for index, path in self.font_files {
    if index != removed_index {
      let added = replacement.as_pango_font_map().add_font_file(path) catch {
          error => raise Native(status=5, message=error.message())
        }
      if !added {
        raise Native(status=5, message="failed to rebuild font map")
      }
    }
  }
  self.font_map = replacement
  ignore(self.font_files.remove(removed_index))
}

///|
pub fn PangoTextEngine::font_list(self : PangoTextEngine) -> Array[String] {
  let names = self.font_map
    .as_pango_font_map()
    .list_families()
    .map(family => family.get_name())
  names.sort()
  names
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
pub fn PangoTextEngine::render_text(
  self : PangoTextEngine,
  spec : TextSpec,
) -> RenderedText raise TextError {
  spec.style.validate()
  spec.layout.validate()
  let index_map = prepare_plain_text(spec.text, spec.tab_width)
  let attributes = PangoRenderAttributes(@pango.AttrList::new())
  attributes.apply_base_features(
    combined_font_features(spec.style.font_features, spec.disable_ligatures),
  )
  for span in spec.spans {
    span.validate()
    let (start, end) = index_map.span_bytes(span.start, span.end)
    attributes.apply_span(span, start, end)
  }
  self.render_configured(
    index_map.rendered,
    spec.style,
    spec.layout,
    attributes,
    index_map,
    expected_native_text=Some(index_map.rendered),
  )
}

///|
pub fn PangoTextEngine::render_markup(
  self : PangoTextEngine,
  spec : MarkupTextSpec,
) -> RenderedText raise TextError {
  spec.style.validate()
  spec.layout.validate()
  let expanded_markup = prepare_plain_text(spec.markup, spec.tab_width).rendered
  let (parsed_attributes, plain_text, _) = @pango.parse_markup(
    expanded_markup, -1, 0,
  ) catch {
    error => raise InvalidMarkup(error.message())
  }
  let attributes = PangoRenderAttributes(parsed_attributes)
  attributes.apply_base_features(
    combined_font_features(spec.style.font_features, spec.disable_ligatures),
  )
  self.render_configured(
    plain_text,
    spec.style,
    spec.layout,
    attributes,
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
fn PangoRenderAttributes::change_range(
  self : PangoRenderAttributes,
  attribute : @pango.Attribute,
  start : Int,
  end : Int,
) -> Unit {
  attribute.set_start_index(start.reinterpret_as_uint())
  attribute.set_end_index(end.reinterpret_as_uint())
  self.0.change(attribute)
}

///|
fn PangoRenderAttributes::change_full(
  self : PangoRenderAttributes,
  attribute : @pango.Attribute,
) -> Unit {
  attribute.set_start_index(@pango.ATTR_INDEX_FROM_TEXT_BEGINNING)
  attribute.set_end_index(@pango.ATTR_INDEX_TO_TEXT_END)
  self.0.change(attribute)
}

///|
fn PangoRenderAttributes::color_channel(
  self : PangoRenderAttributes,
  value : Double,
) -> UInt {
  ignore(self)
  (value.clamp(min=0.0, max=1.0) * 65535.0).round().to_uint()
}

///|
fn PangoRenderAttributes::apply_base_features(
  self : PangoRenderAttributes,
  features : String,
) -> Unit {
  if features != "" {
    self.change_full(@pango.AttrFontFeatures::new(features))
  }
}

///|
fn PangoRenderAttributes::apply_span(
  self : PangoRenderAttributes,
  span : TextSpan,
  start : Int,
  end : Int,
) -> Unit {
  if span.font_family is Some(family) {
    self.change_range(@pango.attr_family_new(family), start, end)
  }
  if span.font_size is Some(size) {
    self.change_range(
      @pango.AttrSize::new(
        @pango.units_from_double(size / manim_text_adjustment),
      ),
      start,
      end,
    )
  }
  if span.slant is Some(slant) {
    self.change_range(@pango.attr_style_new(slant.to_pango()), start, end)
  }
  if span.weight is Some(weight) {
    self.change_range(@pango.attr_weight_new(weight.to_pango()), start, end)
  }
  if span.stretch is Some(stretch) {
    self.change_range(@pango.attr_stretch_new(stretch.to_pango()), start, end)
  }
  if span.color is Some(color) {
    self.change_range(
      @pango.attr_foreground_new(
        self.color_channel(color.r),
        self.color_channel(color.g),
        self.color_channel(color.b),
      ),
      start,
      end,
    )
    self.change_range(
      @pango.attr_foreground_alpha_new(self.color_channel(color.a)),
      start,
      end,
    )
  }
  if span.background is Some(color) {
    self.change_range(
      @pango.attr_background_new(
        self.color_channel(color.r),
        self.color_channel(color.g),
        self.color_channel(color.b),
      ),
      start,
      end,
    )
    self.change_range(
      @pango.attr_background_alpha_new(self.color_channel(color.a)),
      start,
      end,
    )
  }
  if span.underline is Some(underline) {
    self.change_range(
      @pango.attr_underline_new(underline.to_pango()),
      start,
      end,
    )
  }
  if span.underline_color is Some(color) {
    self.change_range(
      @pango.attr_underline_color_new(
        self.color_channel(color.r),
        self.color_channel(color.g),
        self.color_channel(color.b),
      ),
      start,
      end,
    )
  }
  if span.overline is Some(enabled) {
    self.change_range(
      @pango.attr_overline_new(
        if enabled {
          @pango.Overline::Single
        } else {
          @pango.Overline::None
        },
      ),
      start,
      end,
    )
  }
  if span.overline_color is Some(color) {
    self.change_range(
      @pango.attr_overline_color_new(
        self.color_channel(color.r),
        self.color_channel(color.g),
        self.color_channel(color.b),
      ),
      start,
      end,
    )
  }
  if span.strikethrough is Some(enabled) {
    self.change_range(@pango.attr_strikethrough_new(enabled), start, end)
  }
  if span.strikethrough_color is Some(color) {
    self.change_range(
      @pango.attr_strikethrough_color_new(
        self.color_channel(color.r),
        self.color_channel(color.g),
        self.color_channel(color.b),
      ),
      start,
      end,
    )
  }
  if span.rise is Some(rise) {
    self.change_range(
      @pango.attr_rise_new(@pango.units_from_double(rise)),
      start,
      end,
    )
  }
  if span.letter_spacing is Some(spacing) {
    self.change_range(
      @pango.attr_letter_spacing_new(@pango.units_from_double(spacing)),
      start,
      end,
    )
  }
  if span.font_features is Some(features) {
    self.change_range(@pango.AttrFontFeatures::new(features), start, end)
  }
  if span.language is Some(language) &&
    @pango.Language::from_string(Some(language)) is Some(language) {
    self.change_range(@pango.AttrLanguage::new(language), start, end)
  }
}

///|
fn PangoTextEngine::build_layout(
  self : PangoTextEngine,
  source : String,
  style : TextStyle,
  layout_options : TextLayout,
  attributes : PangoRenderAttributes,
  cairo : @cairo.Context,
) -> @pango.Layout {
  let context = self.font_map.as_pango_font_map().create_context()
  @pangocairo.context_set_resolution(context, layout_options.dpi)
  context.set_base_dir(layout_options.direction.to_pango())
  if style.language is Some(language) &&
    @pango.Language::from_string(Some(language)) is Some(language) {
    context.set_language(Some(language))
  }
  @pangocairo.update_context(cairo, context)
  let layout = @pango.Layout::new(context)
  let description = @pango.FontDescription::new()
  if style.font_family != "" {
    description.set_family(style.font_family)
  }
  description.set_size(
    @pango.units_from_double(style.font_size / manim_text_adjustment),
  )
  description.set_style(style.slant.to_pango())
  description.set_weight(style.weight.to_pango())
  description.set_stretch(style.stretch.to_pango())
  layout.set_font_description(Some(description))
  layout.set_text(source, -1)
  layout.set_attributes(Some(attributes.0))
  if layout_options.width is Some(width) {
    layout.set_width(@pango.units_from_double(width))
  }
  if layout_options.height is Some(height) {
    layout.set_height(@pango.units_from_double(height))
  } else if layout_options.max_lines is Some(lines) {
    layout.set_height(0 - lines)
  }
  layout.set_wrap(layout_options.wrap.to_pango())
  layout.set_ellipsize(layout_options.ellipsize.to_pango())
  layout.set_alignment(layout_options.alignment.to_pango())
  layout.set_justify(layout_options.justify)
  layout.set_justify_last_line(layout_options.justify_last_line)
  layout.set_indent(@pango.units_from_double(layout_options.indent))
  layout.set_spacing(@pango.units_from_double(layout_options.spacing))
  if layout_options.line_spacing is Some(spacing) {
    layout.set_line_spacing(Float::from_double(spacing))
  }
  layout.set_auto_dir(layout_options.auto_dir)
  layout.set_single_paragraph_mode(layout_options.single_paragraph)
  @pangocairo.update_layout(cairo, layout)
  layout
}

///|
fn @pango.Rectangle::to_motiva_rect(self : @pango.Rectangle) -> PangoRect {
  {
    x: @pango.units_to_double(self.get_x()),
    y: @pango.units_to_double(self.get_y()),
    width: @pango.units_to_double(self.get_width()),
    height: @pango.units_to_double(self.get_height()),
  }
}

///|
fn @pango.Layout::motiva_lines(
  self : @pango.Layout,
  index_map : TextIndexMap,
) -> Array[PangoTextLine] raise TextError {
  let lines : Array[PangoTextLine] = []
  let iterator = self.get_iter()
  let mut more = true
  while more {
    if iterator.get_line_readonly() is Some(line) {
      let (ink, logical) = iterator.get_line_extents()
      lines.push({
        range: index_map.source_range(
          line.get_start_index(),
          line.get_start_index() + line.get_length(),
        ),
        pango_ink: ink.to_motiva_rect(),
        pango_logical: logical.to_motiva_rect(),
        pango_baseline: @pango.units_to_double(iterator.get_baseline()),
      })
    }
    more = iterator.next_line()
  }
  lines
}

///|
fn SvgGeometryIndex::object_at(
  self : SvgGeometryIndex,
  object : @object.Object,
  indices : Array[Int],
  depth : Int,
) -> @object.Object? {
  ignore(self)
  if depth == indices.length() {
    return Some(object)
  }
  match object.node {
    Group(children) =>
      children
      .get(indices[depth])
      .bind(child => self.object_at(child, indices, depth + 1))
    _ => None
  }
}

///|
fn SvgGeometryIndex::has_geometry(
  self : SvgGeometryIndex,
  path : @object.FamilyPath,
) -> Bool {
  self
  .object_at(self.object, path.indices(), 0)
  .bind(child => child.bounds())
  .map_or(false, bounds => bounds.width() != 0.0 || bounds.height() != 0.0)
}

///|
fn @renderer.RendererOutput::motiva_clusters(
  self : @renderer.RendererOutput,
  index_map : TextIndexMap,
  svg : @svg.SvgObject,
  svg_object : @object.Object,
) -> Array[TextCluster] raise TextError {
  let geometry = SvgGeometryIndex::{ object: svg_object }
  let clusters = [
    for index, cluster in self.clusters => {
      {
        range: index_map.source_range(cluster.source_start, cluster.source_end),
        glyphs: { start: cluster.glyph_start, end: cluster.glyph_end },
        line_index: cluster.line_index,
        bidi_level: cluster.bidi_level,
        pango_logical_bounds: {
          x: cluster.x,
          y: cluster.y,
          width: cluster.width,
          height: cluster.height,
        },
        paths: svg
        .group_paths("motiva-cluster-\{index}")
        .filter(path => geometry.has_geometry(path)),
      }
    }
  ]
  clusters.sort_by((left, right) => {
    if left.range.start != right.range.start {
      left.range.start - right.range.start
    } else {
      left.range.end - right.range.end
    }
  })
  clusters
}

///|
fn PangoTextEngine::render_configured(
  self : PangoTextEngine,
  source : String,
  style : TextStyle,
  layout_options : TextLayout,
  attributes : PangoRenderAttributes,
  index_map : TextIndexMap,
  expected_native_text~ : String?,
) -> RenderedText raise TextError {
  let surface = @cairo.Surface::create_recording(@cairo.Content::ColorAlpha)
  let cairo = @cairo.Context::create(surface)
  if !surface.status().is_success() {
    let status = surface.status()
    raise Native(status=status.to_int(), message=status.to_string())
  }
  if !cairo.status().is_success() {
    let status = cairo.status()
    raise Native(status=status.to_int(), message=status.to_string())
  }
  let layout = self.build_layout(
    source, style, layout_options, attributes, cairo,
  )
  let native_text = layout.get_text()
  if expected_native_text is Some(expected) && native_text != expected {
    raise Native(status=4, message="Pango changed the plain text unexpectedly")
  }
  let (ink, logical) = layout.get_extents()
  let ink = ink.to_motiva_rect()
  let logical = logical.to_motiva_rect()
  let metrics : PangoTextMetrics = {
    ink,
    logical,
    baseline: @pango.units_to_double(layout.get_baseline()),
    unknown_glyphs: layout.get_unknown_glyphs_count(),
    glyph_count: 0,
    line_count: layout.get_line_count(),
  }
  let min_x = Double::min(ink.x, logical.x)
  let min_y = Double::min(ink.y, logical.y)
  let max_x = Double::max(ink.x + ink.width, logical.x + logical.width)
  let max_y = Double::max(ink.y + ink.height, logical.y + logical.height)
  let padding = 1.0
  let surface_width = Double::max(1.0, max_x - min_x + 2.0 * padding).ceil()
  let surface_height = Double::max(1.0, max_y - min_y + 2.0 * padding).ceil()
  let output = @renderer.render(
    layout,
    cairo,
    surface_width,
    surface_height,
    padding - min_x,
    padding - min_y,
    style.color.r,
    style.color.g,
    style.color.b,
    style.color.a,
  ) catch {
    @renderer.RendererFailed(message) => raise Native(status=3, message~)
  }
  let svg = @svg.SvgObject::parse_string(output.svg, center=false) catch {
    error => raise SvgParse(error)
  }
  let svg_object = svg.object()
  {
    source: index_map.source,
    character_count: index_map.source_character_count,
    svg,
    clusters: output.motiva_clusters(index_map, svg, svg_object),
    lines: layout.motiva_lines(index_map),
    metrics: { ..metrics, glyph_count: output.glyph_count },
  }
}

///|
fn TextStyle::validate(self : TextStyle) -> Unit raise TextError {
  TextStyle::validate_font_size(self.font_size)
  self.color.validate_text_color("text color")
}

///|
fn TextStyle::validate_font_size(size : Double) -> Unit raise TextError {
  if size <= 0.0 ||
    size.is_nan() ||
    size.is_inf() ||
    size / manim_text_adjustment > max_pango_value {
    raise InvalidFontSize(size)
  }
}

///|
fn TextSpan::validate(self : TextSpan) -> Unit raise TextError {
  if self.font_size is Some(size) {
    TextStyle::validate_font_size(size)
  }
  for
    entry in [
      ("foreground", self.color),
      ("background", self.background),
      ("underline", self.underline_color),
      ("overline", self.overline_color),
      ("strikethrough", self.strikethrough_color),
    ] {
    let (name, color) = entry
    if color is Some(color) {
      color.validate_text_color(name)
    }
  }
  if self.rise is Some(value) {
    TextLayout::validate_pango_value(value, "rise")
  }
  if self.letter_spacing is Some(value) {
    TextLayout::validate_pango_value(value, "letter_spacing")
  }
}

///|
fn @object.Rgba::validate_text_color(
  self : @object.Rgba,
  name : String,
) -> Unit raise TextError {
  for channel in [self.r, self.g, self.b, self.a] {
    if channel < 0.0 || channel > 1.0 || channel.is_nan() || channel.is_inf() {
      raise InvalidColor(
        "\{name} channels must be finite and between zero and one",
      )
    }
  }
}

///|
fn TextLayout::validate_pango_value(
  value : Double,
  name : String,
) -> Unit raise TextError {
  if value.is_nan() || value.is_inf() || Double::abs(value) > max_pango_value {
    raise InvalidLayout("\{name} exceeds the finite Pango unit range")
  }
}

///|
fn TextLayout::validate(self : TextLayout) -> Unit raise TextError {
  if self.dpi <= 0.0 ||
    self.dpi > 1000000.0 ||
    self.dpi.is_nan() ||
    self.dpi.is_inf() {
    raise InvalidDpi(self.dpi)
  }
  if self.width is Some(width) {
    if width < 0.0 {
      raise InvalidLayout("width must be non-negative")
    }
    TextLayout::validate_pango_value(width, "width")
  }
  if self.height is Some(height) {
    if height < 0.0 {
      raise InvalidLayout("height must be non-negative")
    }
    TextLayout::validate_pango_value(height, "height")
  }
  if self.max_lines is Some(lines) && lines <= 0 {
    raise InvalidLayout("max_lines must be greater than zero")
  }
  if self.line_spacing is Some(spacing) &&
    (
      spacing < 0.0 ||
      spacing > 1000000.0 ||
      spacing.is_nan() ||
      spacing.is_inf()
    ) {
    raise InvalidLayout("line_spacing must be finite and non-negative")
  }
  TextLayout::validate_pango_value(self.indent, "indent")
  TextLayout::validate_pango_value(self.spacing, "spacing")
}

///|
fn FontSlant::to_pango(self : FontSlant) -> @pango.Style {
  match self {
    NormalSlant => @pango.Style::Normal
    Oblique => @pango.Style::Oblique
    Italic => @pango.Style::Italic
  }
}

///|
fn FontWeight::to_pango(self : FontWeight) -> @pango.Weight {
  match self {
    Thin => @pango.Weight::Thin
    UltraLight => @pango.Weight::Ultralight
    Light => @pango.Weight::Light
    SemiLight => @pango.Weight::Semilight
    Book => @pango.Weight::Book
    NormalWeight => @pango.Weight::Normal
    Medium => @pango.Weight::Medium
    SemiBold => @pango.Weight::Semibold
    Bold => @pango.Weight::Bold
    UltraBold => @pango.Weight::Ultrabold
    Heavy => @pango.Weight::Heavy
    UltraHeavy => @pango.Weight::Ultraheavy
  }
}

///|
fn FontStretch::to_pango(self : FontStretch) -> @pango.Stretch {
  match self {
    UltraCondensed => @pango.Stretch::UltraCondensed
    ExtraCondensed => @pango.Stretch::ExtraCondensed
    Condensed => @pango.Stretch::Condensed
    SemiCondensed => @pango.Stretch::SemiCondensed
    NormalStretch => @pango.Stretch::Normal
    SemiExpanded => @pango.Stretch::SemiExpanded
    Expanded => @pango.Stretch::Expanded
    ExtraExpanded => @pango.Stretch::ExtraExpanded
    UltraExpanded => @pango.Stretch::UltraExpanded
  }
}

///|
fn TextAlignment::to_pango(self : TextAlignment) -> @pango.Alignment {
  match self {
    AlignLeft => @pango.Alignment::Left
    AlignCenter => @pango.Alignment::Center
    AlignRight => @pango.Alignment::Right
  }
}

///|
fn TextWrap::to_pango(self : TextWrap) -> @pango.WrapMode {
  match self {
    WrapWord => @pango.WrapMode::Word
    WrapChar => @pango.WrapMode::Char
    WrapWordChar => @pango.WrapMode::WordChar
    NoWrap => @pango.WrapMode::None
  }
}

///|
fn TextEllipsize::to_pango(self : TextEllipsize) -> @pango.EllipsizeMode {
  match self {
    NoEllipsize => @pango.EllipsizeMode::None
    EllipsizeStart => @pango.EllipsizeMode::Start
    EllipsizeMiddle => @pango.EllipsizeMode::Middle
    EllipsizeEnd => @pango.EllipsizeMode::End
  }
}

///|
fn TextDirection::to_pango(self : TextDirection) -> @pango.Direction {
  match self {
    AutoDirection => @pango.Direction::WeakLtr
    LeftToRight => @pango.Direction::Ltr
    RightToLeft => @pango.Direction::Rtl
  }
}

///|
fn TextUnderline::to_pango(self : TextUnderline) -> @pango.Underline {
  match self {
    NoUnderline => @pango.Underline::None
    SingleUnderline => @pango.Underline::Single
    DoubleUnderline => @pango.Underline::Double
    LowUnderline => @pango.Underline::Low
    ErrorUnderline => @pango.Underline::Error
  }
}
