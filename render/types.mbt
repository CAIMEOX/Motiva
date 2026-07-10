///|
pub(all) suberror RenderError {
  Cairo(@cairoon.CairoError)
  Ffmpeg(@ffmpeg.FfmpegError)
  Scene(@scene.SceneError)
  MissingObject(@scene.ObjectId)
  OutputFrameCountMismatch(expected~ : Int, actual~ : Int)
}

///|
pub(all) struct Camera {
  pixel_width : Int
  pixel_height : Int
  frame_width : Double
  frame_height : Double
  frame_center : @object.Vec3
  background : @object.Rgba
  cairo_line_width_multiple : Double
}

///|
pub fn Camera::new(
  pixel_width? : Int = 1280,
  pixel_height? : Int = 720,
  frame_width? : Double,
  frame_height? : Double,
  frame_center? : @object.Vec3 = @object.Vec3::zero(),
  background? : @object.Rgba = @object.Rgba::black(),
  cairo_line_width_multiple? : Double = 0.01,
) -> Camera {
  let (frame_width, frame_height) = resolve_frame_size(
    pixel_width, pixel_height, frame_width, frame_height,
  )
  {
    pixel_width,
    pixel_height,
    frame_width,
    frame_height,
    frame_center,
    background,
    cairo_line_width_multiple,
  }
}

///|
pub impl Default for Camera with fn default() -> Camera {
  Camera::new()
}

///|
fn resolve_frame_size(
  pixel_width : Int,
  pixel_height : Int,
  frame_width : Double?,
  frame_height : Double?,
) -> (Double, Double) {
  let default_frame_height = 8.0
  let aspect = pixel_width.to_double() / pixel_height.to_double()
  match (frame_width, frame_height) {
    (None, None) => (default_frame_height * aspect, default_frame_height)
    (Some(width), None) => (width, width / aspect)
    (None, Some(height)) => (height * aspect, height)
    (Some(width), Some(height)) => (width, height)
  }
}

///|
pub(all) enum RenderLayer {
  Main
  Foreground
} derive(Eq)

///|
pub(all) struct RenderItem {
  id : @scene.ObjectId
  object : @object.Object
  layer : RenderLayer
}

///|
pub(all) struct FrameSnapshot {
  time : Double
  frame_index : Int
  camera : Camera
  items : Array[RenderItem]
}

///|
pub fn FrameSnapshot::from_scene(
  scene : @scene.Scene,
  camera? : Camera = Camera::default(),
  frame_index? : Int = 0,
) -> FrameSnapshot raise RenderError {
  let foreground_roots = scene.foreground_objects()
  let foreground_ids = collect_family_ids(scene, foreground_roots)
  let main_items : Array[RenderItem] = []
  let foreground_items : Array[RenderItem] = []
  let main_ids : Set[@scene.ObjectId] = Set([])
  for root in scene.visible_objects() {
    push_family_items(
      main_items,
      main_ids,
      scene,
      root,
      Main,
      excluded=foreground_ids,
    )
  }
  let rendered_foreground_ids : Set[@scene.ObjectId] = Set([])
  let no_exclusions : Set[@scene.ObjectId] = Set([])
  for root in foreground_roots {
    push_family_items(
      foreground_items,
      rendered_foreground_ids,
      scene,
      root,
      Foreground,
      excluded=no_exclusions,
    )
  }
  main_items.append(foreground_items)
  { time: scene.time(), frame_index, camera, items: main_items }
}

///|
fn collect_family_ids(
  scene : @scene.Scene,
  roots : Array[@scene.ObjectId],
) -> Set[@scene.ObjectId] raise RenderError {
  let ids : Set[@scene.ObjectId] = Set([])
  for root in roots {
    for id in try_scene(() => scene.family(root)) {
      ids.add(id)
    }
  }
  ids
}

///|
fn push_family_items(
  items : Array[RenderItem],
  rendered_ids : Set[@scene.ObjectId],
  scene : @scene.Scene,
  root : @scene.ObjectId,
  layer : RenderLayer,
  excluded~ : Set[@scene.ObjectId],
) -> Unit raise RenderError {
  for id in try_scene(() => scene.family(root)) {
    if scene.is_visible(id) &&
      !excluded.contains(id) &&
      !rendered_ids.contains(id) {
      match scene.get(id) {
        None => raise MissingObject(id)
        Some({ node: Path(_, _), .. } as object) => {
          push_z_sorted(items, { id, object, layer })
          rendered_ids.add(id)
        }
        Some(_) => ()
      }
    }
  }
}

///|
fn push_z_sorted(items : Array[RenderItem], item : RenderItem) -> Unit {
  match
    items.search_by(current => item.object.z_index < current.object.z_index) {
    Some(index) => items.insert(index, item)
    None => items.push(item)
  }
}

///|
pub(all) struct RenderedFrame {
  width : Int
  height : Int
  data : Bytes
}

///|
pub fn RenderedFrame::byte_length(self : RenderedFrame) -> Int {
  self.data.length()
}

///|
pub(all) struct CairoRenderer {
  camera : Camera
}

///|
pub fn CairoRenderer::new(
  camera? : Camera = Camera::default(),
) -> CairoRenderer {
  { camera, }
}

///|
pub fn CairoRenderer::snapshot(
  self : CairoRenderer,
  scene : @scene.Scene,
  frame_index? : Int = 0,
) -> FrameSnapshot raise RenderError {
  FrameSnapshot::from_scene(scene, camera=self.camera, frame_index~)
}

///|
pub fn CairoRenderer::render_scene(
  self : CairoRenderer,
  scene : @scene.Scene,
  frame_index? : Int = 0,
) -> RenderedFrame raise RenderError {
  self.render(self.snapshot(scene, frame_index~))
}

///|
pub fn CairoRenderer::write_scene_png(
  self : CairoRenderer,
  scene : @scene.Scene,
  path : String,
  frame_index? : Int = 0,
) -> Unit raise RenderError {
  self.write_png(self.snapshot(scene, frame_index~), path)
}
