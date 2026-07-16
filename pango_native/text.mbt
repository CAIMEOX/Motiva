///|
priv enum TextPathOp {
  PathColor(@object.Rgba)
  PathOpacity(Double)
}

///|
pub struct Text {
  priv rendered : RenderedText
  priv object : @object.Object
}

///|
pub struct MarkupText {
  priv markup : String
  priv rendered : RenderedText
  priv object : @object.Object
}

///|
pub fn Text::new(
  source : String,
  style? : TextStyle = TextStyle::default(),
  spans? : Array[TextSpan] = [],
  layout? : TextLayout = TextLayout::default(),
  tab_width? : Int = 4,
  disable_ligatures? : Bool = false,
  fill_opacity? : Double = 1.0,
  stroke_width? : Double = 0.0,
  width? : Double,
  height? : Double,
  should_center? : Bool = true,
) -> Text raise TextError {
  PangoTextEngine::new().text(
    TextSpec::new(
      source,
      style~,
      spans~,
      layout~,
      tab_width~,
      disable_ligatures~,
    ),
    fill_opacity~,
    stroke_width~,
    width?,
    height?,
    should_center~,
  )
}

///|
pub fn MarkupText::new(
  markup : String,
  style? : TextStyle = TextStyle::default(),
  layout? : TextLayout = TextLayout::default(),
  tab_width? : Int = 4,
  disable_ligatures? : Bool = false,
  fill_opacity? : Double = 1.0,
  stroke_width? : Double = 0.0,
  width? : Double,
  height? : Double,
  should_center? : Bool = true,
) -> MarkupText raise TextError {
  PangoTextEngine::new().markup_text(
    MarkupTextSpec::new(markup, style~, layout~, tab_width~, disable_ligatures~),
    fill_opacity~,
    stroke_width~,
    width?,
    height?,
    should_center~,
  )
}

///|
pub fn PangoTextEngine::text(
  self : PangoTextEngine,
  spec : TextSpec,
  fill_opacity? : Double = 1.0,
  stroke_width? : Double = 0.0,
  width? : Double,
  height? : Double,
  should_center? : Bool = true,
) -> Text raise TextError {
  let rendered = self.render_text(spec)
  {
    rendered,
    object: make_text_object(
      rendered, fill_opacity, stroke_width, width, height, should_center,
    ),
  }
}

///|
pub fn PangoTextEngine::markup_text(
  self : PangoTextEngine,
  spec : MarkupTextSpec,
  fill_opacity? : Double = 1.0,
  stroke_width? : Double = 0.0,
  width? : Double,
  height? : Double,
  should_center? : Bool = true,
) -> MarkupText raise TextError {
  let rendered = self.render_markup(spec)
  {
    markup: spec.markup,
    rendered,
    object: make_text_object(
      rendered, fill_opacity, stroke_width, width, height, should_center,
    ),
  }
}

///|
pub fn Text::source(self : Text) -> String {
  self.rendered.source()
}

///|
pub fn Text::svg_object(self : Text) -> @svg.SvgObject {
  self.rendered.svg_object()
}

///|
pub fn Text::pango_metrics(self : Text) -> PangoTextMetrics {
  self.rendered.pango_metrics()
}

///|
pub fn Text::clusters(self : Text) -> Array[TextCluster] {
  self.rendered.clusters()
}

///|
pub fn Text::lines(self : Text) -> Array[PangoTextLine] {
  self.rendered.lines()
}

///|
pub fn Text::character_count(self : Text) -> Int {
  self.rendered.character_count()
}

///|
pub fn Text::fragment(
  self : Text,
  start : Int,
  end : Int,
) -> TextFragment raise TextError {
  self.rendered.fragment(start, end)
}

///|
pub fn Text::fragments_by_text(
  self : Text,
  pattern : String,
) -> Array[TextFragment] raise TextError {
  self.rendered.fragments_by_text(pattern)
}

///|
pub fn Text::characters(self : Text) -> Array[TextFragment] {
  self.rendered.characters()
}

///|
pub fn Text::object(self : Text) -> @object.Object {
  self.object
}

///|
pub fn Text::set_color(self : Text, color : @object.Rgba) -> Text {
  { ..self, object: self.object.set_color(color) }
}

///|
pub fn Text::set_color_by_range(
  self : Text,
  start : Int,
  end : Int,
  color : @object.Rgba,
) -> Text raise TextError {
  validate_color(color, "range color")
  let fragment = self.fragment(start, end)
  { ..self, object: apply_fragment_op(self.object, fragment, PathColor(color)) }
}

///|
pub fn Text::set_color_by_text(
  self : Text,
  pattern : String,
  color : @object.Rgba,
) -> Text raise TextError {
  validate_color(color, "text color")
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_fragment_op(object, fragment, PathColor(color))
  }
  { ..self, object, }
}

///|
pub fn Text::set_opacity_by_text(
  self : Text,
  pattern : String,
  opacity : Double,
) -> Text raise TextError {
  validate_opacity(opacity, "text opacity")
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_fragment_op(object, fragment, PathOpacity(opacity))
  }
  { ..self, object, }
}

///|
pub fn Text::set_color_by_gradient(
  self : Text,
  colors : Array[@object.Rgba],
) -> Text raise TextError {
  {
    ..self,
    object: apply_cluster_gradient(self.object, self.rendered.clusters, colors),
  }
}

///|
pub fn Text::set_gradient_by_text(
  self : Text,
  pattern : String,
  colors : Array[@object.Rgba],
) -> Text raise TextError {
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_cluster_gradient(object, fragment.clusters, colors)
  }
  { ..self, object, }
}

///|
pub impl @object.IntoObject for Text with fn to_object(self) {
  self.object()
}

///|
pub fn MarkupText::source(self : MarkupText) -> String {
  self.rendered.source()
}

///|
pub fn MarkupText::markup(self : MarkupText) -> String {
  self.markup
}

///|
pub fn MarkupText::svg_object(self : MarkupText) -> @svg.SvgObject {
  self.rendered.svg_object()
}

///|
pub fn MarkupText::pango_metrics(self : MarkupText) -> PangoTextMetrics {
  self.rendered.pango_metrics()
}

///|
pub fn MarkupText::clusters(self : MarkupText) -> Array[TextCluster] {
  self.rendered.clusters()
}

///|
pub fn MarkupText::lines(self : MarkupText) -> Array[PangoTextLine] {
  self.rendered.lines()
}

///|
pub fn MarkupText::character_count(self : MarkupText) -> Int {
  self.rendered.character_count()
}

///|
pub fn MarkupText::fragment(
  self : MarkupText,
  start : Int,
  end : Int,
) -> TextFragment raise TextError {
  self.rendered.fragment(start, end)
}

///|
pub fn MarkupText::fragments_by_text(
  self : MarkupText,
  pattern : String,
) -> Array[TextFragment] raise TextError {
  self.rendered.fragments_by_text(pattern)
}

///|
pub fn MarkupText::characters(self : MarkupText) -> Array[TextFragment] {
  self.rendered.characters()
}

///|
pub fn MarkupText::object(self : MarkupText) -> @object.Object {
  self.object
}

///|
pub fn MarkupText::set_color(
  self : MarkupText,
  color : @object.Rgba,
) -> MarkupText {
  { ..self, object: self.object.set_color(color) }
}

///|
pub fn MarkupText::set_color_by_range(
  self : MarkupText,
  start : Int,
  end : Int,
  color : @object.Rgba,
) -> MarkupText raise TextError {
  validate_color(color, "range color")
  let fragment = self.fragment(start, end)
  { ..self, object: apply_fragment_op(self.object, fragment, PathColor(color)) }
}

///|
pub fn MarkupText::set_color_by_text(
  self : MarkupText,
  pattern : String,
  color : @object.Rgba,
) -> MarkupText raise TextError {
  validate_color(color, "text color")
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_fragment_op(object, fragment, PathColor(color))
  }
  { ..self, object, }
}

///|
pub fn MarkupText::set_opacity_by_text(
  self : MarkupText,
  pattern : String,
  opacity : Double,
) -> MarkupText raise TextError {
  validate_opacity(opacity, "text opacity")
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_fragment_op(object, fragment, PathOpacity(opacity))
  }
  { ..self, object, }
}

///|
pub fn MarkupText::set_color_by_gradient(
  self : MarkupText,
  colors : Array[@object.Rgba],
) -> MarkupText raise TextError {
  {
    ..self,
    object: apply_cluster_gradient(self.object, self.rendered.clusters, colors),
  }
}

///|
pub fn MarkupText::set_gradient_by_text(
  self : MarkupText,
  pattern : String,
  colors : Array[@object.Rgba],
) -> MarkupText raise TextError {
  let mut object = self.object
  for fragment in self.fragments_by_text(pattern) {
    object = apply_cluster_gradient(object, fragment.clusters, colors)
  }
  { ..self, object, }
}

///|
pub impl @object.IntoObject for MarkupText with fn to_object(self) {
  self.object()
}

///|
fn make_text_object(
  rendered : RenderedText,
  fill_opacity : Double,
  stroke_width : Double,
  width : Double?,
  height : Double?,
  should_center : Bool,
) -> @object.Object raise TextError {
  validate_presentation(fill_opacity, stroke_width, width, height)
  let presented = apply_presentation(
    rendered.object(),
    fill_opacity,
    stroke_width,
  )
  let resized = resize_text_object(presented, width, height)
  if should_center {
    resized.move_to(@object.Vec3::zero())
  } else {
    resized
  }
}

///|
fn validate_presentation(
  fill_opacity : Double,
  stroke_width : Double,
  width : Double?,
  height : Double?,
) -> Unit raise TextError {
  if fill_opacity < 0.0 ||
    fill_opacity > 1.0 ||
    fill_opacity.is_nan() ||
    fill_opacity.is_inf() {
    raise InvalidPresentation("fill_opacity must be between zero and one")
  }
  if stroke_width < 0.0 || stroke_width.is_nan() || stroke_width.is_inf() {
    raise InvalidPresentation("stroke_width must be finite and non-negative")
  }
  match width {
    Some(value) if value <= 0.0 || value.is_nan() || value.is_inf() =>
      raise InvalidPresentation("width must be finite and greater than zero")
    _ => ()
  }
  match height {
    Some(value) if value <= 0.0 || value.is_nan() || value.is_inf() =>
      raise InvalidPresentation("height must be finite and greater than zero")
    _ => ()
  }
}

///|
fn apply_presentation(
  object : @object.Object,
  fill_opacity : Double,
  stroke_width : Double,
) -> @object.Object {
  let node = match object.node {
    Empty => @object.Empty
    Group(children) =>
      Group(
        children.map(child => {
          apply_presentation(child, fill_opacity, stroke_width)
        }),
      )
    Path(path, style) => {
      let (stroke, stroke_opacity) = match style.stroke {
        Some(color) => (Some(color), style.stroke_opacity * fill_opacity)
        None => (style.fill, style.fill_opacity * fill_opacity)
      }
      Path(path, {
        ..style,
        fill_opacity: style.fill_opacity * fill_opacity,
        stroke,
        stroke_opacity,
        stroke_width,
      })
    }
  }
  { ..object, node, }
}

///|
fn resize_text_object(
  object : @object.Object,
  width : Double?,
  height : Double?,
) -> @object.Object raise TextError {
  match (width, height) {
    (None, None) => object
    _ => {
      guard object.bounds() is Some(bounds) else {
        raise InvalidPresentation("empty text cannot be resized")
      }
      let current_width = bounds.width()
      let current_height = bounds.height()
      let (sx, sy) = match (width, height) {
        (Some(target_width), Some(target_height)) =>
          (
            dimension_scale(target_width, current_width, "width"),
            dimension_scale(target_height, current_height, "height"),
          )
        (Some(target_width), None) => {
          let scale = dimension_scale(target_width, current_width, "width")
          (scale, scale)
        }
        (None, Some(target_height)) => {
          let scale = dimension_scale(target_height, current_height, "height")
          (scale, scale)
        }
        (None, None) => (1.0, 1.0)
      }
      let center = bounds.center()
      let resize = @object.Transform::translate(center.scale(-1.0))
        .then(@object.Transform::scale(sx~, sy~))
        .then(@object.Transform::translate(center))
      object.with_transform(object.transform.then(resize))
    }
  }
}

///|
fn dimension_scale(
  target : Double,
  current : Double,
  dimension : String,
) -> Double raise TextError {
  if current == 0.0 {
    raise InvalidPresentation("text has zero \{dimension}")
  }
  target / current
}

///|
fn apply_fragment_op(
  object : @object.Object,
  fragment : TextFragment,
  operation : TextPathOp,
) -> @object.Object {
  let mut result = object
  for path in fragment.paths {
    result = apply_op_at_path(result, path.indices(), 0, operation)
  }
  result
}

///|
fn apply_cluster_gradient(
  object : @object.Object,
  clusters : Array[TextCluster],
  colors : Array[@object.Rgba],
) -> @object.Object raise TextError {
  if colors.is_empty() {
    raise InvalidGradient(0)
  }
  for color in colors {
    validate_color(color, "gradient color")
  }
  let visible = clusters.filter(cluster => !cluster.paths.is_empty())
  let mut result = object
  for index, cluster in visible {
    let color = gradient_color(colors, index, visible.length())
    for path in cluster.paths {
      result = apply_op_at_path(result, path.indices(), 0, PathColor(color))
    }
  }
  result
}

///|
fn validate_opacity(opacity : Double, name : String) -> Unit raise TextError {
  if opacity < 0.0 || opacity > 1.0 || opacity.is_nan() || opacity.is_inf() {
    raise InvalidPresentation("\{name} must be finite and between zero and one")
  }
}

///|
fn gradient_color(
  colors : Array[@object.Rgba],
  index : Int,
  count : Int,
) -> @object.Rgba {
  if count <= 1 || colors.length() == 1 {
    return colors[0]
  }
  let denominator = count - 1
  let scaled = index * (colors.length() - 1)
  let left_index = scaled / denominator
  let remainder = scaled % denominator
  let right_index = if left_index + 1 < colors.length() {
    left_index + 1
  } else {
    left_index
  }
  let alpha = Double::from_int(remainder) / Double::from_int(denominator)
  interpolate_color(colors[left_index], colors[right_index], alpha)
}

///|
fn interpolate_color(
  start : @object.Rgba,
  end : @object.Rgba,
  alpha : Double,
) -> @object.Rgba {
  let inverse = 1.0 - alpha
  @object.Rgba::new(
    r=start.r * inverse + end.r * alpha,
    g=start.g * inverse + end.g * alpha,
    b=start.b * inverse + end.b * alpha,
    a=start.a * inverse + end.a * alpha,
  )
}

///|
fn apply_op_at_path(
  object : @object.Object,
  indices : Array[Int],
  depth : Int,
  operation : TextPathOp,
) -> @object.Object {
  if depth == indices.length() {
    return match operation {
      PathColor(color) => object.set_color(color)
      PathOpacity(opacity) => object.set_fill(opacity~).set_stroke(opacity~)
    }
  }
  match object.node {
    Group(children) =>
      match children.get(indices[depth]) {
        None => object
        Some(child) => {
          let next = children.copy()
          next[indices[depth]] = apply_op_at_path(
            child,
            indices,
            depth + 1,
            operation,
          )
          { ..object, node: Group(next) }
        }
      }
    _ => object
  }
}
