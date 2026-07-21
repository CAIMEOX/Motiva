///|
priv enum MathTexStyleOp {
  ColorPart(String, @object.Rgba)
  OpacityPart(String, Double)
  OpacityAll(Double)
}

///|
pub struct MathTex {
  priv svg : @svg.SvgObject
  priv part_index : Array[TexPart]
  priv font_size : Double
  priv color : @object.Rgba
  priv style_ops : Array[MathTexStyleOp]
}

///|
pub async fn TexEngine::math_tex(
  self : TexEngine,
  tex_strings : Array[String],
  arg_separator? : String = " ",
  substrings_to_isolate? : Array[String] = [],
  environment? : String = "align*",
  font_size? : Double = 48.0,
  color? : @object.Rgba = @object.Rgba::white(),
) -> MathTex raise TexError {
  if font_size <= 0.0 || font_size.is_nan() || font_size.is_inf() {
    raise InvalidFontSize(font_size)
  }
  let prepared = prepare_math_source(
    tex_strings,
    arg_separator,
    substrings_to_isolate~,
  )
  let svg = self.compile_svg(prepared.expression, environment~)
  { svg, part_index: prepared.parts, font_size, color, style_ops: [] }
}

///|
pub fn MathTex::parts(self : MathTex) -> Array[String] {
  self.part_index
  .iter()
  .filter(part => part.kind is Main)
  .map(part => part.source)
  .to_array()
}

///|
pub fn MathTex::fragments(
  self : MathTex,
  kind? : TexFragmentKind,
) -> Array[TexFragment] {
  let fragments : Array[TexFragment] = []
  let mut fragment_index = 0
  for part in self.part_index {
    for path in self.svg.group_paths(part.id) {
      let fragment = {
        tex_string: part.source,
        kind: part.kind,
        path,
        index: fragment_index,
      }
      if kind.map_or(true, expected => expected == fragment.kind) {
        fragments.push(fragment)
      }
      fragment_index = fragment_index + 1
    }
  }
  fragments
}

///|
pub fn MathTex::fragment(self : MathTex, index : Int) -> TexFragment? {
  for fragment in self.fragments() {
    if fragment.index == index {
      return Some(fragment)
    }
  }
  None
}

///|
pub fn MathTex::fragments_by_tex(
  self : MathTex,
  tex : String,
  kind? : TexFragmentKind,
) -> Array[TexFragment] {
  self.fragments(kind?).filter(fragment => fragment.tex_string == tex)
}

///|
pub fn MathTex::part_paths(
  self : MathTex,
  tex : String,
) -> Array[@object.FamilyPath] {
  self.fragments_by_tex(tex).map(fragment => fragment.path)
}

///|
pub fn MathTex::svg_object(self : MathTex) -> @svg.SvgObject {
  self.svg.copy()
}

///|
pub fn MathTex::set_color_by_tex(
  self : MathTex,
  tex : String,
  color : @object.Rgba,
) -> MathTex {
  let style_ops = self.style_ops.copy()
  style_ops.push(ColorPart(tex, color))
  { ..self, style_ops, }
}

///|
pub fn MathTex::set_opacity_by_tex(
  self : MathTex,
  tex : String,
  opacity? : Double = 0.5,
  remaining_opacity? : Double,
) -> MathTex {
  let style_ops = self.style_ops.copy()
  match remaining_opacity {
    Some(opacity) => style_ops.push(OpacityAll(opacity))
    None => ()
  }
  style_ops.push(OpacityPart(tex, opacity))
  { ..self, style_ops, }
}

///|
pub fn MathTex::object(self : MathTex) -> @object.Object {
  let mut object = recolor_default_tex(self.svg.object(), self.color)
  let scale = math_tex_font_scale(self.font_size)
  object = {
    ..object,
    transform: object.transform.then(
      @object.Transform::scale(sx=scale, sy=scale),
    ),
  }
  for style_op in self.style_ops {
    match style_op {
      OpacityAll(_) => object = apply_math_style(object, style_op)
      ColorPart(tex, _) | OpacityPart(tex, _) =>
        for path in self.part_paths(tex) {
          object = apply_math_style_at_path(object, path.indices(), 0, style_op)
        }
    }
  }
  object
}

///|
fn math_tex_font_scale(font_size : Double) -> Double {
  let scene_units_per_font_point = 1.0 / 960.0
  let svg_units_per_point = 96.0 / 72.0
  font_size * scene_units_per_font_point / svg_units_per_point
}

///|
pub fn MathTex::copy(self : MathTex) -> MathTex {
  {
    svg: self.svg.copy(),
    part_index: self.part_index.copy(),
    font_size: self.font_size,
    color: self.color,
    style_ops: self.style_ops.copy(),
  }
}

///|
pub impl @object.IntoObject for MathTex with fn to_object(self : MathTex) -> @object.Object {
  self.object()
}

///|
fn recolor_default_tex(
  object : @object.Object,
  replacement : @object.Rgba,
) -> @object.Object {
  let node = match object.node {
    Empty => @object.Empty
    Group(children) =>
      Group(children.map(child => recolor_default_tex(child, replacement)))
    Path(path, style) =>
      Path(path, {
        ..style,
        fill: replace_black(style.fill, replacement),
        stroke: replace_black(style.stroke, replacement),
        stroke_width: 0.0,
      })
    Mesh(mesh, style) =>
      Mesh(mesh, {
        ..style,
        fill: replace_black(style.fill, replacement),
        stroke: replace_black(style.stroke, replacement),
        stroke_width: 0.0,
      })
  }
  { ..object, node, }
}

///|
fn replace_black(
  paint : @object.Rgba?,
  replacement : @object.Rgba,
) -> @object.Rgba? {
  paint.map(color => {
    if color.r == 0.0 && color.g == 0.0 && color.b == 0.0 {
      { ..replacement, a: replacement.a * color.a }
    } else {
      color
    }
  })
}

///|
fn apply_math_style_at_path(
  object : @object.Object,
  indices : Array[Int],
  depth : Int,
  operation : MathTexStyleOp,
) -> @object.Object {
  if depth == indices.length() {
    return apply_math_style(object, operation)
  }
  match object.node {
    Group(children) =>
      match children.get(indices[depth]) {
        None => object
        Some(child) => {
          let next = children.copy()
          next[indices[depth]] = apply_math_style_at_path(
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

///|
fn apply_math_style(
  object : @object.Object,
  operation : MathTexStyleOp,
) -> @object.Object {
  match operation {
    ColorPart(_, color) => object.set_color(color)
    OpacityPart(_, opacity) | OpacityAll(opacity) =>
      object.set_fill(opacity~).set_stroke(opacity~)
  }
}
