///|
test "PangoTextEngine renders multilingual text through SVG" {
  let engine = PangoTextEngine::new()
  let rendered = engine.render_text(
    TextSpec::new("office العربية 中文"),
  )
  assert_true(pango_version() != "")
  assert_true(cairo_version() != "")
  assert_true(rendered.pango_metrics().glyph_count > 0)
  assert_true(rendered.pango_metrics().unknown_glyphs == 0)
  assert_true(rendered.clusters().length() > 0)
  assert_true(rendered.object().bounds() is Some(_))
}

///|
test "PangoTextEngine preserves source ranges across tabs and UTF-8" {
  let rendered = render_text(
    TextSpec::new(
      "A\t中B",
      spans=[TextSpan::new(2, 3, color=@object.Rgba::red(), weight=Bold)],
      disable_ligatures=true,
    ),
  )
  assert_eq(rendered.source(), "A\t中B")
  assert_true(
    rendered.clusters().any(cluster => cluster.range == { start: 2, end: 3 }),
  )
}

///|
test "Pango markup supports styled multiline layout" {
  let rendered = render_markup(
    MarkupTextSpec::new(
      "<span foreground='#ff0000' weight='bold'>Hello</span>\n<i>世界</i>",
      layout=TextLayout::new(
        width=120.0,
        alignment=AlignCenter,
        line_spacing=1.2,
      ),
    ),
  )
  assert_eq(rendered.source(), "Hello\n世界")
  assert_eq(rendered.lines().length(), 2)
}

///|
test "invalid Pango markup raises a typed error" {
  try render_markup(MarkupTextSpec::new("<span>missing close")) catch {
    InvalidMarkup(_) => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid markup to raise")
  }
}

///|
fn assert_text_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn object_at_text_path(
  object : @object.Object,
  path : @object.FamilyPath,
) -> @object.Object? {
  object_at_text_indices(object, path.indices(), 0)
}

///|
fn object_at_text_indices(
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
      .bind(child => object_at_text_indices(child, indices, depth + 1))
    _ => None
  }
}

///|
fn first_text_path_style(object : @object.Object) -> @object.ShapeStyle? {
  match object.node {
    Empty => None
    Path(_, style) => Some(style)
    Mesh(_, _) => None
    Group(children) => {
      for child in children {
        match first_text_path_style(child) {
          Some(style) => return Some(style)
          None => ()
        }
      }
      None
    }
  }
}

///|
fn style_at_text_path(
  object : @object.Object,
  path : @object.FamilyPath,
) -> @object.ShapeStyle? {
  object_at_text_path(object, path).bind(first_text_path_style)
}

///|
fn text_fragment_bounds(
  object : @object.Object,
  fragment : TextFragment,
) -> @object.Aabb? {
  let mut bounds : @object.Aabb? = None
  for path in fragment.paths {
    let next = object_at_text_path(object, path).bind(child => child.bounds())
    bounds = match (bounds, next) {
      (None, value) => value
      (value, None) => value
      (Some(left), Some(right)) => Some(left.union(right))
    }
  }
  bounds
}

///|
fn assert_text_paint(
  actual : @object.Rgba?,
  expected : @object.Rgba,
) -> Unit raise {
  guard actual is Some(color) else { fail("text paint should be present") }
  assert_text_close(color.r, expected.r)
  assert_text_close(color.g, expected.g)
  assert_text_close(color.b, expected.b)
  assert_text_close(color.a, expected.a)
}

///|
test "Text is a centered resizable IntoObject" {
  let text = Text::new(
    "Motiva",
    fill_opacity=0.6,
    stroke_width=0.08,
    width=4.0,
    height=1.0,
  )
  let object = @object.into_object(text)
  guard object.bounds() is Some(bounds) else {
    fail("rendered text should have bounds")
  }
  assert_text_close(bounds.width(), 4.0)
  assert_text_close(bounds.height(), 1.0)
  assert_text_close(bounds.center().x, 0.0)
  assert_text_close(bounds.center().y, 0.0)
  guard first_text_path_style(object) is Some(style) else {
    fail("rendered text should contain a styled path")
  }
  assert_text_close(style.fill_opacity, 0.6)
  assert_text_close(style.stroke_width, 0.08)
}

///|
test "TextSpec styles every Unicode substring occurrence" {
  let spec = TextSpec::new("red 世界 red")
    .with_color_by_text("red", @object.Rgba::red())
    .with_weight_by_text("世界", Bold)
  let text = PangoTextEngine::new().text(spec)
  let matches = text.fragments_by_text("red")
  assert_eq(matches.length(), 2)
  assert_eq(matches[0].source, "red")
  assert_eq(matches[0].range, { start: 0, end: 3 })
  for fragment in matches {
    guard fragment.paths.get(0) is Some(path) else {
      fail("colored text should resolve to glyph paths")
    }
    guard style_at_text_path(text.object(), path) is Some(style) else {
      fail("glyph path should resolve to a style")
    }
    assert_text_paint(style.fill, @object.Rgba::red())
  }
  guard text.fragments_by_text("世界") is [world] else {
    fail("Unicode matching should use character indices")
  }
  assert_eq(world.range, { start: 4, end: 6 })
}

///|
test "Text fragments preserve shaping clusters and whitespace" {
  let text = Text::new("office العربية 中文")
  let ligature = text.fragment(1, 4)
  assert_eq(ligature.source, "ffi")
  assert_true(!ligature.clusters.is_empty())
  assert_true(!ligature.paths.is_empty())
  guard text.fragments_by_text(" ") is [first_space, second_space] else {
    fail("both spaces should remain addressable source fragments")
  }
  assert_true(
    first_space.clusters.any(cluster => cluster.pango_logical_bounds.width > 0.0),
  )
  assert_true(
    second_space.clusters.any(cluster => {
      cluster.pango_logical_bounds.width > 0.0
    }),
  )
  let only_space = Text::new(" ").fragment(0, 1)
  assert_true(only_space.paths.is_empty())
  let characters = Text::new("A 中").characters()
  assert_eq(characters.length(), 3)
  assert_eq(characters.map(character => character.source), ["A", " ", "中"])
}

///|
test "Text post-render color and gradient target glyph family paths" {
  let recolored = Text::new("A B A")
    .set_color_by_text("A", @object.Rgba::yellow())
    .set_gradient_by_text("B", [@object.Rgba::red(), @object.Rgba::blue()])
  for fragment in recolored.fragments_by_text("A") {
    guard fragment.paths.get(0) is Some(path) &&
      style_at_text_path(recolored.object(), path) is Some(style) else {
      fail("recolored glyph should resolve to a style")
    }
    assert_text_paint(style.fill, @object.Rgba::yellow())
  }
  let gradient = Text::new("ABC").set_color_by_gradient([
    @object.Rgba::red(),
    @object.Rgba::blue(),
  ])
  let visible = gradient.clusters().filter(cluster => !cluster.paths.is_empty())
  guard visible.get(0) is Some(first) &&
    visible.last() is Some(last) &&
    first.paths.get(0) is Some(first_path) &&
    last.paths.get(0) is Some(last_path) &&
    style_at_text_path(gradient.object(), first_path) is Some(first_style) &&
    style_at_text_path(gradient.object(), last_path) is Some(last_style) else {
    fail("gradient endpoints should resolve to glyph styles")
  }
  assert_text_paint(first_style.fill, @object.Rgba::red())
  assert_text_paint(last_style.fill, @object.Rgba::blue())
}

///|
test "MarkupText supports Pango markup tabs and multiline layout" {
  let markup = MarkupText::new(
    "<b>Hello</b>\t<span foreground='#ff0000' underline='double'>世界</span>\n<i>مرحبا</i>",
    layout=TextLayout::new(line_spacing=1.2),
  )
  assert_eq(
    markup.markup(),
    "<b>Hello</b>\t<span foreground='#ff0000' underline='double'>世界</span>\n<i>مرحبا</i>",
  )
  assert_eq(markup.source(), "Hello    世界\nمرحبا")
  assert_eq(markup.lines().length(), 2)
  guard markup.fragments_by_text("世界") is [world] &&
    world.paths.get(0) is Some(path) &&
    style_at_text_path(markup.object(), path) is Some(style) else {
    fail("marked-up glyphs should remain source-addressable")
  }
  assert_text_paint(style.fill, @object.Rgba::red())
}

///|
test "TextSpan supports independently colored text decorations" {
  let decorated = Text::new("decorated", spans=[
    TextSpan::new(
      0,
      9,
      underline=DoubleUnderline,
      underline_color=@object.Rgba::red(),
      overline=true,
      overline_color=@object.Rgba::blue(),
      strikethrough=true,
      strikethrough_color=@object.Rgba::yellow(),
    ),
  ])
  assert_true(decorated.object().bounds() is Some(_))
  assert_eq(decorated.fragments_by_text("decorated").length(), 1)
}

///|
test "Pango layout wraps text and preserves source ordered clusters" {
  let text = Text::new(
    "one two three four five six seven",
    layout=TextLayout::new(width=45.0, wrap=WrapWord),
  )
  assert_true(text.lines().length() > 1)
  let clusters = text.clusters()
  for index in 1..<clusters.length() {
    assert_true(clusters[index - 1].range.start <= clusters[index].range.start)
  }
}

///|
test "PangoTextEngine exposes fonts and typed registration failures" {
  let engine = PangoTextEngine::new()
  let fonts = engine.font_list()
  guard fonts.get(0) is Some(font) else {
    fail("Pango should expose at least one font family")
  }
  assert_true(engine.has_font(font))
  try engine.register_font("/motiva/missing-font.ttf") catch {
    Native(status~, message~) => {
      assert_true(status != 0)
      assert_true(message != "")
    }
    error => raise error
  } noraise {
    _ => fail("missing font registration should raise a typed native error")
  }
}

///|
test "text selection and gradient validation use TextError" {
  let text = Text::new("abc")
  try text.fragments_by_text("") catch {
    EmptyPattern => ()
    error => raise error
  } noraise {
    _ => fail("empty text patterns should be rejected")
  }
  try text.set_color_by_gradient([]) catch {
    InvalidGradient(0) => ()
    error => raise error
  } noraise {
    _ => fail("empty gradients should be rejected")
  }
  try text.fragment(-1, 2) catch {
    InvalidSpan(start=-1, end=2, character_count=3) => ()
    error => raise error
  } noraise {
    _ => fail("invalid text ranges should be rejected")
  }
}

///|
test "RTL clusters map logical source characters to visual glyph groups" {
  let text = Text::new(
    "אבג",
    layout=TextLayout::new(auto_dir=false, direction=RightToLeft),
  )
  let first = text.fragment(0, 1)
  let last = text.fragment(2, 3)
  guard text_fragment_bounds(text.object(), first) is Some(first_bounds) &&
    text_fragment_bounds(text.object(), last) is Some(last_bounds) else {
    fail("RTL characters should resolve to glyph geometry")
  }
  assert_true(first_bounds.center().x > last_bounds.center().x)
  assert_eq(text.clusters().map(cluster => cluster.range), [
    { start: 0, end: 1 },
    { start: 1, end: 2 },
    { start: 2, end: 3 },
  ])
}

///|
test "combining marks and ZWJ sequences preserve source character indexing" {
  let text = Text::new("é 👩‍💻")
  assert_eq(text.character_count(), 6)
  assert_eq(text.characters().map(character => character.source), [
    "e", "́", " ", "👩", "‍", "💻",
  ])
  assert_true(
    text
    .clusters()
    .all(cluster => {
      cluster.range.start >= 0 && cluster.range.end <= text.character_count()
    }),
  )
}

///|
test "ellipsized text retains valid source clusters" {
  let text = Text::new(
    "one two three four five",
    layout=TextLayout::new(width=22.0, max_lines=1, ellipsize=EllipsizeEnd),
  )
  assert_eq(text.lines().length(), 1)
  assert_true(
    text
    .clusters()
    .all(cluster => {
      cluster.range.start >= 0 && cluster.range.end <= text.character_count()
    }),
  )
  assert_true(text.object().bounds() is Some(_))
}

///|
test "text specifications and returned clusters do not alias mutable arrays" {
  let spans = [TextSpan::new(0, 1, color=@object.Rgba::red())]
  let spec = TextSpec::new("A", spans~)
  spans.clear()
  let rendered = render_text(spec)
  guard rendered.fragment(0, 1).paths.get(0) is Some(path) &&
    style_at_text_path(rendered.object(), path) is Some(style) else {
    fail("copied span should still style the rendered glyph")
  }
  assert_text_paint(style.fill, @object.Rgba::red())
  let returned = rendered.clusters()
  guard returned.get(0) is Some(cluster) else {
    fail("rendered text should expose at least one cluster")
  }
  cluster.paths.clear()
  assert_true(!rendered.clusters()[0].paths.is_empty())
}

///|
test "transparent runs remain addressable and numeric limits are typed" {
  let transparent = Text::new("A", spans=[
    TextSpan::new(0, 1, color=@object.Rgba::new(r=1.0, g=0.0, b=0.0, a=0.0)),
  ])
  guard transparent.fragment(0, 1).paths.get(0) is Some(path) &&
    style_at_text_path(transparent.object(), path) is Some(style) else {
    fail("transparent glyphs should retain their family identity")
  }
  assert_text_close(style.fill_opacity, 0.0)
  try Text::new("too wide", layout=TextLayout::new(width=3000000.0)) catch {
    InvalidLayout(_) => ()
    error => raise error
  } noraise {
    _ => fail("out-of-range Pango units should be rejected")
  }
  try transparent.set_opacity_by_text("A", 2.0) catch {
    InvalidPresentation(_) => ()
    error => raise error
  } noraise {
    _ => fail("out-of-range opacity should be rejected")
  }
}
