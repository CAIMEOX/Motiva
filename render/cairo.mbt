///|
fn[T] try_cairo(f : () -> T raise @cairoon.CairoError) -> T raise RenderError {
  f() catch {
    error => raise Cairo(error)
  }
}

///|
pub fn CairoRenderer::render(
  self : CairoRenderer,
  snapshot : FrameSnapshot,
) -> RenderedFrame raise RenderError {
  let surface = self.render_surface(snapshot)
  try_cairo(() => surface.flush())
  let data = try_cairo(() => surface.copy_data())
  {
    width: snapshot.camera.pixel_width,
    height: snapshot.camera.pixel_height,
    data,
  }
}

///|
pub fn CairoRenderer::write_png(
  self : CairoRenderer,
  snapshot : FrameSnapshot,
  path : String,
) -> Unit raise RenderError {
  let surface = self.render_surface(snapshot)
  try_cairo(() => surface.write_to_png(path))
}

///|
fn CairoRenderer::render_surface(
  _self : CairoRenderer,
  snapshot : FrameSnapshot,
) -> @cairoon.Surface raise RenderError {
  let camera = snapshot.camera
  let surface = try_cairo(() => {
    @cairoon.Surface::image(Argb32, camera.pixel_width, camera.pixel_height)
  })
  let ctx = try_cairo(() => @cairoon.Context::new(surface))
  paint_background(ctx, camera)
  set_camera_matrix(ctx, camera)
  for item in snapshot.items {
    draw_object(ctx, camera, item.object)
  }
  surface
}

///|
fn paint_background(
  ctx : @cairoon.Context,
  camera : Camera,
) -> Unit raise RenderError {
  try_cairo(() => ctx.save())
  try_cairo(() => ctx.identity_matrix())
  set_source_rgba(ctx, camera.background, 1.0)
  try_cairo(() => ctx.paint())
  try_cairo(() => ctx.restore())
}

///|
fn set_camera_matrix(
  ctx : @cairoon.Context,
  camera : Camera,
) -> Unit raise RenderError {
  let width_scale = camera.pixel_width.to_double() / camera.frame_width
  let height_scale = camera.pixel_height.to_double() / camera.frame_height
  let matrix = @cairoon.Matrix::new(
    xx=width_scale,
    yy=0.0 - height_scale,
    x0=camera.pixel_width.to_double() / 2.0 -
      camera.frame_center.x * width_scale,
    y0=camera.pixel_height.to_double() / 2.0 +
      camera.frame_center.y * height_scale,
  )
  try_cairo(() => ctx.set_matrix(matrix))
}

///|
fn draw_object(
  ctx : @cairoon.Context,
  camera : Camera,
  object : @object.Object,
) -> Unit raise RenderError {
  draw_object_with_transform(ctx, camera, object, object.transform)
}

///|
fn draw_object_with_transform(
  ctx : @cairoon.Context,
  camera : Camera,
  object : @object.Object,
  transform : @object.Transform,
) -> Unit raise RenderError {
  match object.node {
    Empty => ()
    Group(children) =>
      for child in children {
        draw_object_with_transform(
          ctx,
          camera,
          child,
          child.transform.then(transform),
        )
      }
    Path(path, style) => draw_path(ctx, camera, path, style, transform)
  }
}

///|
fn draw_path(
  ctx : @cairoon.Context,
  camera : Camera,
  path : @object.Path3D,
  style : @object.ShapeStyle,
  transform : @object.Transform,
) -> Unit raise RenderError {
  try_cairo(() => ctx.new_path())
  for command in path.commands {
    match command {
      MoveTo(point) => move_to(ctx, transform.apply_point(point))
      LineTo(point) => line_to(ctx, transform.apply_point(point))
      CubicTo(handle1, handle2, anchor) =>
        curve_to(
          ctx,
          transform.apply_point(handle1),
          transform.apply_point(handle2),
          transform.apply_point(anchor),
        )
      Close => try_cairo(() => ctx.close_path())
    }
  }
  apply_style(ctx, camera, style)
  try_cairo(() => ctx.new_path())
}

///|
fn move_to(
  ctx : @cairoon.Context,
  point : @object.Vec3,
) -> Unit raise RenderError {
  try_cairo(() => ctx.move_to(point.x, point.y))
}

///|
fn line_to(
  ctx : @cairoon.Context,
  point : @object.Vec3,
) -> Unit raise RenderError {
  try_cairo(() => ctx.line_to(point.x, point.y))
}

///|
fn curve_to(
  ctx : @cairoon.Context,
  handle1 : @object.Vec3,
  handle2 : @object.Vec3,
  anchor : @object.Vec3,
) -> Unit raise RenderError {
  try_cairo(() => {
    ctx.curve_to(handle1.x, handle1.y, handle2.x, handle2.y, anchor.x, anchor.y)
  })
}

///|
fn apply_style(
  ctx : @cairoon.Context,
  camera : Camera,
  style : @object.ShapeStyle,
) -> Unit raise RenderError {
  match style.fill {
    Some(color) =>
      if style.fill_opacity > 0.0 && color.a > 0.0 {
        set_source_rgba(ctx, color, style.fill_opacity)
        try_cairo(() => ctx.fill_preserve())
      }
    None => ()
  }
  match style.stroke {
    Some(color) =>
      if style.stroke_width > 0.0 && style.stroke_opacity > 0.0 && color.a > 0.0 {
        set_source_rgba(ctx, color, style.stroke_opacity)
        try_cairo(() => {
          ctx.set_line_width(
            style.stroke_width * camera.cairo_line_width_multiple,
          )
        })
        try_cairo(() => ctx.stroke_preserve())
      }
    None => ()
  }
}

///|
fn set_source_rgba(
  ctx : @cairoon.Context,
  color : @object.Rgba,
  opacity : Double,
) -> Unit raise RenderError {
  try_cairo(() => {
    ctx.set_source_rgba(
      clamp01(color.r),
      clamp01(color.g),
      clamp01(color.b),
      clamp01(color.a * opacity),
    )
  })
}

///|
fn clamp01(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}
