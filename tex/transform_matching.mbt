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
  path? : @object.MotionPath = @object.MotionPath::straight(),
) -> TransformMatchingTex raise @scene.SceneError {
  let target_root = scene.object(
    target_object.map_or_else(() => target.object(), object => object),
  )
  let correspondence = @object.ObjectCorrespondence::by_key(
    tex_correspondence_parts(source),
    tex_correspondence_parts(target),
    key_map?,
  )
  {
    animation: scene.transform_matching(
      source_root,
      target_root,
      correspondence,
      run_time~,
      rate_func~,
      path~,
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
fn tex_correspondence_parts(
  formula : MathTex,
) -> Array[@object.CorrespondencePart[String]] {
  formula
  .fragments(kind=Main)
  .map(fragment => {
    @object.CorrespondencePart::new(fragment.path, fragment.tex_string)
  })
}
