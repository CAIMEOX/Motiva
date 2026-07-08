///|
priv struct AnimationLifecycle {
  introducer : Bool
  remover : Bool
  mutates_object : Bool
}

///|
priv enum RevealMode {
  CreateReveal
  FadeInReveal
}

///|
priv enum RemovalMode {
  FadeOutRemoval
}

///|
priv enum ActiveAnimationKind {
  ActiveWait
  ActiveTransform(ObjectId, start~ : @object.Object, target~ : @object.Object)
  ActiveReveal(ObjectId, source~ : @object.Object, mode~ : RevealMode)
  ActiveRemoval(ObjectId, source~ : @object.Object, mode~ : RemovalMode)
}

///|
priv struct ActiveAnimation {
  kind : ActiveAnimationKind
  timing : Timing
  lifecycle : AnimationLifecycle
}

///|
fn AnimationLifecycle::new(
  introducer~ : Bool,
  remover~ : Bool,
  mutates_object~ : Bool,
) -> AnimationLifecycle {
  { introducer, remover, mutates_object }
}

///|
fn AnimationLifecycle::passive() -> AnimationLifecycle {
  AnimationLifecycle::new(introducer=false, remover=false, mutates_object=false)
}

///|
fn ActiveAnimation::compile(
  scene : Scene,
  animation : Animation,
) -> ActiveAnimation raise SceneError {
  match animation.kind {
    Wait => ActiveAnimation::wait(animation.timing)
    Create(id) =>
      ActiveAnimation::reveal(
        id,
        source=scene.require_object(id).object,
        mode=CreateReveal,
        timing=animation.timing,
      )
    FadeIn(id) =>
      ActiveAnimation::reveal(
        id,
        source=scene.require_object(id).object,
        mode=FadeInReveal,
        timing=animation.timing,
      )
    FadeOut(id) =>
      ActiveAnimation::removal(
        id,
        source=scene.require_object(id).object,
        mode=FadeOutRemoval,
        timing=animation.timing,
      )
    Transform(id, target) =>
      ActiveAnimation::transform(
        id,
        start=scene.require_object(id).object,
        target~,
        timing=animation.timing,
      )
    ApplyOps(id, ops) => {
      let start = scene.require_object(id).object
      let target = ops.fold(init=start, (object, op) => op.apply(object))
      ActiveAnimation::transform(id, start~, target~, timing=animation.timing)
    }
  }
}

///|
fn ActiveAnimation::wait(timing : Timing) -> ActiveAnimation {
  { kind: ActiveWait, timing, lifecycle: AnimationLifecycle::passive() }
}

///|
fn ActiveAnimation::transform(
  id : ObjectId,
  start~ : @object.Object,
  target~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveTransform(id, start~, target~),
    timing,
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=false,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::reveal(
  id : ObjectId,
  source~ : @object.Object,
  mode~ : RevealMode,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveReveal(id, source~, mode~),
    timing,
    lifecycle: AnimationLifecycle::new(
      introducer=true,
      remover=false,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::removal(
  id : ObjectId,
  source~ : @object.Object,
  mode~ : RemovalMode,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveRemoval(id, source~, mode~),
    timing,
    lifecycle: AnimationLifecycle::new(
      introducer=false,
      remover=true,
      mutates_object=true,
    ),
  }
}

///|
fn ActiveAnimation::run_time(self : ActiveAnimation) -> Double {
  self.timing.run_time
}

///|
fn ActiveAnimation::affected_ids(self : ActiveAnimation) -> Array[ObjectId] {
  match self.kind {
    ActiveWait => []
    ActiveTransform(id, ..) | ActiveReveal(id, ..) | ActiveRemoval(id, ..) =>
      [id]
  }
}

///|
fn ActiveAnimation::begin_patch(self : ActiveAnimation) -> FramePatch {
  let _ = self.lifecycle.introducer
  match self.kind {
    ActiveWait => FramePatch::empty()
    ActiveTransform(id, start~, ..) =>
      FramePatch::all([
        FramePatch::put(id, start),
        FramePatch::ensure_visible(id),
      ])
    ActiveReveal(id, source~, mode~) =>
      FramePatch::all([
        FramePatch::put(id, sample_reveal(source, mode, 0.0)),
        FramePatch::ensure_visible(id),
      ])
    ActiveRemoval(id, source~, ..) =>
      FramePatch::all([
        FramePatch::put(id, source),
        FramePatch::ensure_visible(id),
      ])
  }
}

///|
fn ActiveAnimation::sample(
  self : ActiveAnimation,
  alpha : Double,
) -> FramePatch {
  let alpha = clamp_alpha(alpha)
  if !self.lifecycle.mutates_object {
    FramePatch::empty()
  } else {
    match self.kind {
      ActiveWait => FramePatch::empty()
      ActiveTransform(id, start~, target~) =>
        FramePatch::all([
          FramePatch::put(id, interpolate_object(start, target, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveReveal(id, source~, mode~) =>
        FramePatch::all([
          FramePatch::put(id, sample_reveal(source, mode, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveRemoval(id, source~, mode~) =>
        FramePatch::all([
          FramePatch::put(id, sample_removal(source, mode, alpha)),
          FramePatch::ensure_visible(id),
        ])
    }
  }
}

///|
fn ActiveAnimation::sample_at_time(
  self : ActiveAnimation,
  elapsed : Double,
) -> FramePatch {
  self.sample(self.alpha_at_time(elapsed))
}

///|
fn ActiveAnimation::finish_patch(self : ActiveAnimation) -> FramePatch {
  let final_sample = self.sample_at_time(self.run_time())
  if self.lifecycle.remover {
    match self.kind {
      ActiveRemoval(id, ..) => final_sample.then(FramePatch::hide(id))
      _ => final_sample
    }
  } else {
    final_sample
  }
}

///|
fn ActiveAnimation::alpha_at_time(
  self : ActiveAnimation,
  elapsed : Double,
) -> Double {
  if self.timing.run_time <= 0.0 {
    1.0
  } else {
    clamp_alpha(elapsed / self.timing.run_time)
  }
}

///|
fn sample_reveal(
  source : @object.Object,
  mode : RevealMode,
  alpha : Double,
) -> @object.Object {
  match mode {
    CreateReveal => sample_create_object(source, alpha)
    FadeInReveal => source
  }
}

///|
fn sample_create_object(
  source : @object.Object,
  alpha : Double,
) -> @object.Object {
  @object.Object::new(
    node=sample_create_node(source.node, alpha),
    id=source.id,
    transform=source.transform,
    z_index=source.z_index,
  )
}

///|
fn sample_create_node(source : @object.Node, alpha : Double) -> @object.Node {
  match source {
    Empty => Empty
    Group(children) =>
      Group(children.map(child => sample_create_object(child, alpha)))
    Path(path, style) => Path(sample_create_path(path, alpha), style)
  }
}

///|
fn sample_create_path(
  source : @object.Path3D,
  alpha : Double,
) -> @object.Path3D {
  source.eval().prefix(alpha).to_path() catch {
    _ => choose_endpoint(@object.Path3D::empty(), source, alpha)
  }
}

///|
fn sample_removal(
  source : @object.Object,
  mode : RemovalMode,
  _alpha : Double,
) -> @object.Object {
  match mode {
    FadeOutRemoval => source
  }
}
