///|
priv struct ResolvedTexFragment {
  tex_string : String
  id : @scene.ObjectId
}

///|
pub struct TransformMatchingTex {
  priv animation : @scene.Animation
  priv target : @scene.ObjectId
}

///|
pub fn TransformMatchingTex::new(
  scene : @scene.Scene,
  source_root : @scene.ObjectId,
  source : MathTex,
  target : MathTex,
  target_object? : @object.Object,
  key_map? : Map[String, String],
  run_time? : Double = 1.0,
  rate_func? : @scene.RateFunc = Smooth,
) -> TransformMatchingTex raise @scene.SceneError {
  let target_root = scene.object(
    target_object.map_or_else(() => target.object(), object => object),
  )
  let source_fragments = resolve_main_fragments(scene, source_root, source)
  let target_fragments = resolve_main_fragments(scene, target_root, target)
  let source_used : Set[@scene.ObjectId] = Set([])
  let target_used : Set[@scene.ObjectId] = Set([])
  let animations : Array[@scene.Animation] = []
  match key_map {
    None => ()
    Some(keys) =>
      for entry in keys {
        let (source_key, target_key) = entry
        match_fragment_keys(
          scene, source_fragments, target_fragments, source_key, target_key, source_used,
          target_used, animations, run_time, rate_func,
        )
      }
  }
  for source_fragment in source_fragments {
    if !source_used.contains(source_fragment.id) {
      match
        first_available_fragment(
          target_fragments,
          source_fragment.tex_string,
          target_used,
        ) {
        None => ()
        Some(target_fragment) =>
          add_fragment_transform(
            scene, source_fragment, target_fragment, source_used, target_used, animations,
            run_time, rate_func,
          )
      }
    }
  }
  let source_center = require_scene_object(scene, source_root).center()
  let target_center = require_scene_object(scene, target_root).center()
  for source_fragment in source_fragments {
    if !source_used.contains(source_fragment.id) {
      animations.push(
        @scene.Animation::fade_out(
          source_fragment.id,
          run_time~,
          rate_func~,
          target_position=target_center,
        ),
      )
    }
  }
  for target_fragment in target_fragments {
    if !target_used.contains(target_fragment.id) {
      animations.push(
        @scene.Animation::fade_in(
          target_fragment.id,
          run_time~,
          rate_func~,
          target_position=source_center,
        ),
      )
    }
  }
  if animations.length() == 0 {
    animations.push(@scene.Animation::wait(run_time))
  }
  {
    animation: @scene.Animation::replacement(
      source=source_root,
      target=target_root,
      animations,
    ),
    target: target_root,
  }
}

///|
pub fn TransformMatchingTex::target_id(
  self : TransformMatchingTex,
) -> @scene.ObjectId {
  self.target
}

///|
pub impl @scene.IntoAnimation for TransformMatchingTex with fn to_animation(
  self,
) {
  self.animation
}

///|
fn resolve_main_fragments(
  scene : @scene.Scene,
  root : @scene.ObjectId,
  formula : MathTex,
) -> Array[ResolvedTexFragment] raise @scene.SceneError {
  formula
  .fragments(kind=Main)
  .map(fragment => {
    tex_string: fragment.tex_string,
    id: scene.resolve_family_path(root, fragment.path),
  })
}

///|
fn match_fragment_keys(
  scene : @scene.Scene,
  source_fragments : Array[ResolvedTexFragment],
  target_fragments : Array[ResolvedTexFragment],
  source_key : String,
  target_key : String,
  source_used : Set[@scene.ObjectId],
  target_used : Set[@scene.ObjectId],
  animations : Array[@scene.Animation],
  run_time : Double,
  rate_func : @scene.RateFunc,
) -> Unit raise @scene.SceneError {
  for source_fragment in source_fragments {
    if source_fragment.tex_string == source_key &&
      !source_used.contains(source_fragment.id) {
      match
        first_available_fragment(target_fragments, target_key, target_used) {
        None => ()
        Some(target_fragment) =>
          add_fragment_transform(
            scene, source_fragment, target_fragment, source_used, target_used, animations,
            run_time, rate_func,
          )
      }
    }
  }
}

///|
fn first_available_fragment(
  fragments : Array[ResolvedTexFragment],
  tex_string : String,
  used : Set[@scene.ObjectId],
) -> ResolvedTexFragment? {
  for fragment in fragments {
    if fragment.tex_string == tex_string && !used.contains(fragment.id) {
      return Some(fragment)
    }
  }
  None
}

///|
fn add_fragment_transform(
  scene : @scene.Scene,
  source : ResolvedTexFragment,
  target : ResolvedTexFragment,
  source_used : Set[@scene.ObjectId],
  target_used : Set[@scene.ObjectId],
  animations : Array[@scene.Animation],
  run_time : Double,
  rate_func : @scene.RateFunc,
) -> Unit raise @scene.SceneError {
  let source_paths = path_family_ids(scene, source.id)
  let target_paths = path_family_ids(scene, target.id)
  let pair_count = if source_paths.length() < target_paths.length() {
    source_paths.length()
  } else {
    target_paths.length()
  }
  for index in 0..<pair_count {
    match (source_paths.get(index), target_paths.get(index)) {
      (Some(source_path), Some(target_path)) =>
        animations.push(
          @scene.Animation::transform(
            source_path,
            require_scene_object(scene, target_path),
            run_time~,
            rate_func~,
          ),
        )
      _ => ()
    }
  }
  let source_center = require_scene_object(scene, source.id).center()
  let target_center = require_scene_object(scene, target.id).center()
  for index in pair_count..<source_paths.length() {
    match source_paths.get(index) {
      None => ()
      Some(source_path) =>
        animations.push(
          @scene.Animation::fade_out(
            source_path,
            run_time~,
            rate_func~,
            target_position=target_center,
          ),
        )
    }
  }
  for index in pair_count..<target_paths.length() {
    match target_paths.get(index) {
      None => ()
      Some(target_path) =>
        animations.push(
          @scene.Animation::fade_in(
            target_path,
            run_time~,
            rate_func~,
            target_position=source_center,
          ),
        )
    }
  }
  source_used.add(source.id)
  target_used.add(target.id)
}

///|
fn path_family_ids(
  scene : @scene.Scene,
  root : @scene.ObjectId,
) -> Array[@scene.ObjectId] raise @scene.SceneError {
  let paths : Array[@scene.ObjectId] = []
  for id in scene.family(root) {
    if scene.get(id).map_or(false, object => object.node is Path(_, _)) {
      paths.push(id)
    }
  }
  paths
}

///|
fn require_scene_object(
  scene : @scene.Scene,
  id : @scene.ObjectId,
) -> @object.Object raise @scene.SceneError {
  match scene.get(id) {
    Some(object) => object
    None => raise UnknownObject(id)
  }
}
