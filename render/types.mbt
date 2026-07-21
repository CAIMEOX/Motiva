///|
pub(all) suberror RenderError {
  Cairo(@cairoon.CairoError)
  Camera(@camera.CameraError)
  Ffmpeg(@ffmpeg.FfmpegError)
  Scene(@scene.SceneError)
  MissingObject(@scene.ObjectId)
  OutputFrameCountMismatch(expected~ : Int, actual~ : Int)
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
  camera_space : @camera.CameraSpace
}

///|
pub(all) struct FrameSnapshot {
  time : Double
  frame_index : Int
  camera : @camera.Camera
  items : Array[RenderItem]
}

///|
pub fn FrameSnapshot::from_scene(
  scene : @scene.Scene,
  frame_index? : Int = 0,
) -> FrameSnapshot raise RenderError {
  let camera = scene.camera()
  validate_render_camera(camera)
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
        Some(object) =>
          match object.node {
            Path(_, _) | Mesh(_, _) => {
              let camera_space = try_scene(() => scene.camera_space(id))
              push_z_sorted(items, { id, object, layer, camera_space })
              rendered_ids.add(id)
            }
            _ => ()
          }
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
fn validate_render_camera(camera : @camera.Camera) -> Unit raise RenderError {
  camera.validate() catch {
    error => raise Camera(error)
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
  cairo_line_width_multiple : Double
}

///|
pub fn CairoRenderer::new(
  cairo_line_width_multiple? : Double = 0.01,
) -> CairoRenderer {
  { cairo_line_width_multiple, }
}

///|
pub fn CairoRenderer::snapshot(
  _self : CairoRenderer,
  scene : @scene.Scene,
  frame_index? : Int = 0,
) -> FrameSnapshot raise RenderError {
  FrameSnapshot::from_scene(scene, frame_index~)
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
