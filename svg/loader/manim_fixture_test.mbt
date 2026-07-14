///|
fn path_count(object : @object.Object) -> Int {
  match object.node {
    Empty => 0
    Path(_, _) => 1
    Group(children) =>
      children.fold(init=0, (count, child) => count + path_count(child))
  }
}

///|
fn collect_paths(
  object : @object.Object,
  paths : Array[@object.Object],
) -> Unit {
  match object.node {
    Empty => ()
    Path(_, _) => paths.push(object)
    Group(children) =>
      for child in children {
        collect_paths(child, paths)
      }
  }
}

///|
fn assert_fixture_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(
    Double::abs(actual - expected) < 0.000001,
    msg="expected \{expected}, got \{actual}",
  )
}

///|
async test "SvgLoader parses Manim graphical-unit fixtures" {
  let loader = SvgLoader::new()
  let fixtures = [
    ("A.svg", 1),
    ("aabbb.svg", 7),
    ("arcs02.svg", 15),
    ("path_multiple_moves.svg", 8),
    ("multiple_transforms.svg", 44),
  ]
  for entry in fixtures {
    let (fixture, expected_paths) = entry
    let svg = loader.load("svg/testdata/manim/\{fixture}", center=false) catch {
      _ => fail("failed to parse Manim fixture \{fixture}")
    }
    let object = svg.object()
    assert_true(
      object.bounds() is Some(_),
      msg="\{fixture} should produce finite bounds",
    )
    assert_eq(path_count(object), expected_paths)
    if fixture == "A.svg" {
      guard object.bounds() is Some(bounds) else {
        fail("A.svg should produce finite bounds")
      }
      assert_fixture_close(bounds.min.x, 29.9335938)
      assert_fixture_close(bounds.min.y, -33.339844)
      assert_fixture_close(bounds.max.x, 38.058594)
      assert_fixture_close(bounds.max.y, -23.644532)
    } else if fixture == "multiple_transforms.svg" {
      let paths : Array[@object.Object] = []
      collect_paths(object, paths)
      guard paths.get(4).bind(path => path.bounds()) is Some(bounds) else {
        fail("the first transformed glyph should have bounds")
      }
      let viewport_scale = 4.0 / 3.0
      assert_fixture_close(
        bounds.min.x,
        (70.651477 + 6.59375 * 0.1) * viewport_scale,
      )
      assert_fixture_close(
        bounds.max.x,
        (70.651477 + 56.984375 * 0.1) * viewport_scale,
      )
      assert_fixture_close(
        bounds.min.y,
        (322.182437 - 74.21875 * 0.1) * viewport_scale,
      )
      assert_fixture_close(
        bounds.max.y,
        (322.182437 + 1.421875 * 0.1) * viewport_scale,
      )
    }
  }
}

///|
async test "SvgLoader accepts the complete Manim SVG fixture corpus" {
  let loader = SvgLoader::new()
  let fixtures = [
    "A.svg", "aabbb.svg", "arcs01.svg", "arcs02.svg", "cubic_and_lineto.svg", "cubic_demo.svg",
    "curve.svg", "dash.svg", "desmos-graph_1.svg", "half_ellipse.svg", "heart.svg",
    "inheritance_test.svg", "line.svg", "manim-logo-sidebar.svg", "matrix.svg", "multi_part_path.svg",
    "multiple_transforms.svg", "path_multiple_moves.svg", "penrose.svg", "pixelated_text.svg",
    "qcurve_demo.svg", "rhomboid.svg", "rotate.svg", "scale.svg", "single_state.svg",
    "skewX.svg", "skewY.svg", "smooth_curves.svg", "states_map.svg", "translate.svg",
    "united-kingdom.svg", "video_icon.svg", "watch_the_decimals.svg", "weight.svg",
  ]
  for fixture in fixtures {
    let svg = loader.load("svg/testdata/manim/\{fixture}", center=false) catch {
      _ => fail("failed to parse Manim fixture \{fixture}")
    }
    let object = svg.object()
    assert_true(
      object.bounds() is Some(_),
      msg="\{fixture} should produce finite bounds",
    )
    assert_true(
      path_count(object) > 0,
      msg="\{fixture} should produce at least one path",
    )
  }
}
