///|
test "MathTex double braces split main parts like Manim" {
  assert_eq(prepare_math_parts(["{{x}} + {{y}} = {{z}}"]), [
    "x", " + ", "y", " = ", "z",
  ])
  assert_eq(prepare_math_parts(["left", "right"]), ["left", "right"])
}

///|
test "MathTex splitting preserves ordinary nested and escaped LaTeX braces" {
  assert_eq(split_double_braces("\\frac{{{n}}}{k}"), ["\\frac{{{n}}}{k}"])
  assert_eq(split_double_braces("a^{{2}}"), ["a^{{2}}"])
  assert_eq(split_double_braces("{{ a^{b^{c}} }} + \\{literal\\}"), [
    "", " a^{b^{c}} ", " + \\{literal\\}",
  ])
}

///|
test "TexTemplate renders math inside the requested environment" {
  let document = TexTemplate::new().render("x^2 + y^2", environment="align*")
  assert_true(document.contains("\\documentclass[preview]{standalone}"))
  assert_true(document.contains("\\usepackage{amsmath}"))
  assert_true(document.contains("\\begin{align*}"))
  assert_true(document.contains("x^2 + y^2"))
  assert_true(document.contains("\\end{align*}"))
  assert_true(document.contains("\\end{document}"))
}

///|
test "MathTex substring isolation wraps every match without changing TeX" {
  let prepared = prepare_math_source(["x+y+x"], " ", substrings_to_isolate=["x"])
  assert_true(prepared.expression.contains("motiva-main-0"))
  assert_true(prepared.expression.contains("motiva-sub-0"))
  assert_true(prepared.expression.contains("motiva-sub-1"))
  assert_eq(prepared.parts.map(part => part.source), ["x+y+x", "x", "x"])
}

///|
fn object_at_family_path(
  object : @object.Object,
  path : @object.FamilyPath,
) -> @object.Object? {
  path
  .indices()
  .fold(init=Some(object), (current, index) => {
    current.bind(object => {
      match object.node {
        Group(children) => children.get(index)
        _ => None
      }
    })
  })
}

///|
fn first_path_style(object : @object.Object) -> @object.ShapeStyle? {
  match object.node {
    Empty => None
    Path(_, style) => Some(style)
    Mesh(_, _) => None
    Group(children) => children.iter().filter_map(first_path_style).next()
  }
}

///|
async test "TexEngine compiles queryable MathTex through dvisvgm" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  @async.with_task_group() <| root => {
    let cache_dir = "_build/tex_integration_test"
    if @fs.exists(cache_dir) {
      @fs.rmdir(cache_dir, recursive=true)
    }
    root.add_defer(() => @fs.rmdir(cache_dir, recursive=true))
    let engine = TexEngine::new(latex~, dvisvgm~, cache_dir~)
    let formula = engine.math_tex(["{{x}} + {{y}}"])
    assert_eq(formula.parts(), ["x", " + ", "y"])
    assert_true(formula.object().bounds() is Some(_))
    guard formula.part_paths("x") is [x_path] else {
      fail("the x fragment should resolve to one SVG family path")
    }
    guard formula.part_paths("y") is [y_path] else {
      fail("the y fragment should resolve to one SVG family path")
    }
    let scene = @scene.Scene::new()
    let formula_id = scene.object(formula.copy())
    let x_id = scene.resolve_family_path(formula_id, x_path)
    assert_true(scene.get(x_id) is Some(_))
    let colored = formula.set_color_by_tex("x", @object.Rgba::red())
    guard object_at_family_path(colored.object(), x_path).bind(first_path_style)
      is Some(x_style) &&
      x_style.fill is Some(x_fill) else {
      fail("the colored x fragment should contain a filled path")
    }
    guard object_at_family_path(colored.object(), y_path).bind(first_path_style)
      is Some(y_style) &&
      y_style.fill is Some(y_fill) else {
      fail("the uncolored y fragment should contain a filled path")
    }
    assert_eq(x_fill.r, 1.0)
    assert_eq(x_fill.g, 0.0)
    assert_eq(y_fill.r, 1.0)
    assert_eq(y_fill.g, 1.0)
    assert_eq(x_style.stroke_width, 0.0)
    assert_eq(y_style.stroke_width, 0.0)
    let faded = formula.set_opacity_by_tex(
      "x",
      opacity=0.25,
      remaining_opacity=0.1,
    )
    guard object_at_family_path(faded.object(), x_path).bind(first_path_style)
      is Some(faded_x_style) else {
      fail("the faded x fragment should contain a path")
    }
    guard object_at_family_path(faded.object(), y_path).bind(first_path_style)
      is Some(faded_y_style) else {
      fail("the faded y fragment should contain a path")
    }
    assert_eq(faded_x_style.fill_opacity, 0.25)
    assert_eq(faded_y_style.fill_opacity, 0.1)
    let isolated = engine.math_tex(["x+y+x"], substrings_to_isolate=["x"])
    assert_eq(isolated.part_paths("x").length(), 2)
  }
}

///|
async test "MathTex font size compensates for SVG point units" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  @async.with_task_group() <| root => {
    let cache_dir = "_build/tex_unit_scale_test"
    if @fs.exists(cache_dir) {
      @fs.rmdir(cache_dir, recursive=true)
    }
    root.add_defer(() => @fs.rmdir(cache_dir, recursive=true))
    let formula = TexEngine::new(latex~, dvisvgm~, cache_dir~).math_tex(
      ["x"],
      font_size=48.0,
    )
    guard formula.svg_object().object().bounds() is Some(svg_bounds) &&
      formula.object().bounds() is Some(math_bounds) else {
      fail("compiled MathTex should have SVG and scene bounds")
    }
    assert_tex_close(math_bounds.width() / svg_bounds.width(), 48.0 / 1280.0)
  }
}

///|
async test "MathTex fragments distinguish main and isolated matches" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  @async.with_task_group() <| root => {
    let cache_dir = "_build/tex_fragment_test"
    if @fs.exists(cache_dir) {
      @fs.rmdir(cache_dir, recursive=true)
    }
    root.add_defer(() => @fs.rmdir(cache_dir, recursive=true))
    let formula = TexEngine::new(latex~, dvisvgm~, cache_dir~).math_tex(
      ["{{x}} + {{y}}"],
      substrings_to_isolate=["x"],
    )
    let main_x = formula.fragments_by_tex("x", kind=Main)
    let isolated_x = formula.fragments_by_tex("x", kind=Isolated)
    guard (main_x, isolated_x) is ([main], [isolated]) else {
      fail("x should have one main and one isolated fragment")
    }
    assert_eq(main.tex_string, "x")
    assert_true(main.kind is Main)
    assert_true(isolated.kind is Isolated)
    assert_true(main.path != isolated.path)
    assert_eq(formula.fragments(kind=Main).length(), 3)
    assert_true(isolated.index > main.index)
    assert_true(
      formula.fragment(main.index).map_or(false, found => found == main),
    )
    assert_true(
      formula.fragment(isolated.index).map_or(false, found => found == isolated),
    )
  }
}

///|
async test "TransformMatchingTex matches main fragments and replaces the formula" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  @async.with_task_group() <| root => {
    let cache_dir = "_build/transform_matching_tex_test"
    if @fs.exists(cache_dir) {
      @fs.rmdir(cache_dir, recursive=true)
    }
    root.add_defer(() => @fs.rmdir(cache_dir, recursive=true))
    let engine = TexEngine::new(latex~, dvisvgm~, cache_dir~)
    let source = engine.math_tex(["A", "+", "B"])
    let target = engine.math_tex(["B", "-", "A"])
    let scene = @scene.Scene::new(
      config=@scene.SceneConfig::new(frame_rate=20.0),
    )
    let source_root = scene.add(source.copy())
    guard source.fragments_by_tex("A", kind=Main) is [source_a] &&
      target.fragments_by_tex("A", kind=Main) is [target_a] else {
      fail("both formulas should expose one main A fragment")
    }
    let source_a_id = scene.resolve_family_path(source_root, source_a.path)
    guard scene.get(source_a_id) is Some(source_a_object) else {
      fail("source A should exist before matching")
    }
    let transition = TransformMatchingTex::new(
      scene,
      source_root,
      source,
      target,
      run_time=1.0,
    )
    let target_root = transition.target_id()
    let target_a_id = scene.resolve_family_path(target_root, target_a.path)
    guard scene.get(target_a_id) is Some(target_a_object) else {
      fail("target A should be allocated before matching")
    }
    assert_true(scene.state(target_root) is Some(Allocated))
    let plan = scene.compile_play_plan(
      [transition],
      config=@scene.PlayConfig::image_sequence(),
    )
    plan.begin(scene)
    plan.apply_frame(scene, {
      frame_index: 10,
      play_time: 0.5,
      absolute_time: 0.5,
      dt: 0.5,
    })
    guard scene.get(source_a_id) is Some(sampled_a) else {
      fail("matched source A should remain present during interpolation")
    }
    assert_tex_close(
      sampled_a.center().x,
      (source_a_object.center().x + target_a_object.center().x) / 2.0,
    )
    plan.finish(scene)
    assert_true(!scene.is_visible(source_root))
    assert_true(scene.is_visible(target_root))
  }
}

///|
async test "TransformMatchingTex key map accepts fragments with different topology" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  @async.with_task_group() <| root => {
    let cache_dir = "_build/transform_matching_tex_key_map_test"
    if @fs.exists(cache_dir) {
      @fs.rmdir(cache_dir, recursive=true)
    }
    root.add_defer(() => @fs.rmdir(cache_dir, recursive=true))
    let engine = TexEngine::new(latex~, dvisvgm~, cache_dir~)
    let source = engine.math_tex(["x"])
    let target = engine.math_tex(["\\frac{1}{y}"])
    let scene = @scene.Scene::new()
    let source_root = scene.add(source.copy())
    let key_map : Map[String, String] = { "x": "\\frac{1}{y}" }
    let transition = TransformMatchingTex::new(
      scene,
      source_root,
      source,
      target,
      key_map~,
    )
    let target_root = transition.target_id()
    let plan = scene.compile_play_plan([transition])
    plan.begin(scene)
    plan.finish(scene)
    assert_true(!scene.is_visible(source_root))
    assert_true(scene.is_visible(target_root))
  }
}

///|
async test "TexEngine reports compiler failures as TexError" {
  let cache_dir = "_build/tex_failure_test"
  if @fs.exists(cache_dir) {
    @fs.rmdir(cache_dir, recursive=true)
  }
  let engine = TexEngine::new(
    latex="/usr/bin/false",
    dvisvgm="/usr/bin/false",
    cache_dir~,
  )
  let result : Result[MathTex, TexError] = try engine.math_tex(["x"]) catch {
    error => Err(error)
  } noraise {
    formula => Ok(formula)
  }
  if @fs.exists(cache_dir) {
    @fs.rmdir(cache_dir, recursive=true)
  }
  assert_true(result is Err(CompilerFailed(binary="/usr/bin/false", ..)))
}

///|
async test "MathTex rejects a non-positive font size before compilation" {
  let engine = TexEngine::new(latex="/usr/bin/false")
  let result : Result[MathTex, TexError] = try
    engine.math_tex(["x"], font_size=0.0)
  catch {
    error => Err(error)
  } noraise {
    formula => Ok(formula)
  }
  assert_true(result is Err(InvalidFontSize(0.0)))
}

///|
async test "animating MathTex siblings preserves every visible glyph leaf" {
  let latex = "/Library/TeX/texbin/latex"
  let dvisvgm = "/Library/TeX/texbin/dvisvgm"
  if !@fs.exists(latex) || !@fs.exists(dvisvgm) {
    return
  }
  let engine = TexEngine::new(
    latex~,
    dvisvgm~,
    cache_dir="_build/tex_scene_test",
  )
  let formula = engine.math_tex(["a^2", "+", "b^2", "=", "c^2"])
  guard (
      formula.part_paths("a^2"),
      formula.part_paths("+"),
      formula.part_paths("b^2"),
      formula.part_paths("="),
      formula.part_paths("c^2"),
    )
    is ([a_path], [plus_path], [b_path], [equals_path], [c_path]) else {
    fail("formula fragments should each expose one family path")
  }
  let scene = @scene.Scene::new(config=@scene.SceneConfig::new(frame_rate=20.0))
  let root = scene.object(formula.object())
  let a = scene.resolve_family_path(root, a_path)
  let plus = scene.resolve_family_path(root, plus_path)
  let b = scene.resolve_family_path(root, b_path)
  let equals = scene.resolve_family_path(root, equals_path)
  let c = scene.resolve_family_path(root, c_path)
  let create_plan = scene.compile_play_plan(
    [
      @scene.Animation::lagged_start(
        [a, plus, b, equals, c].map(id => @scene.Animation::create(id)),
        run_time=2.0,
        lag_ratio=0.18,
      ),
    ],
    config=@scene.PlayConfig::image_sequence(),
  )
  create_plan.begin(scene)
  for frame in create_plan.frame_times() {
    create_plan.apply_frame(scene, frame)
  }
  create_plan.finish(scene)
  let initial = visible_path_count(scene)
  guard scene.get(plus).bind(object => object.bounds()) is Some(plus_bounds) else {
    fail("the plus fragment should have bounds")
  }
  guard scene.get(plus).bind(first_path_style) is Some(plus_style) &&
    plus_style.fill is Some(plus_fill) else {
    fail("the plus fragment should have a fill style")
  }
  let plan = scene.compile_play_plan(
    [
      @scene.Animation::group(
        [
          a
          .animate(run_time=1.3, rate_func=@scene.ThereAndBack)
          .set_color(@object.Rgba::red())
          .scale(sx=1.25, sy=1.25),
          b
          .animate(run_time=1.3, rate_func=@scene.ThereAndBack)
          .set_color(@object.Rgba::blue())
          .scale(sx=1.25, sy=1.25),
          c
          .animate(run_time=1.3, rate_func=@scene.ThereAndBack)
          .set_color(@object.Rgba::green())
          .scale(sx=1.25, sy=1.25),
        ],
        run_time=2.2,
        lag_ratio=0.2,
        rate_func=@scene.Smooth,
      ),
    ],
    config=@scene.PlayConfig::image_sequence(),
  )
  plan.begin(scene)
  for frame in plan.frame_times() {
    plan.apply_frame(scene, frame)
    assert_eq(visible_path_count(scene), initial)
    guard scene.get(plus).bind(object => object.bounds()) is Some(sampled_plus) else {
      fail("the unanimated plus fragment should retain bounds")
    }
    assert_tex_close(sampled_plus.min.x, plus_bounds.min.x)
    assert_tex_close(sampled_plus.min.y, plus_bounds.min.y)
    assert_tex_close(sampled_plus.max.x, plus_bounds.max.x)
    assert_tex_close(sampled_plus.max.y, plus_bounds.max.y)
    guard scene.get(plus).bind(first_path_style) is Some(sampled_style) &&
      sampled_style.fill is Some(sampled_fill) else {
      fail("the unanimated plus fragment should retain its fill style")
    }
    assert_tex_close(sampled_fill.r, plus_fill.r)
    assert_tex_close(sampled_fill.g, plus_fill.g)
    assert_tex_close(sampled_fill.b, plus_fill.b)
    assert_tex_close(sampled_style.fill_opacity, plus_style.fill_opacity)
  }
  plan.finish(scene)
}

///|
fn visible_path_count(scene : @scene.Scene) -> Int raise @scene.SceneError {
  let mut count = 0
  for root in scene.visible_objects() {
    for id in scene.family(root) {
      if scene.is_visible(id) &&
        scene.get(id).map_or(false, object => object.node is @object.Path(_, _)) {
        count = count + 1
      }
    }
  }
  count
}

///|
fn assert_tex_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}
