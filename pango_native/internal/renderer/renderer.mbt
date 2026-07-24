///|
pub(all) suberror RendererError {
  RendererFailed(String)
}

///|
pub(all) struct RendererCluster {
  source_start : Int
  source_end : Int
  glyph_start : Int
  glyph_end : Int
  line_index : Int
  bidi_level : Int
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub(all) struct RendererOutput {
  svg : String
  clusters : Array[RendererCluster]
  glyph_count : Int
}

///|
priv struct RendererPaint {
  red : UInt
  green : UInt
  blue : UInt
  alpha : UInt
}

///|
fn RendererPaint::from_rgba(
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) -> RendererPaint {
  {
    red: (red.clamp(min=0.0, max=1.0) * 65535.0).round().to_uint(),
    green: (green.clamp(min=0.0, max=1.0) * 65535.0).round().to_uint(),
    blue: (blue.clamp(min=0.0, max=1.0) * 65535.0).round().to_uint(),
    alpha: (alpha.clamp(min=0.0, max=1.0) * 65535.0).round().to_uint(),
  }
}

///|
fn RendererPaint::with_color(
  self : RendererPaint,
  color : @pango.Color,
) -> RendererPaint {
  {
    ..self,
    red: color.get_red(),
    green: color.get_green(),
    blue: color.get_blue(),
  }
}

///|
fn RendererPaint::write_hex_byte(
  self : RendererPaint,
  output : StringBuilder,
  byte : UInt,
) -> Unit {
  ignore(self)
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.write_char(digits[(byte / 16).reinterpret_as_int()])
  output.write_char(digits[(byte % 16).reinterpret_as_int()])
}

///|
fn RendererPaint::write_svg(
  self : RendererPaint,
  output : StringBuilder,
) -> Unit {
  output.write_string(" fill=\"#")
  self.write_hex_byte(output, self.red / 257)
  self.write_hex_byte(output, self.green / 257)
  self.write_hex_byte(output, self.blue / 257)
  output.write_string("\" fill-opacity=\"")
  output.write_string((self.alpha.to_double() / 65535.0).to_string())
  output.write_char('"')
}

///|
priv struct RendererClusterSlice {
  source_start : Int
  source_end : Int
  first_glyph : Int
  glyph_limit : Int
}

///|
/// Mutable state retained by the generated native PangoRenderer subclass.
#gobject.subclass(name=MotivaPangoSvgRenderer, parent=Renderer, gtype_name="MotivaPangoSvgRenderer")
struct MotivaPangoSvgRendererState {
  cairo : @cairo.Context
  elements : StringBuilder
  clusters : Array[RendererCluster]
  mut glyph_count : Int
  origin_x : Double
  origin_y : Double
  base_paint : RendererPaint
  paints : Array[RendererPaint]
  mut error : String?
}

///|
fn MotivaPangoSvgRendererState::part_index(
  self : MotivaPangoSvgRendererState,
  part : @pango.RenderPart,
) -> Int {
  ignore(self)
  match part {
    Foreground => 0
    Background => 1
    Underline => 2
    Strikethrough => 3
    Overline => 4
  }
}

///|
fn MotivaPangoSvgRendererState::paint(
  self : MotivaPangoSvgRendererState,
  part : @pango.RenderPart,
) -> RendererPaint {
  self.paints[self.part_index(part)]
}

///|
fn MotivaPangoSvgRendererState::fail(
  self : MotivaPangoSvgRendererState,
  message : String,
) -> Unit {
  if self.error is None {
    self.error = Some(message)
  }
}

///|
fn MotivaPangoSvgRendererState::line_index(
  self : MotivaPangoSvgRendererState,
  renderer : @pango.Renderer,
) -> Int {
  ignore(self)
  guard renderer.get_layout() is Some(layout) &&
    renderer.get_layout_line() is Some(current) else {
    return -1
  }
  let current_start = current.get_start_index()
  let current_length = current.get_length()
  for index, line in layout.get_lines_readonly() {
    if line.get_start_index() == current_start &&
      line.get_length() == current_length {
      return index
    }
  }
  -1
}

///|
fn MotivaPangoSvgRendererState::write_path(
  self : MotivaPangoSvgRendererState,
  output : StringBuilder,
  path : @cairo.Path,
  paint : RendererPaint,
) -> Bool {
  let status = path.status()
  if !status.is_success() {
    self.fail(status.to_string())
    return false
  }
  let data = StringBuilder()
  let mut draws = false
  for segment in path.segments() {
    match segment {
      @cairo.PathSegmentMoveTo(x, y) => data.write_string("M \{x} \{y} ")
      @cairo.PathSegmentLineTo(x, y) => {
        draws = true
        data.write_string("L \{x} \{y} ")
      }
      @cairo.PathSegmentCurveTo(x1, y1, x2, y2, x3, y3) => {
        draws = true
        data.write_string("C \{x1} \{y1} \{x2} \{y2} \{x3} \{y3} ")
      }
      @cairo.PathSegmentClosePath => {
        draws = true
        data.write_string("Z ")
      }
    }
  }
  if !draws {
    return false
  }
  output.write_string("<path d=\"")
  output.write_string(data.to_string())
  output.write_char('"')
  paint.write_svg(output)
  output.write_string("/>\n")
  true
}

///|
fn MotivaPangoSvgRendererState::write_glyph_path(
  self : MotivaPangoSvgRendererState,
  output : StringBuilder,
  font : &@pango.IFont,
  glyphs : @pango.GlyphString,
  glyph : Int,
  x : Double,
  y : Double,
  paint : RendererPaint,
) -> Bool {
  self.cairo.new_path()
  self.cairo.move_to(x + self.origin_x, y + self.origin_y)
  if !@pangocairo.glyph_string_path_range(
      self.cairo,
      font,
      glyphs,
      glyph,
      glyph + 1,
    ) {
    self.fail("invalid Pango glyph range")
    return false
  }
  self.write_path(output, self.cairo.copy_path(), paint)
}

///|
impl @pango.VRendererPrepareRun for MotivaPangoSvgRendererState with fn prepare_run(
  self,
  renderer,
  run,
) {
  ignore(renderer)
  for index in 0..<self.paints.length() {
    self.paints[index] = self.base_paint
  }
  let attributes = run.get_item().get_analysis().get_extra_attrs()
  for attribute in attributes {
    match attribute.get_type() {
      Foreground =>
        if attribute.as_color() is Some(value) {
          let paint = self.paints[0].with_color(value.get_color())
          self.paints[0] = paint
          self.paints[2] = paint
          self.paints[3] = paint
          self.paints[4] = paint
        }
      Background =>
        if attribute.as_color() is Some(value) {
          self.paints[1] = self.paints[1].with_color(value.get_color())
        }
      ForegroundAlpha =>
        if attribute.as_int() is Some(value) {
          let alpha = value.get_value().reinterpret_as_uint()
          self.paints[0] = { ..self.paints[0], alpha, }
          self.paints[2] = { ..self.paints[2], alpha, }
          self.paints[3] = { ..self.paints[3], alpha, }
          self.paints[4] = { ..self.paints[4], alpha, }
        }
      BackgroundAlpha =>
        if attribute.as_int() is Some(value) {
          self.paints[1] = {
            ..self.paints[1],
            alpha: value.get_value().reinterpret_as_uint(),
          }
        }
      _ => ()
    }
  }
  for attribute in attributes {
    match attribute.get_type() {
      UnderlineColor =>
        if attribute.as_color() is Some(value) {
          self.paints[2] = self.paints[2].with_color(value.get_color())
        }
      StrikethroughColor =>
        if attribute.as_color() is Some(value) {
          self.paints[3] = self.paints[3].with_color(value.get_color())
        }
      OverlineColor =>
        if attribute.as_color() is Some(value) {
          self.paints[4] = self.paints[4].with_color(value.get_color())
        }
      _ => ()
    }
  }
}

///|
impl @pango.VRendererDrawGlyphItem for MotivaPangoSvgRendererState with fn draw_glyph_item(
  self,
  renderer,
  text,
  glyph_item,
  x,
  y,
) {
  if self.error is Some(_) {
    return
  }
  guard text is Some(text) &&
    glyph_item.get_item().get_analysis().get_font() is Some(font) else {
    self.fail("invalid Pango glyph item")
    return
  }
  let line_index = self.line_index(renderer)
  if line_index < 0 {
    self.fail("invalid Pango layout line")
    return
  }
  let glyphs = glyph_item.get_glyphs()
  let glyph_infos = glyphs.get_glyphs()
  let slices : Array[RendererClusterSlice] = []
  if @pango.GlyphItemIter::from_start(glyph_item, text) is Some(iterator) {
    let mut more = true
    while more {
      let start_glyph = iterator.get_start_glyph()
      let end_glyph = iterator.get_end_glyph()
      let (first_glyph, glyph_limit) = if start_glyph <= end_glyph {
        (start_glyph, end_glyph)
      } else {
        (end_glyph + 1, start_glyph + 1)
      }
      if first_glyph < 0 ||
        glyph_limit < first_glyph ||
        glyph_limit > glyph_infos.length() {
        self.fail("invalid Pango cluster glyph range")
        return
      }
      slices.push({
        source_start: iterator.get_start_index(),
        source_end: iterator.get_end_index(),
        first_glyph,
        glyph_limit,
      })
      more = iterator.next_cluster()
    }
  }
  slices.sort_by((left, right) => left.first_glyph - right.first_glyph)
  let positions : Array[Int64] = [x.to_int64()]
  for info in glyph_infos {
    positions.push(
      positions[positions.length() - 1] +
      info.get_geometry().get_width().to_int64(),
    )
  }
  guard renderer.get_layout() is Some(layout) &&
    renderer.get_layout_line() is Some(line) else {
    self.fail("invalid Pango layout")
    return
  }
  let paint = self.paint(@pango.RenderPart::Foreground)
  for slice in slices {
    let cluster_svg = StringBuilder()
    let glyph_start = self.glyph_count
    for glyph in slice.first_glyph..<slice.glyph_limit {
      if glyph_infos[glyph].get_glyph() != @pango.GLYPH_EMPTY {
        self.glyph_count += 1
        ignore(
          self.write_glyph_path(
            cluster_svg,
            font,
            glyphs,
            glyph,
            positions[glyph].to_double() / @pango.SCALE.to_double(),
            @pango.units_to_double(y),
            paint,
          ),
        )
      }
    }
    let x_start = line.index_to_x(slice.source_start, false)
    let x_end = line.index_to_x(slice.source_end, false)
    let position = layout.index_to_pos(slice.source_start)
    let cluster_index = self.clusters.length()
    self.clusters.push({
      source_start: slice.source_start,
      source_end: slice.source_end,
      glyph_start,
      glyph_end: self.glyph_count,
      line_index,
      bidi_level: glyph_item
      .get_item()
      .get_analysis()
      .get_level()
      .reinterpret_as_int(),
      x: @pango.units_to_double(Int::min(x_start, x_end)),
      y: @pango.units_to_double(position.get_y()),
      width: @pango.units_to_double(Int::abs(x_end - x_start)),
      height: @pango.units_to_double(position.get_height()),
    })
    if !cluster_svg.is_empty() {
      self.elements.write_string("<g id=\"motiva-cluster-\{cluster_index}\">\n")
      self.elements.write_string(cluster_svg.to_string())
      self.elements.write_string("</g>\n")
    }
  }
}

///|
impl @pango.VRendererDrawRectangle for MotivaPangoSvgRendererState with fn draw_rectangle(
  self,
  renderer,
  part,
  x,
  y,
  width,
  height,
) {
  ignore(renderer)
  let x = @pango.units_to_double(x) + self.origin_x
  let y = @pango.units_to_double(y) + self.origin_y
  let width = @pango.units_to_double(width)
  let height = @pango.units_to_double(height)
  let left = if width < 0.0 { x + width } else { x }
  let top = if height < 0.0 { y + height } else { y }
  self.elements.write_string(
    "<rect x=\"\{left}\" y=\"\{top}\" width=\"\{Double::abs(width)}\" height=\"\{Double::abs(height)}\"",
  )
  self.paint(part).write_svg(self.elements)
  self.elements.write_string("/>\n")
}

///|
impl @pango.VRendererDrawErrorUnderline for MotivaPangoSvgRendererState with fn draw_error_underline(
  self,
  renderer,
  x,
  y,
  width,
  height,
) {
  ignore(renderer)
  self.cairo.new_path()
  @pangocairo.error_underline_path(
    self.cairo,
    @pango.units_to_double(x) + self.origin_x,
    @pango.units_to_double(y) + self.origin_y,
    @pango.units_to_double(width),
    @pango.units_to_double(height),
  )
  ignore(
    self.write_path(
      self.elements,
      self.cairo.copy_path(),
      self.paint(@pango.RenderPart::Underline),
    ),
  )
}

///|
impl @pango.VRendererDrawTrapezoid for MotivaPangoSvgRendererState with fn draw_trapezoid(
  self,
  renderer,
  part,
  y1,
  x11,
  x21,
  y2,
  x12,
  x22,
) {
  ignore(renderer)
  self.elements.write_string(
    "<path d=\"M \{x11 + self.origin_x} \{y1 + self.origin_y} L \{x21 + self.origin_x} \{y1 + self.origin_y} L \{x22 + self.origin_x} \{y2 + self.origin_y} L \{x12 + self.origin_x} \{y2 + self.origin_y} Z\"",
  )
  self.paint(part).write_svg(self.elements)
  self.elements.write_string("/>\n")
}

///|
impl @pango.VRendererDrawGlyph for MotivaPangoSvgRendererState with fn draw_glyph(
  self,
  renderer,
  font,
  glyph,
  x,
  y,
) {
  ignore(renderer)
  let glyphs = @pango.GlyphString::new()
  glyphs.set_size(1)
  let infos = glyphs.get_glyphs()
  if infos is [info] {
    info.set_glyph(glyph)
    ignore(
      self.write_glyph_path(
        self.elements,
        font,
        glyphs,
        0,
        x,
        y,
        self.paint(@pango.RenderPart::Foreground),
      ),
    )
  } else {
    self.fail("failed to create a Pango glyph string")
  }
}

///|
impl @pango.VRendererDrawShape for MotivaPangoSvgRendererState with fn draw_shape(
  self,
  renderer,
  attr,
  x,
  y,
) {
  ignore(renderer)
  ignore(attr)
  ignore(x)
  ignore(y)
  self.fail("Pango shape attributes are not supported")
}

///|
pub fn render(
  layout : @pango.Layout,
  cairo : @cairo.Context,
  width : Double,
  height : Double,
  origin_x : Double,
  origin_y : Double,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
) -> RendererOutput raise RendererError {
  let base_paint = RendererPaint::from_rgba(red, green, blue, alpha)
  let state : MotivaPangoSvgRendererState = {
    cairo,
    elements: StringBuilder(),
    clusters: [],
    glyph_count: 0,
    origin_x,
    origin_y,
    base_paint,
    paints: [base_paint, base_paint, base_paint, base_paint, base_paint],
    error: None,
  }
  let renderer = MotivaPangoSvgRenderer::new(state).as_pango_renderer()
  renderer.activate()
  renderer.draw_layout(layout, 0, 0)
  renderer.deactivate()
  if state.error is Some(message) {
    raise RendererFailed(message)
  }
  let document = StringBuilder()
  document.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}\" height=\"\{height}\" viewBox=\"0 0 \{width} \{height}\">\n",
  )
  document.write_string(state.elements.to_string())
  document.write_string("</svg>\n")
  {
    svg: document.to_string(),
    clusters: state.clusters,
    glyph_count: state.glyph_count,
  }
}
