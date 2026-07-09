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
  ActiveRotate(ObjectId, start~ : @object.Object, spec~ : RotationSpec)
  ActiveReveal(ObjectId, source~ : @object.Object, mode~ : RevealMode)
  ActiveDrawBorderThenFill(
    ObjectId,
    source~ : @object.Object,
    outline~ : @object.Object
  )
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
    DrawBorderThenFill(id) =>
      ActiveAnimation::draw_border_then_fill(
        id,
        source=scene.require_object(id).object,
        timing=animation.timing,
      )
    Rotate(id, spec) =>
      ActiveAnimation::rotate(
        id,
        start=scene.require_object(id).object,
        spec~,
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
fn ActiveAnimation::rotate(
  id : ObjectId,
  start~ : @object.Object,
  spec~ : RotationSpec,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveRotate(id, start~, spec~),
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
fn ActiveAnimation::draw_border_then_fill(
  id : ObjectId,
  source~ : @object.Object,
  timing~ : Timing,
) -> ActiveAnimation {
  {
    kind: ActiveDrawBorderThenFill(
      id,
      source~,
      outline=make_outline_object(source),
    ),
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
    ActiveTransform(id, ..)
    | ActiveRotate(id, ..)
    | ActiveReveal(id, ..)
    | ActiveDrawBorderThenFill(id, ..)
    | ActiveRemoval(id, ..) => [id]
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
    ActiveRotate(id, start~, ..) =>
      FramePatch::all([
        FramePatch::put(id, start),
        FramePatch::ensure_visible(id),
      ])
    ActiveReveal(id, source~, mode~) =>
      FramePatch::all([
        FramePatch::put(id, sample_reveal(source, mode, 0.0)),
        FramePatch::ensure_visible(id),
      ])
    ActiveDrawBorderThenFill(id, source~, outline~) =>
      FramePatch::all([
        FramePatch::put(id, sample_draw_border_then_fill(source, outline, 0.0)),
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
      ActiveRotate(id, start~, spec~) =>
        FramePatch::all([
          FramePatch::put(id, sample_rotate_object(start, spec, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveReveal(id, source~, mode~) =>
        FramePatch::all([
          FramePatch::put(id, sample_reveal(source, mode, alpha)),
          FramePatch::ensure_visible(id),
        ])
      ActiveDrawBorderThenFill(id, source~, outline~) =>
        FramePatch::all([
          FramePatch::put(
            id,
            sample_draw_border_then_fill(source, outline, alpha),
          ),
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
fn sample_rotate_object(
  start : @object.Object,
  spec : RotationSpec,
  alpha : Double,
) -> @object.Object {
  let point = resolve_rotation_about_point(spec, start)
  let transform = @object.Transform::rotate_about(
    angle=spec.angle * alpha,
    axis=spec.axis,
    point~,
  )
  start.with_transform(start.transform.then(transform))
}

///|
fn resolve_rotation_about_point(
  spec : RotationSpec,
  object : @object.Object,
) -> @object.Vec3 {
  match (spec.about_point, spec.about_edge) {
    (Some(point), _) => point
    (None, Some(edge)) => object.critical_point(edge)
    (None, None) => object.center()
  }
}

///|
fn sample_draw_border_then_fill(
  source : @object.Object,
  outline : @object.Object,
  alpha : Double,
) -> @object.Object {
  if alpha < 0.5 {
    sample_create_object(outline, alpha * 2.0)
  } else {
    interpolate_object(outline, source, (alpha - 0.5) * 2.0)
  }
}

///|
fn make_outline_object(source : @object.Object) -> @object.Object {
  @object.Object::new(
    node=make_outline_node(source.node),
    id=source.id,
    transform=source.transform,
    z_index=source.z_index,
  )
}

///|
fn make_outline_node(source : @object.Node) -> @object.Node {
  match source {
    Empty => Empty
    Group(children) => Group(children.map(child => make_outline_object(child)))
    Path(path, style) => Path(path, make_outline_style(style))
  }
}

///|
fn make_outline_style(style : @object.ShapeStyle) -> @object.ShapeStyle {
  {
    fill: style.fill,
    fill_opacity: 0.0,
    stroke: make_outline_stroke(style),
    stroke_opacity: style.stroke_opacity,
    stroke_width: make_outline_stroke_width(style),
  }
}

///|
fn make_outline_stroke(style : @object.ShapeStyle) -> @object.Rgba? {
  match (style.stroke, style.fill) {
    (Some(stroke), _) => Some(stroke)
    (None, fill) => fill
  }
}

///|
fn make_outline_stroke_width(style : @object.ShapeStyle) -> Double {
  if style.stroke_width <= 0.0 {
    4.0
  } else {
    style.stroke_width
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
