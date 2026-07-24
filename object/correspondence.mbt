///|
pub(all) struct CorrespondencePart[K] {
  path : FamilyPath
  key : K
}

///|
pub fn[K] CorrespondencePart::new(
  path : FamilyPath,
  key : K,
) -> CorrespondencePart[K] {
  { path, key }
}

///|
pub(all) struct CorrespondenceBucket {
  source : Array[FamilyPath]
  target : Array[FamilyPath]
}

///|
pub struct ObjectCorrespondence {
  priv matched : Array[CorrespondenceBucket]
  priv unmatched_source : Array[FamilyPath]
  priv unmatched_target : Array[FamilyPath]
}

///|
pub fn ObjectCorrespondence::buckets(
  self : ObjectCorrespondence,
) -> Array[CorrespondenceBucket] {
  self.matched.map(bucket => {
    source: bucket.source.copy(),
    target: bucket.target.copy(),
  })
}

///|
pub fn ObjectCorrespondence::source_only(
  self : ObjectCorrespondence,
) -> Array[FamilyPath] {
  self.unmatched_source.copy()
}

///|
pub fn ObjectCorrespondence::target_only(
  self : ObjectCorrespondence,
) -> Array[FamilyPath] {
  self.unmatched_target.copy()
}

///|
pub fn[K : Hash + Eq] ObjectCorrespondence::by_key(
  source : Array[CorrespondencePart[K]],
  target : Array[CorrespondencePart[K]],
  key_map? : Map[K, K],
) -> ObjectCorrespondence {
  let source_buckets = correspondence_buckets(source)
  let target_buckets = correspondence_buckets(target)
  let visited_source_keys : Set[K] = Set([])
  let matched_source_keys : Set[K] = Set([])
  let matched_target_keys : Set[K] = Set([])
  let matched : Array[CorrespondenceBucket] = []
  for part in source {
    if visited_source_keys.add_and_check(part.key) {
      let target_key = key_map
        .bind(keys => keys.get(part.key))
        .map_or(part.key, key => key)
      match (source_buckets.get(part.key), target_buckets.get(target_key)) {
        (Some(source_paths), Some(target_paths)) =>
          if matched_target_keys.add_and_check(target_key) {
            matched_source_keys.add(part.key)
            matched.push({
              source: source_paths.copy(),
              target: target_paths.copy(),
            })
          }
        _ => ()
      }
    }
  }
  {
    matched,
    unmatched_source: source
    .filter(part => !matched_source_keys.contains(part.key))
    .map(part => part.path),
    unmatched_target: target
    .filter(part => !matched_target_keys.contains(part.key))
    .map(part => part.path),
  }
}

///|
fn[K : Hash + Eq] correspondence_buckets(
  parts : Array[CorrespondencePart[K]],
) -> Map[K, Array[FamilyPath]] {
  let buckets : Map[K, Array[FamilyPath]] = Map([])
  for part in parts {
    buckets.get_or_init(part.key, () => []).push(part.path)
  }
  buckets
}
