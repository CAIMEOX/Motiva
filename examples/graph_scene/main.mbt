///|
using @object {
  into_object,
  type Arrow,
  type Axes,
  type Circle,
  type DashedLine,
  type Object,
  type Rgba,
  type ShapeStyle,
  type Transform,
  type Vec3,
}

///|
using @camera {type Camera}

///|
using @render {type CairoRenderer, type MovieWriter}

///|
using @scene {type Animation, type Scene, type SceneConfig}

///|
fn rgb(r : Double, g : Double, b : Double) -> Rgba {
  Rgba::rgb(r~, g~, b~)
}

///|
fn node_style(fill : Rgba) -> ShapeStyle {
  ShapeStyle::new(
    fill~,
    fill_opacity=0.95,
    stroke=Rgba::white(),
    stroke_width=3.0,
  )
}

///|
fn edge_style(color : Rgba, width? : Double = 4.0) -> ShapeStyle {
  ShapeStyle::stroked(color~, stroke_width=width)
}

///|
fn graph_node(point : Vec3, color : Rgba) -> Object {
  into_object(Circle::new(radius=0.22, style=node_style(color)))
  .move_to(point)
  .with_z_index(2.0)
}

///|
fn edge(start : Vec3, end : Vec3, color : Rgba) -> Object {
  into_object(
    Arrow::new(
      start~,
      end~,
      buff=0.31,
      tip_length=0.22,
      tip_width=0.18,
      style=edge_style(color, width=4.8),
    ),
  ).with_z_index(1.0)
}

///|
fn dashed_edge(start : Vec3, end : Vec3, color : Rgba) -> Object {
  let (trimmed_start, trimmed_end) = trim_edge(start, end, 0.31)
  into_object(
    DashedLine::new(
      start=trimmed_start,
      end=trimmed_end,
      dash_length=0.22,
      dashed_ratio=0.52,
      style=edge_style(color, width=3.0),
    ),
  ).with_z_index(1.0)
}

///|
struct GraphPoints {
  a : Vec3
  b : Vec3
  c : Vec3
  d : Vec3
  e : Vec3
}

///|
fn graph_points() -> GraphPoints {
  {
    a: Vec3::new(x=-4.8, y=1.45),
    b: Vec3::new(x=-3.75, y=2.05),
    c: Vec3::new(x=-2.55, y=1.35),
    d: Vec3::new(x=-3.95, y=0.55),
    e: Vec3::new(x=-2.65, y=0.35),
  }
}

///|
fn directed_graph_nodes() -> Object {
  let blue = rgb(0.22, 0.58, 0.95)
  let green = rgb(0.18, 0.76, 0.44)
  let amber = rgb(0.96, 0.66, 0.18)
  let red = rgb(0.94, 0.28, 0.24)
  let points = graph_points()
  Object::group([
    graph_node(points.a, blue),
    graph_node(points.b, amber),
    graph_node(points.c, green),
    graph_node(points.d, red),
    graph_node(points.e, blue),
  ])
}

///|
fn directed_graph_edges() -> Object {
  let muted = rgb(0.50, 0.62, 0.70)
  let points = graph_points()
  Object::group([
    edge(points.a, points.b, muted),
    edge(points.b, points.c, muted),
    edge(points.a, points.d, muted),
    edge(points.d, points.e, muted),
    edge(points.c, points.e, muted),
    dashed_edge(points.b, points.d, rgb(0.78, 0.78, 0.82)),
  ])
}

///|
fn tree_edge(parent : Vec3, child : Vec3) -> Object {
  edge(parent, child, rgb(0.58, 0.68, 0.76))
}

///|
struct TreePoints {
  root : Vec3
  left : Vec3
  right : Vec3
  ll : Vec3
  lr : Vec3
  rl : Vec3
  rr : Vec3
}

///|
fn tree_points() -> TreePoints {
  {
    root: Vec3::new(x=2.95, y=2.05),
    left: Vec3::new(x=1.65, y=1.05),
    right: Vec3::new(x=4.25, y=1.05),
    ll: Vec3::new(x=0.95, y=-0.05),
    lr: Vec3::new(x=2.35, y=-0.05),
    rl: Vec3::new(x=3.55, y=-0.05),
    rr: Vec3::new(x=4.95, y=-0.05),
  }
}

///|
fn binary_tree_nodes() -> Object {
  let points = tree_points()
  let root_color = rgb(0.83, 0.38, 0.92)
  let branch_color = rgb(0.28, 0.66, 0.88)
  let leaf_color = rgb(0.20, 0.75, 0.48)
  Object::group([
    graph_node(points.root, root_color),
    graph_node(points.left, branch_color),
    graph_node(points.right, branch_color),
    graph_node(points.ll, leaf_color),
    graph_node(points.lr, leaf_color),
    graph_node(points.rl, leaf_color),
    graph_node(points.rr, leaf_color),
  ])
}

///|
fn binary_tree_edges() -> Object {
  let points = tree_points()
  Object::group([
    tree_edge(points.root, points.left),
    tree_edge(points.root, points.right),
    tree_edge(points.left, points.ll),
    tree_edge(points.left, points.lr),
    tree_edge(points.right, points.rl),
    tree_edge(points.right, points.rr),
  ])
}

///|
fn plot_panel() -> Object {
  let axes = Axes::new(
    x_min=-3.0,
    x_max=3.0,
    x_step=1.0,
    y_min=-1.5,
    y_max=1.5,
    y_step=0.75,
    x_length=5.4,
    y_length=2.1,
    tick_size=0.08,
    style=edge_style(rgb(0.74, 0.78, 0.84), width=1.8),
  )
  let wave = axes.plot(
    x => @math.sin(x),
    step=0.06,
    style=edge_style(rgb(1.0, 0.82, 0.20), width=4.0),
  )
  let bowl = axes.plot(
    x => 0.22 * x * x - 0.95,
    step=0.06,
    style=edge_style(rgb(0.20, 0.78, 0.92), width=3.0),
  )
  Object::group([into_object(axes), into_object(wave), into_object(bowl)]).with_transform(
    Transform::translate(Vec3::new(x=0.0, y=-1.95)),
  )
}

///|
fn node_layer() -> Object {
  Object::group([directed_graph_nodes(), binary_tree_nodes()])
}

///|
fn edge_layer() -> Object {
  Object::group([directed_graph_edges(), binary_tree_edges()])
}

///|
fn trim_edge(start : Vec3, end : Vec3, buff : Double) -> (Vec3, Vec3) {
  let direction = end.sub(start)
  let length = direction.length()
  if length <= 2.0 * buff || length.is_nan() {
    (start, end)
  } else {
    let unit = direction.scale(1.0 / length)
    (start.add(unit.scale(buff)), end.sub(unit.scale(buff)))
  }
}

///|
async fn animate() -> Unit {
  let frame_prefix = "graph_scene_720p60"
  let frame_dir = "output/frames"
  let movie_path = "output/graph_scene_720p60.mp4"
  let scene = Scene::new(
    config=SceneConfig::new(frame_rate=60),
    camera=Camera::new(
      pixel_width=1280,
      pixel_height=720,
      frame_width=10.8,
      background=Rgba::black(),
    ),
  )
  let writer = MovieWriter::mp4(
    renderer=CairoRenderer::new(),
    output_dir=frame_dir,
    frame_prefix~,
    frame_padding=4,
    frame_rate=60,
    movie_path~,
  )
  writer.attach(scene)
  let nodes = scene.object(node_layer())
  let edges = scene.object(edge_layer())
  let plot = scene.object(plot_panel())
  scene.play([
    Animation::draw_border_then_fill(nodes, run_time=1.0, rate_func=Smooth),
  ])
  scene.play([Animation::create(edges, run_time=1.35, rate_func=Smooth)])
  scene.play([
    Animation::draw_border_then_fill(plot, run_time=1.0, rate_func=Smooth),
  ])
  scene.play([
    Animation::group(
      [
        nodes
        .animate(run_time=1.2, rate_func=ThereAndBack)
        .scale(sx=1.04, sy=1.04, about_point=Vec3::zero()),
        edges
        .animate(run_time=1.2, rate_func=ThereAndBack)
        .scale(sx=1.04, sy=1.04, about_point=Vec3::zero()),
        plot
        .animate(run_time=1.2, rate_func=ThereAndBack)
        .scale(sx=1.04, sy=1.04, about_point=Vec3::zero()),
      ],
      run_time=1.2,
    ),
  ])
  writer.finish()
  println(
    "wrote \{writer.frame_count()} frames to \{frame_dir}/\{frame_prefix}_*.png and \{movie_path}",
  )
}

///|
async fn main {
  animate()
}
