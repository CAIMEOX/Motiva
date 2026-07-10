///|
fn assert_graphing_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(Double::abs(actual - expected) < 0.000001)
}

///|
fn assert_graphing_point_close(actual : Vec3, expected : Vec3) -> Unit raise {
  assert_graphing_close(actual.x, expected.x)
  assert_graphing_close(actual.y, expected.y)
  assert_graphing_close(actual.z, expected.z)
}

///|
test "dashed line splits a line into visible dash segments" {
  let dashed = DashedLine::new(
    start=Vec3::new(x=0.0, y=0.0),
    end=Vec3::new(x=2.0, y=0.0),
    dash_length=0.5,
    dashed_ratio=0.5,
  )
  let dashes = dashed.dashes()
  assert_eq(dashes.length(), 2)
  guard dashes is [first, second] else {
    fail("dashed line should create two dash segments")
  }
  assert_graphing_point_close(first.start, Vec3::new(x=0.0, y=0.0))
  assert_graphing_point_close(first.end, Vec3::new(x=0.5, y=0.0))
  assert_graphing_point_close(second.start, Vec3::new(x=1.0, y=0.0))
  assert_graphing_point_close(second.end, Vec3::new(x=1.5, y=0.0))
}

///|
test "arrow lowers to a shaft and filled triangular tip" {
  let arrow = Arrow::new(
    start=Vec3::new(x=-1.0, y=0.0),
    end=Vec3::new(x=1.0, y=0.0),
    buff=0.25,
  )
  let object = into_object(arrow)
  guard object.node is Group([shaft, tip]) else {
    fail("arrow should lower to a two child group")
  }
  guard shaft.node is Path(path, _) else {
    fail("arrow shaft should be a path")
  }
  guard path.commands is [MoveTo(start), LineTo(end)] else {
    fail("arrow shaft should be one line segment")
  }
  assert_graphing_point_close(start, Vec3::new(x=-0.75, y=0.0))
  assert_graphing_point_close(end, Vec3::new(x=0.4, y=0.0))
  guard tip.node is Path(_, style) else { fail("arrow tip should be a path") }
  guard style.fill is Some(fill) else { fail("arrow tip should be filled") }
  assert_graphing_close(fill.r, 1.0)
}

///|
test "number line maps numbers into local points and emits ticks" {
  let line = NumberLine::new(x_min=-2.0, x_max=2.0, x_step=1.0, length=8.0)
  assert_graphing_point_close(
    line.number_to_point(-2.0),
    Vec3::new(x=-4.0, y=0.0),
  )
  assert_graphing_point_close(line.number_to_point(0.0), Vec3::zero())
  assert_graphing_point_close(
    line.number_to_point(2.0),
    Vec3::new(x=4.0, y=0.0),
  )
  assert_graphing_close(line.point_to_number(Vec3::new(x=2.0, y=0.0)), 1.0)
  assert_eq(line.tick_values().length(), 5)
}

///|
test "axes map coordinates and lower to two number lines" {
  let axes = Axes::new(
    x_min=-2.0,
    x_max=2.0,
    y_min=-1.0,
    y_max=1.0,
    x_length=8.0,
    y_length=4.0,
  )
  assert_graphing_point_close(axes.coords_to_point(0.0, 0.0), Vec3::zero())
  assert_graphing_point_close(
    axes.coords_to_point(2.0, 1.0),
    Vec3::new(x=4.0, y=2.0),
  )
  let (x, y) = axes.point_to_coords(Vec3::new(x=-4.0, y=-2.0))
  assert_graphing_close(x, -2.0)
  assert_graphing_close(y, -1.0)
  guard into_object(axes).node is Group([_, _]) else {
    fail("axes should lower to x and y number line children")
  }
}

///|
test "function graph and parametric function sample into path commands" {
  let graph = FunctionGraph::new(x => x * x, x_min=0.0, x_max=1.0, step=0.5)
  guard graph.path().commands is [MoveTo(start), LineTo(mid), LineTo(end)] else {
    fail("function graph should sample start, middle, and end")
  }
  assert_graphing_point_close(start, Vec3::new(x=0.0, y=0.0))
  assert_graphing_point_close(mid, Vec3::new(x=0.5, y=0.25))
  assert_graphing_point_close(end, Vec3::new(x=1.0, y=1.0))
  let curve = ParametricFunction::new(
    t => Vec3::new(x=@math.cos(t), y=@math.sin(t)),
    t_min=0.0,
    t_max=@math.PI,
    step=@math.PI / 2.0,
  )
  assert_eq(curve.path().commands.length(), 3)
}
