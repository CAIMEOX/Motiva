///|
pub(all) suberror TextError {
  InvalidFontSize(Double)
  InvalidDpi(Double)
  InvalidTabWidth(Int)
  InvalidSpan(start~ : Int, end~ : Int, character_count~ : Int)
  EmptyPattern
  InvalidGradient(Int)
  InvalidColor(String)
  InvalidPresentation(String)
  InvalidLayout(String)
  InvalidMarkup(String)
  Native(status~ : Int, message~ : String)
  SvgParse(@svg.SvgError)
}

///|
pub(all) enum FontSlant {
  NormalSlant
  Oblique
  Italic
} derive(Eq, Debug)

///|
pub impl Default for FontSlant with fn default() {
  NormalSlant
}

///|
pub(all) enum FontWeight {
  Thin
  UltraLight
  Light
  SemiLight
  Book
  NormalWeight
  Medium
  SemiBold
  Bold
  UltraBold
  Heavy
  UltraHeavy
} derive(Eq, Debug)

///|
pub impl Default for FontWeight with fn default() {
  NormalWeight
}

///|
pub(all) enum FontStretch {
  UltraCondensed
  ExtraCondensed
  Condensed
  SemiCondensed
  NormalStretch
  SemiExpanded
  Expanded
  ExtraExpanded
  UltraExpanded
} derive(Eq, Debug)

///|
pub impl Default for FontStretch with fn default() {
  NormalStretch
}

///|
pub(all) enum TextAlignment {
  AlignLeft
  AlignCenter
  AlignRight
} derive(Eq, Debug)

///|
pub impl Default for TextAlignment with fn default() {
  AlignLeft
}

///|
pub(all) enum TextWrap {
  WrapWord
  WrapChar
  WrapWordChar
  NoWrap
} derive(Eq, Debug)

///|
pub impl Default for TextWrap with fn default() {
  WrapWord
}

///|
pub(all) enum TextEllipsize {
  NoEllipsize
  EllipsizeStart
  EllipsizeMiddle
  EllipsizeEnd
} derive(Eq, Debug)

///|
pub impl Default for TextEllipsize with fn default() {
  NoEllipsize
}

///|
pub(all) enum TextDirection {
  AutoDirection
  LeftToRight
  RightToLeft
} derive(Eq, Debug)

///|
pub impl Default for TextDirection with fn default() {
  AutoDirection
}

///|
pub(all) enum TextUnderline {
  NoUnderline
  SingleUnderline
  DoubleUnderline
  LowUnderline
  ErrorUnderline
} derive(Eq, Debug)

///|
pub(all) struct TextStyle {
  font_family : String
  font_size : Double
  slant : FontSlant
  weight : FontWeight
  stretch : FontStretch
  color : @object.Rgba
  language : String?
  font_features : String
}

///|
pub fn TextStyle::new(
  font_family? : String = "",
  font_size? : Double = 48.0,
  slant? : FontSlant = FontSlant::default(),
  weight? : FontWeight = FontWeight::default(),
  stretch? : FontStretch = FontStretch::default(),
  color? : @object.Rgba = @object.Rgba::white(),
  language? : String,
  font_features? : String = "",
) -> TextStyle {
  {
    font_family,
    font_size,
    slant,
    weight,
    stretch,
    color,
    language,
    font_features,
  }
}

///|
pub impl Default for TextStyle with fn default() {
  TextStyle::new()
}

///|
pub fn TextStyle::with_color(
  self : TextStyle,
  color : @object.Rgba,
) -> TextStyle {
  { ..self, color, }
}

///|
pub fn TextStyle::with_font(
  self : TextStyle,
  family? : String = self.font_family,
  size? : Double = self.font_size,
  slant? : FontSlant = self.slant,
  weight? : FontWeight = self.weight,
  stretch? : FontStretch = self.stretch,
) -> TextStyle {
  { ..self, font_family: family, font_size: size, slant, weight, stretch }
}

///|
pub(all) struct TextSpan {
  start : Int
  end : Int
  font_family : String?
  font_size : Double?
  slant : FontSlant?
  weight : FontWeight?
  stretch : FontStretch?
  color : @object.Rgba?
  background : @object.Rgba?
  underline : TextUnderline?
  underline_color : @object.Rgba?
  overline : Bool?
  overline_color : @object.Rgba?
  strikethrough : Bool?
  strikethrough_color : @object.Rgba?
  rise : Double?
  letter_spacing : Double?
  font_features : String?
  language : String?
}

///|
pub fn TextSpan::new(
  start : Int,
  end : Int,
  font_family? : String,
  font_size? : Double,
  slant? : FontSlant,
  weight? : FontWeight,
  stretch? : FontStretch,
  color? : @object.Rgba,
  background? : @object.Rgba,
  underline? : TextUnderline,
  underline_color? : @object.Rgba,
  overline? : Bool,
  overline_color? : @object.Rgba,
  strikethrough? : Bool,
  strikethrough_color? : @object.Rgba,
  rise? : Double,
  letter_spacing? : Double,
  font_features? : String,
  language? : String,
) -> TextSpan {
  {
    start,
    end,
    font_family,
    font_size,
    slant,
    weight,
    stretch,
    color,
    background,
    underline,
    underline_color,
    overline,
    overline_color,
    strikethrough,
    strikethrough_color,
    rise,
    letter_spacing,
    font_features,
    language,
  }
}

///|
pub(all) struct TextLayout {
  width : Double?
  height : Double?
  max_lines : Int?
  wrap : TextWrap
  ellipsize : TextEllipsize
  alignment : TextAlignment
  justify : Bool
  justify_last_line : Bool
  indent : Double
  spacing : Double
  line_spacing : Double?
  auto_dir : Bool
  direction : TextDirection
  single_paragraph : Bool
  dpi : Double
}

///|
pub fn TextLayout::new(
  width? : Double,
  height? : Double,
  max_lines? : Int,
  wrap? : TextWrap = TextWrap::default(),
  ellipsize? : TextEllipsize = TextEllipsize::default(),
  alignment? : TextAlignment = TextAlignment::default(),
  justify? : Bool = false,
  justify_last_line? : Bool = false,
  indent? : Double = 0.0,
  spacing? : Double = 0.0,
  line_spacing? : Double,
  auto_dir? : Bool = true,
  direction? : TextDirection = TextDirection::default(),
  single_paragraph? : Bool = false,
  dpi? : Double = 96.0,
) -> TextLayout {
  {
    width,
    height,
    max_lines,
    wrap,
    ellipsize,
    alignment,
    justify,
    justify_last_line,
    indent,
    spacing,
    line_spacing,
    auto_dir,
    direction,
    single_paragraph,
    dpi,
  }
}

///|
pub impl Default for TextLayout with fn default() {
  TextLayout::new()
}

///|
pub struct TextSpec {
  priv text : String
  priv style : TextStyle
  priv spans : Array[TextSpan]
  priv layout : TextLayout
  priv tab_width : Int
  priv disable_ligatures : Bool
}

///|
pub fn TextSpec::new(
  text : String,
  style? : TextStyle = TextStyle::default(),
  spans? : Array[TextSpan] = [],
  layout? : TextLayout = TextLayout::default(),
  tab_width? : Int = 4,
  disable_ligatures? : Bool = false,
) -> TextSpec {
  { text, style, spans: spans.copy(), layout, tab_width, disable_ligatures }
}

///|
pub fn TextSpec::with_span(self : TextSpec, span : TextSpan) -> TextSpec {
  let spans = self.spans.copy()
  spans.push(span)
  { ..self, spans, }
}

///|
pub fn TextSpec::with_layout(self : TextSpec, layout : TextLayout) -> TextSpec {
  { ..self, layout, }
}

///|
pub fn TextSpec::with_disable_ligatures(
  self : TextSpec,
  disabled? : Bool = true,
) -> TextSpec {
  { ..self, disable_ligatures: disabled }
}

///|
pub struct MarkupTextSpec {
  priv markup : String
  priv style : TextStyle
  priv layout : TextLayout
  priv tab_width : Int
  priv disable_ligatures : Bool
}

///|
pub fn MarkupTextSpec::new(
  markup : String,
  style? : TextStyle = TextStyle::default(),
  layout? : TextLayout = TextLayout::default(),
  tab_width? : Int = 4,
  disable_ligatures? : Bool = false,
) -> MarkupTextSpec {
  { markup, style, layout, tab_width, disable_ligatures }
}

///|
pub(all) struct TextRange {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub(all) struct GlyphRange {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub(all) struct PangoRect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug)

///|
pub(all) struct PangoTextMetrics {
  ink : PangoRect
  logical : PangoRect
  baseline : Double
  unknown_glyphs : Int
  glyph_count : Int
  line_count : Int
} derive(Debug)

///|
pub(all) struct TextCluster {
  range : TextRange
  glyphs : GlyphRange
  line_index : Int
  bidi_level : Int
  pango_logical_bounds : PangoRect
  paths : Array[@object.FamilyPath]
} derive(Debug)

///|
pub(all) struct PangoTextLine {
  range : TextRange
  pango_ink : PangoRect
  pango_logical : PangoRect
  pango_baseline : Double
} derive(Debug)

///|
pub struct RenderedText {
  priv source : String
  priv character_count : Int
  priv svg : @svg.SvgObject
  priv clusters : Array[TextCluster]
  priv lines : Array[PangoTextLine]
  priv metrics : PangoTextMetrics
}

///|
pub fn RenderedText::source(self : RenderedText) -> String {
  self.source
}

///|
pub fn RenderedText::svg_object(self : RenderedText) -> @svg.SvgObject {
  self.svg.copy()
}

///|
pub fn RenderedText::clusters(self : RenderedText) -> Array[TextCluster] {
  self.clusters.map(copy_text_cluster)
}

///|
pub fn RenderedText::lines(self : RenderedText) -> Array[PangoTextLine] {
  self.lines.copy()
}

///|
pub fn RenderedText::pango_metrics(self : RenderedText) -> PangoTextMetrics {
  self.metrics
}

///|
pub fn RenderedText::object(self : RenderedText) -> @object.Object {
  let object = self.svg.object()
  object.with_transform(
    object.transform.then(
      @object.Transform::scale(sx=manim_text_scale, sy=manim_text_scale),
    ),
  )
}

///|
pub impl @object.IntoObject for RenderedText with fn to_object(self) {
  self.object()
}

///|
fn copy_text_cluster(cluster : TextCluster) -> TextCluster {
  { ..cluster, paths: cluster.paths.copy() }
}
