///|
pub fn Scene::transform_matching(
  self : Scene,
  source_root : ObjectId,
  target_root : ObjectId,
  correspondence : @object.ObjectCorrespondence,
  run_time? : Double = 1.0,
  rate_func? : RateFunc = Smooth,
  path? : @object.MotionPath = @object.MotionPath::straight(),
) -> Animation raise SceneError {
  let source = self.require_matching_object(source_root)
  let target = self.require_matching_object(target_root)
  let animations : Array[Animation] = []
  for bucket in correspondence.buckets() {
    animations.append(
      self.lower_correspondence_bucket(
        source_root, target_root, bucket, run_time, rate_func, path,
      ),
    )
  }
  for source_path in correspondence.source_only() {
    animations.push(
      Animation::fade_out(
        self.resolve_family_path(source_root, source_path),
        run_time~,
        rate_func~,
        target_position=target.center(),
      ),
    )
  }
  for target_path in correspondence.target_only() {
    animations.push(
      Animation::fade_in(
        self.resolve_family_path(target_root, target_path),
        run_time~,
        rate_func~,
        target_position=source.center(),
      ),
    )
  }
  if animations.length() == 0 {
    animations.push(Animation::wait(run_time))
  }
  Animation::replacement(source=source_root, target=target_root, animations)
}

///|
fn Scene::lower_correspondence_bucket(
  self : Scene,
  source_root : ObjectId,
  target_root : ObjectId,
  bucket : @object.CorrespondenceBucket,
  run_time : Double,
  rate_func : RateFunc,
  path : @object.MotionPath,
) -> Array[Animation] raise SceneError {
  let source_count = bucket.source.length()
  let target_count = bucket.target.length()
  if source_count == 0 || target_count == 0 {
    []
  } else if source_count <= target_count {
    let animations : Array[Animation] = []
    for source_index in 0..<source_count {
      guard bucket.source.get(source_index) is Some(source_path) else {
        continue
      }
      let target_paths : Array[@object.FamilyPath] = []
      for target_index in 0..<target_count {
        if target_index * source_count / target_count == source_index {
          match bucket.target.get(target_index) {
            Some(target_path) => target_paths.push(target_path)
            None => ()
          }
        }
      }
      animations.push(
        Animation::transform(
          self.resolve_family_path(source_root, source_path),
          self.matching_target_object(target_root, target_paths),
          run_time~,
          rate_func~,
          path~,
        ),
      )
    }
    animations
  } else {
    let animations : Array[Animation] = []
    for source_index in 0..<source_count {
      match
        (
          bucket.source.get(source_index),
          bucket.target.get(source_index * target_count / source_count),
        ) {
        (Some(source_path), Some(target_path)) =>
          animations.push(
            Animation::transform(
              self.resolve_family_path(source_root, source_path),
              self.matching_target_object(target_root, [target_path]),
              run_time~,
              rate_func~,
              path~,
            ),
          )
        _ => ()
      }
    }
    animations
  }
}

///|
fn Scene::matching_target_object(
  self : Scene,
  target_root : ObjectId,
  paths : Array[@object.FamilyPath],
) -> @object.Object raise SceneError {
  let objects : Array[@object.Object] = []
  for path in paths {
    objects.push(
      self.require_matching_object(self.resolve_family_path(target_root, path)),
    )
  }
  match objects {
    [object] => object
    _ => @object.Object::group(objects)
  }
}

///|
fn Scene::require_matching_object(
  self : Scene,
  id : ObjectId,
) -> @object.Object raise SceneError {
  match self.get(id) {
    Some(object) => object
    None => raise UnknownObject(id)
  }
}
