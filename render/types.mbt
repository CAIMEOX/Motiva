///|
pub(all) suberror RenderError {
  Cairo(@cairoon.CairoError)
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
  frame_width? : Double = 14.222222222222221,
  frame_height? : Double = 8.0,
  frame_center? : @object.Vec3 = @object.Vec3::zero(),
  background? : @object.Rgba = @object.Rgba::black(),
  cairo_line_width_multiple? : Double = 0.01,
) -> Camera {
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
pub fn Camera::default() -> Camera {
  Camera::new()
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
  let foreground_ids = scene.foreground_objects()
  let main_items : Array[RenderItem] = []
  let foreground_items : Array[RenderItem] = []
  for id in scene.visible_objects() {
    if !contains_id(foreground_ids, id) {
      push_scene_item(main_items, scene, id, Main)
    }
  }
  for id in foreground_ids {
    push_scene_item(foreground_items, scene, id, Foreground)
  }
  main_items.append(foreground_items)
  { time: scene.time(), frame_index, camera, items: main_items }
}

///|
fn contains_id(ids : Array[@scene.ObjectId], id : @scene.ObjectId) -> Bool {
  ids.fold(init=false, (found, current) => found || current == id)
}

///|
fn push_scene_item(
  items : Array[RenderItem],
  scene : @scene.Scene,
  id : @scene.ObjectId,
  layer : RenderLayer,
) -> Unit raise RenderError {
  match scene.get(id) {
    None => raise MissingObject(id)
    Some(object) => push_z_sorted(items, { id, object, layer })
  }
}

///|
fn push_z_sorted(items : Array[RenderItem], item : RenderItem) -> Unit {
  let mut inserted = false
  for index in 0..<items.length() {
    if !inserted && item.object.z_index < items[index].object.z_index {
      items.insert(index, item)
      inserted = true
    }
  }
  if !inserted {
    items.push(item)
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
